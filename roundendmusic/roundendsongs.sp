/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION          "0.1.0"     // Plugin version.

#define ARRAY_ARTIST            0
#define ARRAY_TITLE             1
#define ARRAY_FILEPATH          2

#define STR_ARTIST_LENGTH       48          // Maximum length of an artist name.
#define STR_TITLE_LENGTH        48          // Maximum length of a song title.

public Plugin:myinfo = {
    name = "Round End Music",
    author = "nosoop",
    description = "A plugin to queue up a number of songs to play during the end round.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

new g_iTrack, g_nSongsAdded;

// Contains title, artist / source, and file path, respectively.
new Handle:g_hSongData[3] = { INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE };
new Handle:g_hTrackNum = INVALID_HANDLE;

new Handle:g_hFRequestSongs = INVALID_HANDLE,   // Global forward to notify that songs are needed.
    Handle:g_hFSongPlayed = INVALID_HANDLE;     // Global forward to notify that a song was played.

public OnPluginStart() {
    // Initialize cvars and arrays.
    // -- Plugin enabled (boolean).
    // -- Number of songs to download (positive integer).
    // -- Reshuffle queued tracks (boolean)
    
    // Register commands.
    RegAdminCmd("sm_playsong", Command_PlaySong, ADMFLAG_ROOT, "Play a round-end song.");
    RegConsoleCmd("sm_songlist", Command_DisplaySongList, "Opens a menu with the current song listing.");
    
    // Initialize the arrays.
    g_hSongData[ARRAY_ARTIST] = CreateArray(STR_ARTIST_LENGTH);
    g_hSongData[ARRAY_TITLE] = CreateArray(STR_TITLE_LENGTH);
    g_hSongData[ARRAY_FILEPATH] = CreateArray(PLATFORM_MAX_PATH);
    
    // Hook endround.
    HookEvent("teamplay_round_win", Event_RoundEnd);
    
    // Init global forwards.
    g_hFRequestSongs = CreateGlobalForward("REM_OnSongsRequested", ET_Hook, Param_Cell);
    g_hFSongPlayed = CreateGlobalForward("REM_OnSongPlayed", ET_Ignore, Param_String);
}

public APLRes:AskPluginLoad2(Handle:hMySelf, bool:bLate, String:strError[], iMaxErrors) {
    RegPluginLibrary("nosoop-roundendmusic");
    CreateNative("REM_AddToQueue", Native_AddToQueue);
    return APLRes_Success;
}

public OnMapStart() {
	QueueSongs();
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
    // TODO Timer for round end and start playing song.
    CreateTimer(4.3, Timer_PlayEndRound, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_PlayEndRound(Handle:timer, any:data) {
    // ...
    return Plugin_Handled;
}

PlayEndRoundSong(iSong) {
    decl String:sSoundPath[PLATFORM_MAX_PATH];
    GetArrayString(g_hSongData[ARRAY_FILEPATH], 0, sSoundPath, sizeof(sSoundPath));
    EmitSoundToAll(sSoundPath);
}

QueueSongs() {
    // TODO Clear songs that have not been played (cvar configurable).
    for (new i = 0; i < 3; i++) {
        ClearArray(g_hSongData[i]);
    }

    // Call global forward to request songs.
    new Action:result;
    Call_StartForward(g_hFRequestSongs);
    Call_PushCell(5);
    Call_Finish(result);
    
    decl String:sSoundPath[PLATFORM_MAX_PATH];
    decl String:sFilePath[PLATFORM_MAX_PATH];
    for (new i = 0; i < GetArraySize(g_hSongData[ARRAY_FILEPATH]); i++) {
        GetArrayString(g_hSongData[ARRAY_FILEPATH], i, sSoundPath, sizeof(sSoundPath));
        PrecacheSound(sSoundPath);
        
        Format(sFilePath, sizeof(sFilePath), "sound/%s", sFilePath);
        AddFileToDownloadsTable(sFilePath);
        
        PrintToServer("Queued song %d: %s from %s (file %s).", i, sTrack, sArtist, sFilePath);
    }
    
    // TODO Shuffle songs.
}

/**
 * Adds a song to the queue.  Returns true if the song was added, false otherwise.
 */
bool:AddToQueue(const String:sArtist[], const String:sTrack[], const String:sFilePath[]) {
    if (FindStringInArray(g_hSongData[ARRAY_FILEPATH], sFilePath) == -1) {
        new index = PushArrayString(g_hSongData[ARRAY_ARTIST], sArtist);
        PushArrayString(g_hSongData[ARRAY_TITLE], sTrack);
        PushArrayString(g_hSongData[ARRAY_FILEPATH], sFilePath);
        return true;
    }
    return false;
}

public Native_AddToQueue(Handle:plugin, numParams) {
    decl String:rgsSongData[3][PLATFORM_MAX_PATH];
    
    decl nStrLength;
    for (new i = 0; i < 3; i++) {
        GetNativeStringLength(i+1, nStrLength);
        GetNativeString(i+1, rgsSongData[i], PLATFORM_MAX_PATH);
    }
    
    return AddToQueue(rgsSongData[ARRAY_ARTIST], rgsSongData[ARRAY_TITLE], rgsSongData[ARRAY_FILEPATH]);
}

public Action:Command_PlaySong(client, args) {
    // TODO Cycle through round end songs or something.
    PlayEndRoundSong(0);
    return Plugin_Handled;
}

public Action:Command_DisplaySongList(client, args) {
    // TODO Implement client-viewable song list plus detailed output in console.
    return Plugin_Handled;
}
