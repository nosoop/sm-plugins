/**
 * Generic Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.0.1"     // Plugin version.

public Plugin:myinfo = {
    name = "[ANY] Text Logger - Core",
    author = "nosoop",
    description = "Log chat and other stuff to a text file.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new Handle:rg_hLogFiles[4] = { INVALID_HANDLE, ... };

public OnPluginStart() {
    // There isn't anything to start with...
}

public OnPluginEnd() {
    // Clean up all handles.
    for (new i = 0; i < sizeof(rg_hLogFiles); i++) {
        CloseTextLogFile(i);
    }
}

public OnMapStart() {
    new String:sMap[48], String:sMessage[512];
    GetCurrentMap(sMap, sizeof(sMap));
    
    CreateTextLogFile(0, sMap);
    
    Format(sMessage, sizeof(sMessage), "* Map changed to %s", sMap);
    TextLogToFile(0, sMessage);
}

CreateTextLogFile(handleIndex, const String:sLogName[]) {
    CloseTextLogFile(handleIndex);

    new String:sLogFileName[PLATFORM_MAX_PATH],
        String:sLogFullName[PLATFORM_MAX_PATH],
        String:sDateTime[64];
    
    FormatTime(sDateTime, sizeof(sDateTime), "%d%m%Y-%H%M%S");
    Format(sLogFileName, sizeof(sLogFileName), "/logs/chat-%s-%s.log", sDateTime, sLogName);
    BuildPath(Path_SM, sLogFullName, PLATFORM_MAX_PATH, sLogFileName);
    
    PrintToServer("Started logging to file %s.", sLogFileName);
    rg_hLogFiles[handleIndex] = OpenFile(sLogFullName, "a");
}

CloseTextLogFile(handleIndex) {
    if (rg_hLogFiles[handleIndex] == INVALID_HANDLE) {
        return;
    }

    TextLogToFile(handleIndex, "End of log.");
    CloseHandle(rg_hLogFiles[handleIndex]);
    rg_hLogFiles[handleIndex] = INVALID_HANDLE;
}

TextLogToFile(handleIndex, const String:sMessage[]) {
    new String:sDateTime[64];
    FormatTime(sDateTime, sizeof(sDateTime), "%Y/%m/%d %H:%M:%S");
    
    WriteFileLine(rg_hLogFiles[handleIndex], "%s %s", sDateTime, sMessage);
}