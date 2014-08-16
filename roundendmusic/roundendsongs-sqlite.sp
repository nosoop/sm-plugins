/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN                       // Support late loads.
#include <roundendsongs>

#define PLUGIN_VERSION          "0.1.0"     // Plugin version.

public Plugin:myinfo = {
    name = "Round End Music (SQLite)",
    author = "nosoop",
    description = "Extension of the Round End Music plugin to support SQLite databases.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

new Handle:g_hCDatabaseName = INVALID_HANDLE,           String:g_sDatabaseName[32],
    Handle:g_hCTableName = INVALID_HANDLE,              String:g_sTableName[32];

public OnPluginStart() {
    // Hook database.
    g_hCDatabaseName = CreateConVar("sm_rem_sqli_db", "roundendsongs", "Database entry in databases.cfg to load songs from.", FCVAR_PLUGIN|FCVAR_SPONLY);
    g_hCTableName = CreateConVar("sm_rem_sqli_tbl", "songdata", "Table to read songs from.", FCVAR_PLUGIN|FCVAR_SPONLY);
    
    HookConVarChange(g_hCDatabaseName, OnConVarChanged);
    HookConVarChange(g_hCTableName, OnConVarChanged);
    
    // Execute configuration.
    AutoExecConfig(true, "plugin.rem_sqlite");
}

public Action:REM_OnSongsRequested(nSongs) {
    // Connect to database.
    new Handle:hDatabase = GetSongDatabaseHandle();
    
    // TODO Implement database fetching.  For now, we're using a sample song to test the functionality of REM.
    REM_AddToQueue("please ignore", "Test post", "test/alpha2.mp3");
}

/**
 * Gets a handle on the SQLite database.
 */
Handle:GetSongDatabaseHandle() {
    new Handle:hDatabase = INVALID_HANDLE;
    
    if (SQL_CheckConfig(g_sDatabaseName)) {
        decl String:sErrorBuffer[256];
        if ( (hDatabase = SQL_Connect(g_sDatabaseName, true, sErrorBuffer, sizeof(sErrorBuffer))) == INVALID_HANDLE ) {
            SetFailState("[rem-sqlite] Could not connect to Round End Songs database: %s", sErrorBuffer);
        } else {
            return hDatabase;
        }
    } else {
        SetFailState("[rem-sqlite] Could not find configuration for the Round End Songs database.");
    }
    return INVALID_HANDLE;
}

/**
 * TODO Get the highest playcount and do song weighting?
 */
public OnConVarChanged(Handle:hConVar, const String:sOldValue[], const String:sNewValue[]) {
    if (hConVar == g_hCDatabaseName) {
        strcopy(g_sDatabaseName, sizeof(g_sDatabaseName), sNewValue);
    } else if (hConVar == g_hCTableName) {
        strcopy(g_sTableName, sizeof(g_sTableName), sNewValue);
    }
}
