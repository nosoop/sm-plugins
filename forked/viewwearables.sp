/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>

#define PLUGIN_VERSION          "0.1.2"

public Plugin:myinfo = {
    name = "[TF2] Hat Removal (+clientprefs)",
    author = "Jaro 'Monkeys' Vanderheijden, nosoop",
    description = "Gives players the choice to toggle hat visibility",
    version = PLUGIN_VERSION,
    url = "http://www.sourcemod.net/"
};

// Cookie handle and client preference array.
new Handle:g_hCookieViewWearables = INVALID_HANDLE,     bool:g_bClientViewsWearables[MAXPLAYERS+1];

public OnPluginStart() {
    CreateConVar("sm_viewwearables_version", PLUGIN_VERSION, "Version of Hat Removal", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);

    // RegConsoleCmd("sm_togglehat", cbToggleHat, "Toggles hat visibility");
    
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

OnWearableCreated(iWearable) {
    // The delay is present so m_ModelName can be set.
    CreateTimer(0.1, Timer_WearableCheck, iWearable);
}

public Action:Timer_WearableCheck(Handle:Timer, any:entity) {
    if (IsValidEdict(entity)) {
        // TODO Change detection method
        // Exceptions given to the Razorback, Darwin's Danger Shield or Gunboats.
        new String:sModel[256];
        GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
        if (!( StrContains(sModel, "croc_shield") != -1 
                || StrContains(sModel, "c_rocketboots_soldier") != -1
                || StrContains(sModel, "knife_shield") != -1 ) ) {
            SDKHook(entity, SDKHook_SetTransmit, SDKHook_OnWearableTrasnmit);
        }
    }
}

public Action:SDKHook_OnWearableTrasnmit(iEntity, iClient) {
    if (g_bClientViewsWearables[iClient]) {
        return Plugin_Continue;
    } else {
        return Plugin_Handled;
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
