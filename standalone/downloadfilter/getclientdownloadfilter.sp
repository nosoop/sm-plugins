/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.1.0"     // Plugin version.

#define DOWNLOADFILTER_NONE     (0 << 0)    // No downloads allowed.
#define DOWNLOADFILTER_MAPS     (1 << 0)    // Maps.
#define DOWNLOADFILTER_SOUNDS   (1 << 1)    // Sounds.
#define DOWNLOADFILTER_MISC     (1 << 2)    // Other content not defined.
#define DOWNLOADFILTER_ALL      0xFF        // All downloads allowed.

public Plugin:myinfo = {
    name = "[ANY?] Get Download Filter",
    author = "nosoop",
    description = "Helper library to determine if a client has a download filter set.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

// Possible values for cl_downloadfilter
new String:g_rgsDownloadFilterNames[][] = {
    "none", "mapsonly", "nosounds", "all"
};

// Possible bitflags for cl_downloadfilter
new g_rgDownloadFilterBitflags[] = {
    DOWNLOADFILTER_NONE, DOWNLOADFILTER_MAPS, !DOWNLOADFILTER_SOUNDS, DOWNLOADFILTER_ALL
};

new g_rgbClientDownloadFilters[MAXPLAYERS+1];

new Handle:g_hOnDownloadFlagsSet = INVALID_HANDLE;

public OnPluginStart() {
    RegAdminCmd("sm_showclientdownloadfilters", Command_ShowClientDownloadFilters, ADMFLAG_ROOT, "Shows active download filters on each client.");
    for (new i = MaxClients; i > 0; --i) {
        OnClientPostAdminCheck(i);
    }
    
    g_hOnDownloadFlagsSet = CreateGlobalForward("OnClientDownloadFilterFlagsSet", ET_Ignore, Param_Cell, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMySelf, bool:bLate, String:strError[], iMaxErrors) {
    RegPluginLibrary("clientdownloadfilters");
    CreateNative("GetClientDownloadFilterFlags", Native_GetClientDownloadFilterFlag);
    
    return APLRes_Success;
}

public Action:Command_ShowClientDownloadFilters(client, args) {
    for (new i = MaxClients; i > 0; --i) {
        if (IsClientInGame(i)) {
            PrintToConsole(client, "%02X %N", g_rgbClientDownloadFilters[i], i);
        }
    }
    return Plugin_Handled;
}

public OnClientPostAdminCheck(client) {	
    if (IsClientConnected(client)) {
        QueryClientConVar(client, "cl_allowdownload", ConVarQuery_AllowDownload, client);
	}
}

public ConVarQuery_AllowDownload(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[]) {
    new bAllowDownload = StringToInt(cvarValue) > 0;
    if (!bAllowDownload) {
        SetClientDownloadFilterFlag(client, DOWNLOADFILTER_NONE);
    } else {
        if (IsClientConnected(client)) {
            QueryClientConVar(client, "cl_downloadfilter", ConVarQuery_DownloadFilter, client);
        }
    }
}

public ConVarQuery_DownloadFilter(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[]) {
    for (new i = 0; i < sizeof(g_rgsDownloadFilterNames); i++) {
        if (strcmp(g_rgsDownloadFilterNames[i], cvarValue, false) == 0) {
            SetClientDownloadFilterFlag(client, g_rgDownloadFilterBitflags[i]);
            return;
        }
    }
    SetClientDownloadFilterFlag(client, DOWNLOADFILTER_NONE);
}

SetClientDownloadFilterFlag(client, flags) {
    g_rgbClientDownloadFilters[client] = flags;
    
    Call_StartForward(g_hOnDownloadFlagsSet);
    Call_PushCell(client);
    Call_PushCell(flags);
    Call_Finish();
}

GetClientDownloadFilterFlag(client) {
    return g_rgbClientDownloadFilters[client];
}

public Native_GetClientDownloadFilterFlag(Handle:hPlugin, nParams) {
    new iClient = GetNativeCell(1);
    
    return GetClientDownloadFilterFlag(iClient);
}
