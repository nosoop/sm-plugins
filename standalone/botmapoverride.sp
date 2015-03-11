/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <mapchooser>
#include <tf2>

#define PLUGIN_VERSION          "1.1.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Bot-only Map Override",
    author = "nosoop",
    description = "Switches the next map to a map compatible with bots if no players are on.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

#define MAP_NAME_LENGTH         96

public OnPluginStart() {
    LoadTranslations("mapchooser.phrases");
    // TODO Check playercount on disconnect to see if we need to change maps?
    
    RegAdminCmd("sm_setnextbotmap", AdminCmd_SetNextBotMap, ADMFLAG_CHANGEMAP, "Changes the next map to a bot-compatible map.");
    
    // Event fires when the post-map scoreboard shows.
    HookEvent("teamplay_game_over", Hook_OnGameOver);
    HookEvent("player_disconnect", Hook_OnPlayerDisconnect);
}

public OnMapStart() {
    decl String:sCurrentMap[MAP_NAME_LENGTH];
    GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
    if (GetLivePlayerCount() == 0 && (!MapIsNotCustomExcluded(sCurrentMap) || !MapHasNavigationMesh(sCurrentMap))) {
        PrintToServer("No players detected.  Changing map in 1.5 minutes...");
        CreateTimer(90.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action:AdminCmd_SetNextBotMap(iClient, nArgs) {
    if (SetNextBotMap()) {
        decl String:sNextMap[MAP_NAME_LENGTH];
        GetNextMap(sNextMap, MAP_NAME_LENGTH);
        
        ShowActivity(iClient, "%t", "Changed Next Map", sNextMap);
        LogAction(iClient, -1, "\"%L\" changed nextmap to \"%s\"", iClient, sNextMap);
    }
    return Plugin_Handled;
}

public Hook_OnPlayerDisconnect(Handle:hEvent, const String:name[], bool:dontBroadcast) {
    new bool:bBot = GetEventBool(hEvent, "bot");
    
    if (!bBot && GetLivePlayerCount() == 0) {
        decl String:sCurrentMap[MAP_NAME_LENGTH];
        GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
        if (!MapIsNotCustomExcluded(sCurrentMap) || !MapHasNavigationMesh(sCurrentMap)) {
            PrintToServer("No players detected.  Changing map in 1.5 minutes...");
            CreateTimer(90.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public Action:Timer_ChangeMap(Handle:hTimer) {
    if (GetLivePlayerCount() == 0) {
        SetNextBotMap(true);
    }
    return Plugin_Handled;
}

bool:SetNextBotMap(bool:bChangeNow = false) {
    new bool:bSuccess;
    new String:sCurrentMap[MAP_NAME_LENGTH];
    new Handle:hMapList = CreateArray(MAP_NAME_LENGTH);
    
    GetCurrentMap(sCurrentMap, MAP_NAME_LENGTH);
    
    // Validate read map list handle
    if (ReadMapList(hMapList) != INVALID_HANDLE) {
        new Handle:hExcludedMaps = CreateArray(MAP_NAME_LENGTH),
            Handle:hCustomExcludes = CreateArray(MAP_NAME_LENGTH),
            Handle:hValidPreviousMaps = CreateArray(MAP_NAME_LENGTH);
        
        GetExcludeMapList(hExcludedMaps);
        AddCustomMapExclusions(hCustomExcludes);
        
        // Trim candidates down to valid bot maps that have not been played recently.
        decl String:sMapBuffer[MAP_NAME_LENGTH];
        for (new i = GetArraySize(hMapList) - 1; i >= 0; --i) {
            GetArrayString(hMapList, i, sMapBuffer, MAP_NAME_LENGTH);
            
            new bool:bPreviousMap = (FindStringInArray(hExcludedMaps, sMapBuffer) != -1);
            
            if (bPreviousMap
                    || FindStringInArray(hCustomExcludes, sMapBuffer) != -1
                    || !MapHasNavigationMesh(sMapBuffer)
                    || StrEqual(sMapBuffer, sCurrentMap)) {
                RemoveFromArray(hMapList, i);
                
                // Add maps from exclude list to a second array as a fallback.
                if (bPreviousMap && MapHasNavigationMesh(sMapBuffer)
                        && FindStringInArray(hCustomExcludes, sMapBuffer) == -1) {
                    PushArrayString(hValidPreviousMaps, sMapBuffer);
                }
            }
        }
        
        // Pick random map from valid candidates.
        decl String:sNextMapOverride[MAP_NAME_LENGTH];
        if (GetArraySize(hMapList) > 0) {
            GetArrayString(hMapList, GetRandomInt(0, GetArraySize(hMapList) - 1), sNextMapOverride, MAP_NAME_LENGTH);
        } else {
            GetArrayString(hValidPreviousMaps, GetRandomInt(0, GetArraySize(hValidPreviousMaps) - 1), sNextMapOverride, MAP_NAME_LENGTH);
        }
        
        if (bChangeNow) {
            ForceChangeLevel(sNextMapOverride, "No active players -- changed to a bot-playable map."); 
        } else if (SetNextMap(sNextMapOverride)) {
            PrintToServer("[botchangemap] No active players.  Changed next map to %s", sNextMapOverride);
            bSuccess = true;
        }
        
        CloseHandle(hMapList);
        CloseHandle(hValidPreviousMaps);
        CloseHandle(hCustomExcludes);
        CloseHandle(hExcludedMaps);
    }
    return bSuccess;
}

public Hook_OnGameOver(Handle:hEvent, const String:sName[], bool:dontBroadcast) {
    decl String:sNextMap[MAP_NAME_LENGTH];
    new bool:bNextMapSet = GetNextMap(sNextMap, sizeof(sNextMap));
    
    if (GetLivePlayerCount() == 0) {
        new bool:bNextMapSuitable;
        bNextMapSuitable = bNextMapSet ?
            (MapIsNotCustomExcluded(sNextMap) && MapHasNavigationMesh(sNextMap)) : false;
        
        if (!bNextMapSuitable) {
            SetNextBotMap();
        }
    }
}

AddCustomMapExclusions(&Handle:hMapList) {
    new String:sExclusionFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sExclusionFilePath, PLATFORM_MAX_PATH, "data/botchangemap.txt");
    
    if (FileExists(sExclusionFilePath)) {
        new Handle:hCustomExclusionFile = OpenFile(sExclusionFilePath, "r");
        
        if (hCustomExclusionFile != INVALID_HANDLE) {
            decl String:sFileLine[MAP_NAME_LENGTH], String:sFilePath[PLATFORM_MAX_PATH];
            while (ReadFileLine(hCustomExclusionFile, sFileLine, sizeof(sFileLine))) {
                TrimString(sFileLine);
                Format(sFilePath, sizeof(sFilePath), "maps/%s.bsp", sFileLine);
                
                if (FileExists(sFilePath, true)) {
                    PushArrayString(hMapList, sFileLine);
                }
            }
            
            CloseHandle(hCustomExclusionFile);
        }
    }
}

bool:MapIsNotCustomExcluded(const String:sMapName[]) {
    new Handle:hCustomExcludes = CreateArray(MAP_NAME_LENGTH);
    AddCustomMapExclusions(hCustomExcludes);
    
    new bool:bAcceptable = (FindStringInArray(hCustomExcludes, sMapName) == -1);
    CloseHandle(hCustomExcludes);
    
    return bAcceptable;
}

bool:MapHasNavigationMesh(const String:sMapName[]) {
    decl String:sNavFileBuffer[PLATFORM_MAX_PATH];
    Format(sNavFileBuffer, sizeof(sNavFileBuffer), "maps/%s.nav", sMapName);
    
    return FileExists(sNavFileBuffer, true);
}

_:GetLivePlayerCount() {
    new nPlayers;
    for (new i = MaxClients; i > 0; --i) {
        if (IsClientInGame(i) && !IsFakeClient(i) && TFTeam:GetClientTeam(i) != TFTeam_Spectator) {
            nPlayers++;
        }
    }
    return nPlayers;
}
