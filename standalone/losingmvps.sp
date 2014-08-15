/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <tf2>

#define PLUGIN_VERSION          "1.0.1"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Losing Team MVPs",
    author = "nosoop",
    description = "Text chat printout for MVPs on the losing team",
    version = PLUGIN_VERSION,
    url = "localhost"
}

new g_offsTotalScore, g_rgnStartingScore[MAXPLAYERS+1];
new g_nTopPlayerCount = 3;

public OnPluginStart() {
    // Majority of the code was taken from the "Win panel for losing team" plugin by Reflex.
    HookEventEx("teamplay_round_start", Event_RoundStart);
    HookEventEx("teamplay_win_panel", Event_WinPanel);
    
    if ( (g_offsTotalScore = FindSendPropOffs("CTFPlayerResource", "m_iTotalScore")) == -1 ) {
        SetFailState("Failed to find property offset for player scoring.");
    }
    
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i)) {
            g_rgnStartingScore[i] = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iTotalScore", _, i);
        }
    }
}

public Event_WinPanel(Handle:event, const String:name[], bool:dontBroadcast) {
    new winningTeam = TFTeam:GetEventInt(event, "winning_team");
	if (winningTeam == TFTeam_Red || winningTeam == TFTeam_Blue) {
		new losingTeam = (winningTeam == TFTeam_Red) ? TFTeam_Blue : TFTeam_Red;
		CreateTimer(0.1, Timer_ShowLosingMVPs, losingTeam);
	}
}

public OnClientPostAdminCheck(client) {
    g_rgnStartingScore[client] = 0;
}

#define CLIENTID    0
#define SCORE       1

public Action:Timer_ShowLosingMVPs(Handle:timer, any:losingTeam) {
    // First dimension is number of players (ranked), second dimension holds client id and score.
    new validPlayers;
    
    // Size of array is number of players to include.  First block holds client id, second block holds round score.
    new Handle:rgLosers = CreateArray(2, g_nTopPlayerCount);
    
    // Initialize the array in scores.
    for (new r = 0; r < GetArraySize(rgLosers); r++) {
        SetArrayCell(rgLosers, r, 0, SCORE);
    }
    
    for (new c = 1; c < MaxClients; c++) {
        if (IsClientInGame(c) && TFTeam:GetClientTeam(c) == losingTeam) {
            new playerRoundScore = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iTotalScore", _, c) - g_rgnStartingScore[c];
            
            new bool:inserted;
            // Insert into top n players if score is larger than one of the n players.
            // Quit checking if we are checking past the top n players or if the score has been inserted.
            for (new j = 0; j < GetArraySize(rgLosers) && !inserted; j++) {
                if (playerRoundScore > GetArrayCell(rgLosers, j, SCORE)) {
                    ShiftArrayUp(rgLosers, j);
                    SetArrayCell(rgLosers, j, c, CLIENTID);
                    SetArrayCell(rgLosers, j, playerRoundScore, SCORE);
                    
                    // Cap valid players at count of top n players.
                    validPlayers = (validPlayers < g_nTopPlayerCount) ? validPlayers + 1 : g_nTopPlayerCount;
                    inserted = true;
                }
            }
        }
    }
    
    if (validPlayers > 0) {
        decl String:messageBuffer[512];
        
        new String:teamColor[16];
        teamColor = (TFTeam:losingTeam == TFTeam_Red ? "{RED}" : "{BLUE}");
        
        Format(messageBuffer, sizeof(messageBuffer),
                "Top scoring players on %s%s{DEFAULT}:", teamColor, TFTeam:losingTeam == TFTeam_Red ? "RED" : "BLU");
        
        // Top three players on [LOSING TEAM]:
        // %N (%d points), ...
        // GetArrayCell(rgLosers, j, CLIENTID), 
        decl String:scoreBuffer[64];
        for (new p = 0; p < validPlayers; p++) {
            new client = GetArrayCell(rgLosers, p, CLIENTID);
            new score = GetArrayCell(rgLosers, p, SCORE);
            
            // Example:  {RED}0xDEADBEEF{DEFAULT} (12 points)
            Format(scoreBuffer, sizeof(scoreBuffer), "%s%N{DEFAULT} (%d points)", teamColor, client, score);
            
            // Append new player to buffer and append a comma if there are more players to add.
            Format(messageBuffer, sizeof(messageBuffer), "%s %s%s", messageBuffer, scoreBuffer, (p+1 < validPlayers ? "," : ""));
        }
        
        CPrintToChatAll(messageBuffer);
    }
    
    CloseHandle(rgLosers);
}