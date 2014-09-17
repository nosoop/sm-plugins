/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN                       // Support late loads.
#include <roundendsongs>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "Round End Music (Flat Configuration)",
    author = "nosoop",
    description = "Extension of the Round End Music plugin to support a flat configuration file.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

new Handle:g_hSongKeyValues = INVALID_HANDLE,
    Handle:g_rghSongFilenames = INVALID_HANDLE;

public OnPluginStart() {
    g_rghSongFilenames = CreateArray(PLATFORM_MAX_PATH);
    g_hSongKeyValues = CreateKeyValues("roundendsongs");
}

public Action:REM_OnSongsRequested(nSongs) {
    LoadSongList();
    
    new nSongsAvailable = GetArraySize(g_rghSongFilenames);
    for (new i = 0; i < nSongsAvailable; i++) {
        new j = GetRandomInt(i, nSongsAvailable - 1);
        SwapArrayItems(g_rghSongFilenames, i, j);
    }
    
    KvRewind(g_hSongKeyValues);
    
    new iSong;
    new String:rgsSongData[3][PLATFORM_MAX_PATH], bSongAdded;
    do {
        GetArrayString(g_rghSongFilenames, iSong, rgsSongData[ARRAY_FILEPATH], PLATFORM_MAX_PATH);
        iSong++;

        KvGotoFirstSubKey(g_hSongKeyValues);
        
        decl String:sPathBuffer[PLATFORM_MAX_PATH];
        bSongAdded = false;
        // TODO Optimize to jump directly to keyvalue?  I HAVE NO IDEA HOW
        do {
            KvGetSectionName(g_hSongKeyValues, sPathBuffer, PLATFORM_MAX_PATH);
            if (StrEqual(rgsSongData[ARRAY_FILEPATH], sPathBuffer)) {
                KvGetString(g_hSongKeyValues, "title", rgsSongData[ARRAY_TITLE], PLATFORM_MAX_PATH, "?");
                KvGetString(g_hSongKeyValues, "artist", rgsSongData[ARRAY_ARTIST], PLATFORM_MAX_PATH, "?");
                bSongAdded = REM_AddToQueue(rgsSongData[ARRAY_ARTIST], rgsSongData[ARRAY_TITLE], rgsSongData[ARRAY_FILEPATH]);
            }
        } while (KvGotoNextKey(g_hSongKeyValues));
        KvRewind(g_hSongKeyValues);
    } while (bSongAdded && iSong < nSongsAvailable);
}


LoadSongList() {
    new String:sSongFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sSongFilePath, sizeof(sSongFilePath), "data/roundendsongs.txt");

    if (!FileExists(sSongFilePath)) {
        SetFailState("Song list file not found.");
    } else {
        if (g_hSongKeyValues != INVALID_HANDLE) {
            CloseHandle(g_hSongKeyValues);
            ClearArray(g_rghSongFilenames);
        }
        
        g_hSongKeyValues = CreateKeyValues("roundendsongs");
        FileToKeyValues(g_hSongKeyValues, sSongFilePath);
        
        KvGotoFirstSubKey(g_hSongKeyValues);
        
        decl String:buffer[PLATFORM_MAX_PATH];
        do {
            KvGetSectionName(g_hSongKeyValues, buffer, sizeof(buffer));
            PushArrayString(g_rghSongFilenames, buffer);
        } while (KvGotoNextKey(g_hSongKeyValues));
    }
}