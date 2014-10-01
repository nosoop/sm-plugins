/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>

#define PLUGIN_VERSION              "0.1.2"

public Plugin:myinfo = {
    name = "[TF2] Hat Removal (+clientprefs)",
    author = "Jaro 'Monkeys' Vanderheijden, nosoop",
    description = "Gives players the choice to toggle hat visibility",
    version = PLUGIN_VERSION,
    url = "http://www.sourcemod.net/"
};

#define CONFIG_COMMENT              ";"
#define WEARABLE_EXEMPTION_CONFIG   "data/viewwearables.txt"

// Cookie handle and client preference array.
new Handle:g_hCookieViewWearables = INVALID_HANDLE,     bool:g_bClientViewsWearables[MAXPLAYERS+1];

new Handle:g_hItemDefsExempted = INVALID_HANDLE;

public OnPluginStart() {
    CreateConVar("sm_viewwearables_version", PLUGIN_VERSION, "Version of Hat Removal (+clientprefs)", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);

    RegAdminCmd("sm_viewwearables_reload", Command_ReloadExemptions, ADMFLAG_ROOT, "Reloads exemption-by-defindex list of wearables.");
    
    g_hCookieViewWearables = RegClientCookie("ViewWearables", "Show / hide other player's hats.", CookieAccess_Protected);
    
    // TODO Use custom menu handling -- the prefab menu doesn't recache the cookie value.
    SetCookiePrefabMenu(g_hCookieViewWearables, CookieMenu_OnOff_Int, "Toggle Wearables", CookieHandler_RemoveWearables);
    
    for (new i = MaxClients; i > 0; --i) {
        g_bClientViewsWearables = true;
        if (!AreClientCookiesCached(i)) {
            continue;
        }
        
        OnClientCookiesCached(i);
    }
    
    g_hItemDefsExempted = CreateArray();
    LoadItemExemptions();
    
    // Handle late-loading wearables.
    new iWearable = -1;
    while ( (iWearable = FindEntityByClassname(iWearable, "tf_wearable")) != -1 ) {
        OnWearableCreated(iWearable);
    }
}

public OnClientDisconnect(iClient) {
    g_bClientViewsWearables[iClient] = true;
}

public OnEntityCreated(entity, const String:sClassName[]) {
    if (StrEqual(sClassName, "tf_wearable")) {
        OnWearableCreated(entity);
    }
}

/**
 * Called when a tf_wearable instance is created.
 */
OnWearableCreated(iWearable, bool:bRetry = false) {
    new iItemDefinitionIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
    
    // If the defindex is 0, the wearable isn't fully prepared yet.
    if (iItemDefinitionIndex == 0 && !bRetry) {
        CreateTimer(0.01, Timer_RetryOnWearableCreated, iWearable);
    } else if (FindValueInArray(g_hItemDefsExempted, iItemDefinitionIndex) == -1) {
        SDKHook(iWearable, SDKHook_SetTransmit, SDKHook_OnWearableTrasnmit);
    }
}

public Action:Timer_RetryOnWearableCreated(Handle:hTimer, any:iWearable) {
    OnWearableCreated(iWearable, true);
    return Plugin_Handled;
}

public Action:SDKHook_OnWearableTrasnmit(iEntity, iClient) {
    if (g_bClientViewsWearables[iClient]) {
        return Plugin_Continue;
    } else {
        return Plugin_Handled;
    }
}

public Action:Command_ReloadExemptions(client, args) {
    LoadItemExemptions();
    return Plugin_Handled;
}

LoadItemExemptions() {
    ClearArray(g_hItemDefsExempted);

    decl String:sItemExemptions[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sItemExemptions, sizeof(sItemExemptions), WEARABLE_EXEMPTION_CONFIG);
    
    // Exemptions file -- reads each line expecting a defindex value
    // Can contain empty lines or comments starting with the ";" character
    if (FileExists(sItemExemptions)) {
        new Handle:hItemExemptions = OpenFile(sItemExemptions, "r");
        
        if (hItemExemptions != INVALID_HANDLE) {
            new String:sDefIndex[32], String:sConfigLine[256];
            
            while (ReadFileLine(hItemExemptions, sConfigLine, sizeof(sConfigLine))) {
                SplitString(sConfigLine, CONFIG_COMMENT, sDefIndex, sizeof(sDefIndex));
                TrimString(sDefIndex);
                
                if (strlen(sDefIndex) == 0) {
                    continue;
                }
                PushArrayCell(g_hItemDefsExempted, StringToInt(sDefIndex));
            }
            CloseHandle(hItemExemptions);
        }
    }
}

public OnClientCookiesCached(client) {
    decl String:sValue[8];
    GetClientCookie(client, g_hCookieViewWearables, sValue, sizeof(sValue));
    
    // Opt-out:  Enable if null or if cookie is enabled.
    g_bClientViewsWearables[client] = (sValue[0] == '\0' || StringToInt(sValue) > 0);
}

public CookieHandler_RemoveWearables(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
    switch (action) {
        case CookieMenuAction_DisplayOption: {
        }
        case CookieMenuAction_SelectOption: {
            OnClientCookiesCached(client);
        }
    }
}
