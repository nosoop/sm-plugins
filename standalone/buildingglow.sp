/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <tf2_stocks>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

#define NUM_BUILDINGS_CLIENT    8
#define NUM_BUILDINGS_CELLCOUNT 9
#define BUILDING_ANNOT_OFFSET   5751        

public Plugin:myinfo = {
    name = "[TF2] Building Glow",
    author = "nosoop",
    description = "Enables glow outlines for the Engineer that placed them.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

new Handle:g_rgClientBuildings[MAXPLAYERS+1],
    Handle:g_rgClientBuildingTimer[MAXPLAYERS+1],
    g_rgiClientBuilding[MAXPLAYERS+1];

// new Handle:g_hCookieBuildingGlow = INVALID_HANDLE;
// new bool:g_bClientBuildingGlowEnable[MAXPLAYERS+1];

public OnPluginStart() {
    // g_hCookieBuildingGlow = RegClientCookie("OurTestCookie", "A Test Cookie for use in our Tutorial", CookieAccess_Private);
    // SetCookiePrefabMenu(g_hCookieBuildingGlow, CookieMenu_OnOff_Int, "TestCookie", CookieHandler_BuildingGlow);
    // for (new i = MaxClients; i > 0; --i) {
    //     if (!AreClientCookiesCached(i)) {
    //         continue;
    //     }
    //     
    //     OnClientCookiesCached(i);
    // }
    
    HookEvent("player_spawn", Hook_PostPlayerSpawn);
    HookEvent("player_builtobject", Event_BuiltObject);
}

public Hook_PostPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client;
    client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (TF2_GetPlayerClass(client) != TFClass_Engineer && g_rgClientBuildingTimer[client] != INVALID_HANDLE) {
        CloseHandle(g_rgClientBuildings[client]);
        g_rgClientBuildings[client] = INVALID_HANDLE;
        
        KillTimer(g_rgClientBuildingTimer[client]);
        g_rgClientBuildingTimer[client] = INVALID_HANDLE;
    } else if (g_rgClientBuildingTimer[client] == INVALID_HANDLE) {
        g_rgClientBuildings[client] = CreateArray();
        CreateTimer(1.0, Timer_BuildingFinder, client, TIMER_REPEAT);
    }
}

public Action:Timer_BuildingFinder(Handle:timer, any:client) {
    if (GetArraySize(g_rgClientBuildings[client]) > 0) {
        new iBuilding = g_rgiClientBuilding[client] = (g_rgiClientBuilding[client] + 1) % GetArraySize(g_rgClientBuildings[client]);
        ShowAnnotationToPlayer(client, GetArrayCell(g_rgClientBuildings[client], iBuilding));
    }
}


public CookieHandler_BuildingGlow(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
    // switch (action) {
    //     case CookieMenuAction_DisplayOption: {
    //     }
    //     case CookieMenuAction_SelectOption: {
    //         OnClientCookiesCached(client);
    //     }
    // }
}

public Action:Event_BuiltObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsPlayerAlive(iClient)) return Plugin_Continue;

	new iBuilding = GetEventInt(event, "index");
    
    if (FindValueInArray(g_rgClientBuildings[iClient], iBuilding) == -1) {
        PushArrayCell(g_rgClientBuildings[iClient], iBuilding);
    }
    
    return Plugin_Continue;
}

public OnClientCookiesCached(client) {
    // decl String:sValue[8];
    // GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
    
    // g_bClientBuildingGlowEnable[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

public ShowAnnotationToPlayer(client, entity) {
	new Handle:event = CreateEvent("show_annotation");
	if (event == INVALID_HANDLE) return;
	
    new Float:position[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
    
    SetEventInt(event, "follow_entindex", entity);
	SetEventFloat(event, "lifetime", 99999.0);
	SetEventInt(event, "id", 1*MAXPLAYERS + client + BUILDING_ANNOT_OFFSET);
	SetEventString(event, "text", "Engineer Building");
	SetEventString(event, "play_sound", "vo/null.wav");
    SetEventBool(event, "show_effect", false);
	SetEventInt(event, "visibilityBitfield", (1 << client));
	FireEvent(event);
}