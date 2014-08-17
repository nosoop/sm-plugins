/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION          "1.0.0"     // Plugin version.

#define ARRAY_ARTIST            0
#define ARRAY_TITLE             1
#define ARRAY_FILEPATH          2

#define STR_ARTIST_LENGTH       48          // Maximum length of an artist name.
#define STR_TITLE_LENGTH        48          // Maximum length of a song title.

#define CELL_PLAYCOUNT          1

#define MAX_DOWNLOAD_COUNT      5           // Temporary.

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

// Contains pointer to a shuffled track and a boolean to determine if the track was played this map.
new Handle:g_hTrackNum = INVALID_HANDLE;

new Handle:g_hFRequestSongs = INVALID_HANDLE,   // Global forward to notify that songs are needed.
    Handle:g_hFSongPlayed = INVALID_HANDLE;     // Global forward to notify that a song was played.

public OnPluginStart() {
    // Initialize cvars and arrays.
    // -- Plugin enabled (boolean).
    // -- Number of songs to download (positive integer).
    // -- Reshuffle queued tracks (boolean)
    
    // Register commands.
    RegAdminCmd("sm_playsong", Command_PlaySong, ADMFLAG_ROOT, "Play a round-end song (for debugging).");
    RegAdminCmd("sm_rem_rerollsongs", Command_RerollSongs, ADMFLAG_ROOT, "Redo round end music (for debugging).");
    RegConsoleCmd("sm_songlist", Command_DisplaySongList, "Opens a menu with the current song listing.");
    
    // Initialize the arrays.
    g_hSongData[ARRAY_ARTIST] = CreateArray(STR_ARTIST_LENGTH);
    g_hSongData[ARRAY_TITLE] = CreateArray(STR_TITLE_LENGTH);
    g_hSongData[ARRAY_FILEPATH] = CreateArray(PLATFORM_MAX_PATH);
    
    g_hTrackNum = CreateArray(2);
    
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
    CreateTimer(4.3, Timer_PlayEndRound, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_PlayEndRound(Handle:timer, any:data) {
    PlayEndRoundSong(GetNextSong());
    return Plugin_Handled;
}

PlayEndRoundSong(iSong) {
    decl String:sSongArtist[STR_ARTIST_LENGTH],
        String:sSongTitle[STR_TITLE_LENGTH],
        String:sSoundPath[PLATFORM_MAX_PATH];
    GetArrayString(g_hSongData[ARRAY_ARTIST], iSong, sSongArtist, sizeof(sSongArtist));
    GetArrayString(g_hSongData[ARRAY_TITLE], iSong, sSongTitle, sizeof(sSongTitle));
    GetArrayString(g_hSongData[ARRAY_FILEPATH], iSong, sSoundPath, sizeof(sSoundPath));
    
    // Increase playcount.
    SetArrayCell(g_hTrackNum, iSong, GetArrayCell(g_hTrackNum, iSong, 1) + 1, CELL_PLAYCOUNT);
    
    // Play song.
    EmitSoundToAll(sSoundPath);
    
    Call_StartForward(g_hFSongPlayed);
    Call_PushString(sSoundPath);
    Call_Finish();
    
    // Show song information in chat.
    // TODO Nice coloring.
    PrintToChatAll("\x01You are listening to \x04%s\x01 from \x04%s\x01!", sSongTitle, sSongArtist);
    PrintToServer("[rem] Played song %d of %d (%s)", iSong + 1, g_nSongsAdded, sSoundPath);
}

QueueSongs() {
    // TODO Clear songs that have not been played (cvar configurable).
    new iSongCheck;
    while (g_nSongsAdded > iSongCheck) {
        if (GetArrayCell(g_hTrackNum, iSongCheck, CELL_PLAYCOUNT) > 0) {
            for (new i = 0; i < 3; i++) {
                RemoveFromArray(g_hSongData[i], iSongCheck);
            }
            RemoveFromArray(g_hTrackNum, iSongCheck);
            g_nSongsAdded--;
        } else {
            iSongCheck++;
        }
    }

    // Call global forward to request songs.
    new Action:result;
    Call_StartForward(g_hFRequestSongs);
    Call_PushCell(MAX_DOWNLOAD_COUNT);
    Call_Finish(result);
    
    // Initialize shuffler.
    ClearArray(g_hTrackNum);
    
    decl String:sSongPath[PLATFORM_MAX_PATH], String:sFilePath[PLATFORM_MAX_PATH];
    for (new i = 0; i < GetArraySize(g_hSongData[ARRAY_FILEPATH]); i++) {
        GetArrayString(g_hSongData[ARRAY_FILEPATH], i, sSongPath, sizeof(sSongPath));
        PrecacheSound(sSongPath);
        
        Format(sFilePath, sizeof(sFilePath), "sound/%s", sSongPath);
        AddFileToDownloadsTable(sFilePath);
        
        new track = PushArrayCell(g_hTrackNum, i);
        SetArrayCell(g_hTrackNum, track, 0, CELL_PLAYCOUNT);
        
        PrintToServer("[rem] Added song %d: %s", i, sSongPath);
    }
    
    // Shuffle pointers with Fisher-Yates.  Source because I don't know it off the top of my head:
    // http://spin.atomicobject.com/2014/08/11/fisher-yates-shuffle-randomization-algorithm/
    new nTracks = GetArraySize(g_hTrackNum);
    for (new i = 0; i < nTracks; i++) {
        new j = GetRandomInt(i, nTracks - 1);
        SwapArrayItems(g_hTrackNum, i, j);
    }
}

GetNextSong() {
    new iTrack = GetArrayCell(g_hTrackNum, g_iTrack++);
    g_iTrack %= g_nSongsAdded;
    return iTrack;
}

/**
 * Adds a song to the queue.  Returns true if the song was added, false otherwise.
 */
bool:AddToQueue(const String:sArtist[], const String:sTrack[], const String:sFilePath[]) {
    if (FindStringInArray(g_hSongData[ARRAY_FILEPATH], sFilePath) == -1 && g_nSongsAdded < MAX_DOWNLOAD_COUNT) {
        PushArrayString(g_hSongData[ARRAY_ARTIST], sArtist);
        PushArrayString(g_hSongData[ARRAY_TITLE], sTrack);
        PushArrayString(g_hSongData[ARRAY_FILEPATH], sFilePath);
        g_nSongsAdded++;
        return true;
    }
    return false;
}

public Native_AddToQueue(Handle:plugin, numParams) {
    decl String:rgsSongData[3][PLATFORM_MAX_PATH];
    
    for (new i = 0; i < 3; i++) {
        GetNativeString(i+1, rgsSongData[i], PLATFORM_MAX_PATH);
    }
    
    return AddToQueue(rgsSongData[ARRAY_ARTIST], rgsSongData[ARRAY_TITLE], rgsSongData[ARRAY_FILEPATH]);
}

public Action:Command_PlaySong(client, args) {
    new iTrack;
    if (args > 0) {
        decl String:num[4];
        GetCmdArg(1, num, sizeof(num));
        iTrack = StringToInt(num) % g_nSongsAdded;
    } else {
        iTrack = GetNextSong();
    }

    PlayEndRoundSong(iTrack);
    return Plugin_Handled;
}

public Action:Command_RerollSongs(client, args) {
    PrintToServer("[rem] Songlist requeued by %N -- be sure to reconnect.", client);
    QueueSongs();
    return Plugin_Handled;
}

public Action:Command_DisplaySongList(client, args) {
    // TODO Implement client-viewable song list plus detailed output in console.
    new Handle:hPanel = CreatePanel();
    SetPanelTitle(hPanel, "What we have playing on this map:\n(Unplayed songs roll over to the next map.)");
    
    decl String:sMenuBuffer[64], String:rgsSongData[2][PLATFORM_MAX_PATH];
    
    for (new i = 0; i < g_nSongsAdded; i++) {
        for (new d = 0; d < 2; d++) {
            GetArrayString(g_hSongData[d], i, rgsSongData[d], sizeof(rgsSongData[]));
        }
        Format(sMenuBuffer, sizeof(sMenuBuffer),
                "'%s' from %s", rgsSongData[ARRAY_TITLE], rgsSongData[ARRAY_ARTIST]);
        // TODO restrict size of entry
        // TODO Spit detailed output to console.
        
        DrawPanelItem(hPanel, sMenuBuffer);
    }

    SendPanelToClient(hPanel, client, SongListHandler, 20);
    CloseHandle(hPanel);
    return Plugin_Handled;
}

public SongListHandler(Handle:menu, MenuAction:action, client, selection) {
    if (action == MenuAction_Select) {
        // TODO ?
    }
}
