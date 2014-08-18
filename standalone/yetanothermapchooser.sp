/**
 * "Yet Another Map Chooser", by nosoop
 *
 * The goal is to have a fairly lightweight map voting plugin.
 * It will use a basic keyvalues file with the following setup:
 *     "map_name|Display Name" "Float:relativeweight"
 * 
 * If it gets nominated, it gets pushed to the top of the vote pile.
 * It excludes the current map and a set number of previous maps.
 * It also excludes maps of the same prefix as the current map.
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "Yet Another Map Chooser",
    author = "nosoop",
    description = "As if we needed more map plugins to pick from!",
    version = PLUGIN_VERSION,
    url = "localhost"
}

public OnPluginStart() {

}

public OnMapStart() {

}
