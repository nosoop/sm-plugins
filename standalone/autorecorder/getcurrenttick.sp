/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <autorecorder-mod>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "Get Demo Tick",
    author = "nosoop",
    description = "Spits out the tick value of the current demo.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

public OnPluginStart() {
    RegConsoleCmd("sm_gettick", Command_GetTick, "Returns the tick in the currently recording demo.");
}

public Action:Command_GetTick(client, args) {
    new iTick;
    iTick = GetApproximateDemoTick();
    
    if (iTick >= 0) {
        ReplyToCommand(client, "The current demo tick is: %d.", iTick);
    } else {
        ReplyToCommand(client, "A demo is not currently being recorded.");
    }
    
    return Plugin_Handled;
}
