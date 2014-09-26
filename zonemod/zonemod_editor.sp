/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "Plugin name!",
    author = "Author!",
    description = "Description!",
    version = PLUGIN_VERSION,
    url = "localhost"
}

public OnPluginStart() {

}

public OnMapStart() {

}

public OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]) {

}