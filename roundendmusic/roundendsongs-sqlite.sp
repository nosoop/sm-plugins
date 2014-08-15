/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <roundendsongs>

#define PLUGIN_VERSION          "0.0.1"     // Plugin version.

public Plugin:myinfo = {
    name = "Round End Songs (SQLite)",
    author = "nosoop",
    description = "Extension of the Round End Songs plugin to support SQLite databases in a specific format.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

public Action:REM_OnSongsRequested(nSongs) {
    // TODO Select songs from an SQLite database.
}