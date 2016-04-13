/**
 * Generic Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <scp>

#define PLUGIN_VERSION          "0.3.1"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Text Logger",
    author = "nosoop",
    description = "Log chat and other stuff to a text file.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new Handle:rg_hLogFiles[4] = { INVALID_HANDLE, ... };
new bool:g_rgbReceivedMessage[MAXPLAYERS+1];

public OnPluginEnd() {
    // Clean up all handles.
    for (new i = 0; i < sizeof(rg_hLogFiles); i++) {
        CloseTextLogFile(i);
    }
}

/**
 * Generic logging capabilities.
 */
CreateTextLogFile(handleIndex, const String:sLogName[]) {
    CloseTextLogFile(handleIndex);

    new String:sLogFileName[PLATFORM_MAX_PATH],
        String:sLogFullName[PLATFORM_MAX_PATH],
        String:sDateTime[64];
    
    FormatTime(sDateTime, sizeof(sDateTime), "%Y%m%d-%H%M%S");
	
    Format(sLogFileName, sizeof(sLogFileName), "/logs/chat-%s-%s.log", sDateTime, sLogName);
    BuildPath(Path_SM, sLogFullName, PLATFORM_MAX_PATH, sLogFileName);
    
    PrintToServer("Started logging to file %s, handle %d.", sLogFileName, handleIndex);
    rg_hLogFiles[handleIndex] = OpenFile(sLogFullName, "a");
}

CloseTextLogFile(handleIndex) {
    if (rg_hLogFiles[handleIndex] == INVALID_HANDLE) {
        return;
    }

    TextLogToFile(handleIndex, "End of log.");
    PrintToServer("Stopped logging on log handle %d.", handleIndex);
    CloseHandle(rg_hLogFiles[handleIndex]);
    rg_hLogFiles[handleIndex] = INVALID_HANDLE;
}

TextLogToFile(handleIndex, const String:sMessage[]) {
    new String:sDateTime[64];
    FormatTime(sDateTime, sizeof(sDateTime), "%Y/%m/%d %H:%M:%S");
    
    WriteFileLine(rg_hLogFiles[handleIndex], "%s %s", sDateTime, sMessage);
}

/**
 * Map change -- close existing log file on handle 0 and open a new one.
 */
public OnMapStart() {
    new String:sMap[64], String:sMessage[512];
    GetCurrentMap(sMap, sizeof(sMap));
	
	TrimWorkshopMapName(sMap, sizeof(sMap));
    
    CreateTextLogFile(0, sMap);
    
    Format(sMessage, sizeof(sMessage), "* Map changed to %s", sMap);
    TextLogToFile(0, sMessage);
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[]) { 
    new String:sTextMessage[512];
    
    new flags = GetMessageFlags();
    new bTeamMessage = flags & CHATFLAGS_TEAM == CHATFLAGS_TEAM;
    
	if (!IsFakeClient(author)) {
		Format(sTextMessage, sizeof(sTextMessage), "%s%N : %s", bTeamMessage ? "(TEAM) " : "", author, message);

		TextLogToFile(0, sTextMessage);
		CreateTimer(0.01, Timer_UnsetChatDelay, author);
	}
    return Plugin_Continue;
}

public Action:Timer_UnsetChatDelay(Handle:timer, any:client) {
    g_rgbReceivedMessage[client] = false;
}

/**
 * Connect event.
 */
public OnClientPostAdminCheck(client) {
    if (IsFakeClient(client)) {
        return;
    }
    
    new String:steamID[128];
    GetClientAuthString(client, steamID, sizeof(steamID));
    
    new String:sJoinMessage[512];
    Format(sJoinMessage, sizeof(sJoinMessage), "Player %N (%s) connected.", client, steamID);
    TextLogToFile(0, sJoinMessage);
}

stock TrimWorkshopMapName(String:map[], size) {
	if (StrContains(map, "workshop/", true) == 0) {
		// Trim off workshop directory
		strcopy(map, size, map[9]);
		
		// Strip off the map ID onwards
		strcopy(map, StrContains(map, ".ugc") + 1, map);
	}
}