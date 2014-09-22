/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <clientprefs>

#define PLUGIN_VERSION          "0.1.1"     // Plugin version.

#define ADVERTISEMENT_LENGTH    255
#define ADVERTISEMENT_CONFIG    "data/quickads.txt"
#define ADVERTISEMENT_INTERVAL  10.0

public Plugin:myinfo = {
    name = "[ANY] Quick Advertisements",
    author = "nosoop",
    description = "A simple text advertisements-only plugin.",
    version = PLUGIN_VERSION,
    url = "localhost"
}

// Array of advertisement strings.
new Handle:g_hrgsAdvertisements = INVALID_HANDLE;

// Advertisement timer.
new Handle:g_hTimerAdvertisement = INVALID_HANDLE,
    g_iTimeToNextAdvertisement,
    g_iTimeLastAdvertisementPlay;

// Convars.
new Handle:g_hCAdvertisementInterval = INVALID_HANDLE,  Float:g_fAdvertisementInterval;

// Clientprefs support to disable advertisements.
new Handle:g_hAdvertisementCookie = INVALID_HANDLE,     bool:g_bClientSeesAdvertisements[MAXPLAYERS+1];

public OnPluginStart() {
    g_hrgsAdvertisements = CreateArray(ADVERTISEMENT_LENGTH);
    
    g_hCAdvertisementInterval = CreateConVar(
            "sm_quickads_interval", "60.0", "Amount of time between advertisements.",
            FCVAR_PLUGIN|FCVAR_SPONLY, true, 1.0);
    g_fAdvertisementInterval = GetConVarFloat(g_hCAdvertisementInterval);
    
    g_iTimeToNextAdvertisement = RoundFloat(g_fAdvertisementInterval);
    
    AutoExecConfig(true, "plugin.quickads");
    
    g_hAdvertisementCookie = RegClientCookie("QuickAds", "Opt-out of text advertisements.", CookieAccess_Protected);
    SetCookiePrefabMenu(g_hAdvertisementCookie, CookieMenu_OnOff_Int, "Text Advertisements", CookieHandler_Advertisements);
    
    for (new i = MaxClients; i > 0; --i) {
        if (!AreClientCookiesCached(i)) {
            continue;
        }
        OnClientCookiesCached(i);
    }
}

public OnMapStart() {
    ClearArray(g_hrgsAdvertisements);
    LoadAdvertisementsConfig();
    
    // TODO: Call global forward.
    
    OnPlayerCountCheck();
}

public OnClientPutInServer(client) {
    OnPlayerCountCheck();
}

OnPlayerCountCheck() {
    // Enable advertisements if there are people on.
    if (GetLivePlayerCount() > 0 && g_hTimerAdvertisement == INVALID_HANDLE) {
        g_hTimerAdvertisement = CreateTimer(float(g_iTimeToNextAdvertisement), Timer_FirstAdvertisement);
    }
}

public OnClientDisconnect_Post(client) {
    // Pause advertisement timer by killing it and setting the amount of time until next one appropriately.
    if (GetLivePlayerCount() == 0) {
        KillTimer(g_hTimerAdvertisement);
        g_hTimerAdvertisement = INVALID_HANDLE;
        
        g_iTimeToNextAdvertisement = RoundFloat(g_fAdvertisementInterval) - (RoundFloat(GetTickedTime()) - g_iTimeLastAdvertisementPlay);
        g_iTimeToNextAdvertisement = g_iTimeToNextAdvertisement < 0 ? 0 : g_iTimeToNextAdvertisement;
    }
}

public Action:Timer_FirstAdvertisement(Handle:timer, any:thing) {
    g_hTimerAdvertisement = CreateTimer(g_fAdvertisementInterval, Timer_Advertisement, _, TIMER_REPEAT);
    TriggerTimer(g_hTimerAdvertisement);
}

public Action:Timer_Advertisement(Handle:timer, any:thing) {
    PrintNextAdvertisementToChat();
    return Plugin_Handled;
}

PrintNextAdvertisementToChat() {
    static s_iCurrentAdvertisement = 0;
    
    new nAdvertisements = GetArraySize(g_hrgsAdvertisements);
    if (nAdvertisements == 0) {
        return;
    } else if (s_iCurrentAdvertisement + 1 >= nAdvertisements) {
        s_iCurrentAdvertisement = 0;
    }
    
    decl String:sMessage[ADVERTISEMENT_LENGTH];
    GetArrayString(g_hrgsAdvertisements, s_iCurrentAdvertisement++, sMessage, sizeof(sMessage));
    
    // TODO:  Call forward to replace any tokenized values that need replacing.
    
    for (new i = MaxClients; i > 0; --i) {
        if (!g_bClientSeesAdvertisements[i] && IsClientConnected(i) && !IsFakeClient(i)) {
            CSkipNextClient(i);
        }
    }
    CPrintToChatAll(sMessage);
    
    g_iTimeLastAdvertisementPlay = RoundFloat(GetTickedTime());
}

/**
 * Load advertisement configuration.
 */
LoadAdvertisementsConfig() {
    static String:sKeyValuesFile[PLATFORM_MAX_PATH];
    if (strlen(sKeyValuesFile) == 0) {
        BuildPath(Path_SM, sKeyValuesFile, sizeof(sKeyValuesFile), ADVERTISEMENT_CONFIG);
    }

    // Read keyvalues if existent.  If not, rely on forward to retrieve advertisements elsewhere.
    if (FileExists(sKeyValuesFile, true)) {
        new Handle:hKeyValues = CreateKeyValues("quickads");
        FileToKeyValues(hKeyValues, sKeyValuesFile);
        
        KvGotoFirstSubKey(hKeyValues, false);
        
        decl String:sMessage[ADVERTISEMENT_LENGTH];
        do {
            if (KvGetDataType(hKeyValues, NULL_STRING) == KvData_String) {
                KvGetString(hKeyValues, NULL_STRING, sMessage, sizeof(sMessage));
                
                if (strlen(sMessage) > 0) {
                    AddAdvertisement(sMessage);
                }
            }
        } while (KvGotoNextKey(hKeyValues, false));
        
        CloseHandle(hKeyValues);
    }
}

AddAdvertisement(const String:message[]) {
    return PushArrayString(g_hrgsAdvertisements, message);
}

// TODO Native function to add advertisements QuickAds_Add()

stock GetLivePlayerCount() {
    new nPlayers;
    for (new i = MaxClients; i > 0; --i) {
        if (IsClientConnected(i) && !IsFakeClient(i)) {
            nPlayers++;
        }
    }
    return nPlayers;
}

/**
 * Clientprefs.
 */

public OnClientCookiesCached(client) {
    decl String:sValue[8];
    GetClientCookie(client, g_hAdvertisementCookie, sValue, sizeof(sValue));
    
    g_bClientSeesAdvertisements[client] = (sValue[0] == '\0' || StringToInt(sValue) > 0);
}

public CookieHandler_Advertisements(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
    switch (action) {
        case CookieMenuAction_DisplayOption: {
        }
        case CookieMenuAction_SelectOption: {
            OnClientCookiesCached(client);
        }
    }
}
