/**
 * Generic Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.1.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Text Logger",
    author = "nosoop",
    description = "Log chat and other stuff to a text file.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new Handle:rg_hLogFiles[4] = { INVALID_HANDLE, ... };

public OnPluginStart() {
    // Register for say events.
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_SayTeam);
}

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
    
    FormatTime(sDateTime, sizeof(sDateTime), "%d%m%Y-%H%M%S");
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
    new String:sMap[48], String:sMessage[512];
    GetCurrentMap(sMap, sizeof(sMap));
    
    CreateTextLogFile(0, sMap);
    
    Format(sMessage, sizeof(sMessage), "* Map changed to %s", sMap);
    TextLogToFile(0, sMessage);
}

/**
 * Say events.
 */
public Action:Command_Say(client, args) {
    if (IsChatTrigger()) {
        return;
    }

    new String:sTextMessage[512];
    GetCmdArgString(sTextMessage, sizeof(sTextMessage));
    StripQuotes(sTextMessage);
    
    LogSayMessage(client, sTextMessage, false);
}

public Action:Command_SayTeam(client, args) {
    if (IsChatTrigger()) {
        return;
    }

    new String:sTextMessage[512];
    GetCmdArgString(sTextMessage, sizeof(sTextMessage));
    StripQuotes(sTextMessage);
    
    LogSayMessage(client, sTextMessage, true);
}

LogSayMessage(client, String:sMessage[], bool:bTeamMessage) {    
    new String:sTextMessage[512];
    Format(sTextMessage, sizeof(sTextMessage), "%s%N : %s", bTeamMessage ? "(TEAM) " : "", client, sMessage);

    TextLogToFile(0, sTextMessage);
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
