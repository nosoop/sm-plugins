/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

#define DOWNLOADFILTER_NONE     (0 << 0)
#define DOWNLOADFILTER_MAPS     (1 << 0)
#define DOWNLOADFILTER_SOUNDS   (1 << 1)
#define DOWNLOADFILTER_ALL      0xFFFFFFFF    

public Plugin:myinfo = {
    name = "[ANY?] Get Download Filter",
    author = "nosoop",
    description = "Helper library to determine if a client has a download filter set.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

new String:g_rgsDownloadFilterNames[][] = {
    "none", "mapsonly", "nosounds", "all"
};

new g_rgDownloadFilterBitflags[] = {
    DOWNLOADFILTER_NONE, DOWNLOADFILTER_MAPS, !DOWNLOADFILTER_SOUNDS, DOWNLOADFILTER_ALL
};

new g_rgbClientDownloadFilters[MAXPLAYERS+1];

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
        if (strcmp(g_rgsDownloadFilterNames[i], cvarValue, false)) {
            SetClientDownloadFilterFlag(client, g_rgDownloadFilterBitflags[i]);
            return;
        }
    }
    SetClientDownloadFilterFlag(client, DOWNLOADFILTER_NONE);
}

SetClientDownloadFilterFlag(client, flags) {
    g_rgbClientDownloadFilters[client] = flags;
    // TODO Call forward to notify.
}

GetClientDownloadFilterFlag(client) {
    return g_rgbClientDownloadFilters[client];
}

// TODO Create native for GetClientDownloadFilterFlag and OnClientDownloadFilterFlagSet