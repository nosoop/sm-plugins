/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN                       // Support late loads.
#include <roundendsongs>

#define PLUGIN_VERSION          "0.2.1"     // Plugin version.

public Plugin:myinfo = {
    name = "Round End Music (SQLite)",
    author = "nosoop",
    description = "Extension of the Round End Music plugin to support SQLite databases.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

new Handle:g_hCDatabaseName = INVALID_HANDLE,           String:g_sDatabaseName[32],
    Handle:g_hCTableName = INVALID_HANDLE,              String:g_sTableName[32],
    Handle:g_hCSongDir = INVALID_HANDLE,                String:g_sSongDir[32];

// SQLite snippet to generate a number between 0 to 1 for each query.
// Source:  http://stackoverflow.com/a/23785593
new String:g_sRandomFunction[] = "(random() / 18446744073709551616 + 0.5)";

public OnPluginStart() {

    g_hCDatabaseName = CreateConVar("sm_rem_sqli_db", "roundendsongs", "Database entry in databases.cfg to load songs from.", FCVAR_PLUGIN|FCVAR_SPONLY);
    PrepareStringConVar(g_hCDatabaseName, g_sDatabaseName, sizeof(g_sDatabaseName));
    
    g_hCTableName = CreateConVar("sm_rem_sqli_tbl", "songdata", "Table to read songs from.", FCVAR_PLUGIN|FCVAR_SPONLY);
    PrepareStringConVar(g_hCTableName, g_sTableName, sizeof(g_sTableName));
    
    g_hCSongDir = CreateConVar("sm_rem_sqli_dir", "roundendsongs/", "Directory that the songs are located in, if not already defined as the full path in the database.", FCVAR_PLUGIN|FCVAR_SPONLY);
    PrepareStringConVar(g_hCSongDir, g_sSongDir, sizeof(g_sSongDir));
    
    // Execute configuration.
    AutoExecConfig(true, "plugin.rem_sqlite");
}

/**
 * Get a String value from a ConVar, store into a String and hook changes.  Pretty self-explanatory.
 */
PrepareStringConVar(Handle:hConVar, String:sValue[], nValueSize) {
    GetConVarString(hConVar, sValue, nValueSize);
    HookConVarChange(hConVar, OnConVarChanged);
}

public Action:REM_OnSongsRequested(nSongs) {
    // Connect to database.
    new Handle:hDatabase = GetSongDatabaseHandle();
    
    // Create sorter function.
    decl String:sWeightFunction[64];
    Format(sWeightFunction, sizeof(sWeightFunction),
            "((playcount + %d) * %s)", GetHighestPlayCount(hDatabase), g_sRandomFunction);
    
    decl String:sSongQuery[256];
    Format(sSongQuery, sizeof(sSongQuery),
            "SELECT artist,track,filepath FROM %s WHERE enabled = 1 ORDER BY %s LIMIT %d",
            g_sTableName, sWeightFunction, nSongs);
    
    new Handle:hSongQuery = SQL_Query(hDatabase, sSongQuery);
    
    decl String:rgsSongData[3][PLATFORM_MAX_PATH];
    while (SQL_FetchRow(hSongQuery)) {
        for (new i = 0; i < 3; i++) {
            SQL_FetchString(hSongQuery, i, rgsSongData[i], sizeof(rgsSongData[]));
        }
        
        // Append directory.
        Format(rgsSongData[ARRAY_FILEPATH], sizeof(rgsSongData[]), "%s%s", g_sSongDir, rgsSongData[ARRAY_FILEPATH]);
        REM_AddToQueue(rgsSongData[ARRAY_ARTIST], rgsSongData[ARRAY_TITLE], rgsSongData[ARRAY_FILEPATH]);
    }
    
    CloseHandle(hSongQuery);
    CloseHandle(hDatabase);
}

GetHighestPlayCount(Handle:hDatabase) {
    decl String:sPlayCountQuery[64];
    Format(sPlayCountQuery, sizeof(sPlayCountQuery),
            "SELECT MAX(playcount) FROM %s WHERE enabled=1",
            g_sTableName);
    new Handle:hPlayCountQuery = SQL_Query(hDatabase, sPlayCountQuery);
    
    SQL_FetchRow(hPlayCountQuery);
    new nTopPlays = SQL_FetchInt(hPlayCountQuery, 0);
    
    CloseHandle(hPlayCountQuery);
    
    return nTopPlays;
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
        SetFailState("[rem-sqlite] Could not find configuration %s for the Round End Songs database.", g_sDatabaseName);
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
    } else if (hConVar == g_hCSongDir) {
        strcopy(g_sSongDir, sizeof(g_sSongDir), sNewValue);
    }
}
