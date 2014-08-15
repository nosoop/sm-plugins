/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION          "0.0.1"     // Plugin version.

public Plugin:myinfo = {
    name = "Round End Music",
    author = "nosoop",
    description = "A plugin to queue up a number of songs to play during the end round.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

// Contains title, artist / source, and file path, respectively.
new Handle:g_hSongData[3] = { INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE };
new Handle:g_hTrackNum = INVALID_HANDLE;

new Handle:g_hFRequestSongs = INVALID_HANDLE,   // Global forward to notify that songs are needed.
    Handle:g_hFSongPlayed = INVALID_HANDLE;     // Global forward to notify that a song was played.

public OnPluginStart() {
    // Initialize cvars and arrays.
    // -- Plugin enabled (boolean).
    // -- Number of songs to download (read on map change) (positive integer).
    // -- Reshuffle queued tracks (boolean)
    
    // Hook endround.
    HookEvent("teamplay_round_win", Event_RoundEnd);
    
    // Init global forwards.
    g_hFRequestSongs = CreateGlobalForward("REM_OnSongsRequested", ET_Hook, Param_Cell);
    g_hFSongPlayed = CreateGlobalForward("REM_OnSongPlayed", ET_Ignore, Param_String);
}

public APLRes:AskPluginLoad2(Handle:hMySelf, bool:bLate, String:strError[], iMaxErrors) {
    RegPluginLibrary("nosoop-roundendmusic");
    return APLRes_Success;
}

public OnMapStart() {
	QueueSongs();
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
    // TODO Timer for round end and start playing song.
}

QueueSongs() {
    // TODO Clear songs that have not been played (cvar configurable).
    // TODO Call global forward to request songs.
    // TODO Shuffle songs and preload.
}

/**
 * Adds a song to the queue.  Returns true if the song was added, false otherwise.
 */
bool:AddToQueue(const String:sArtist[], const String:sTrack[], const String:sFilePath[]) {
    // TODO Add song if not finding a matching filepath.
    // TODO Native.
    return false;
}