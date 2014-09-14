/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <scp>

#define PLUGIN_VERSION          "1.0.0"     // Plugin version.

#define CHAT_STANDARD           0
#define CHAT_ALL                1
#define CHAT_ALLTALK            2

#define TEAMCHAT_STANDARD       0
#define TEAMCHAT_ALLTEAM        1
#define TEAMCHAT_ALL            2

public Plugin:myinfo = {
    name = "AllChat (SCP)",
    author = "nosoop",
    description = "Relays chat messages to all applicable players via Simple Chat Processor",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

new Handle:g_hCvarAllTalk = INVALID_HANDLE,
    Handle:g_hCvarMode = INVALID_HANDLE,
    Handle:g_hCvarTeam = INVALID_HANDLE;

// Quick fix for multiple one-recipient messages.  (Why do they happen?)
new bool:g_rgbReceivedMessage[MAXPLAYERS+1];

public OnPluginStart() {
    g_hCvarAllTalk = FindConVar("sv_alltalk");
    g_hCvarMode = CreateConVar("sm_allchat_mode", "2", "Relays chat messages to all players? 0 = No, 1 = Yes, 2 = If AllTalk On", FCVAR_PLUGIN, true, 0.0, true, 2.0);
    g_hCvarTeam = CreateConVar("sm_allchat_team", "1", "Who can see say_team messages? 0 = Default, 1 = All teammates, 2 = All players", FCVAR_PLUGIN, true, 0.0, true, 2.0);
    
    AutoExecConfig(true, "allchat");
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[]) {
    if (g_rgbReceivedMessage[author]) {
        return Plugin_Stop;
    } else {
        g_rgbReceivedMessage[author] = true;
    }

    PrintToServer("Message from %s: %s (recipients %d)", name, message, GetArraySize(recipients));
    new mode = GetConVarInt(g_hCvarMode), teamMode = GetConVarInt(g_hCvarTeam);
    new flags = GetMessageFlags();
    
    for (new i = 0; i < GetArraySize(recipients); i++) {
        PrintToServer("%d", GetArrayCell(recipients, i));
    }
    
    if (mode == CHAT_STANDARD
            || mode == CHAT_ALLTALK && !GetConVarBool(g_hCvarAllTalk)) {
        return Plugin_Continue;
    }
    
    if ( (flags & CHATFLAGS_TEAM == CHATFLAGS_TEAM) && (teamMode == TEAMCHAT_STANDARD) ) {
        return Plugin_Continue;
    }
    
    ClearArray(recipients);
    if ( (flags & CHATFLAGS_TEAM == CHATFLAGS_TEAM) && (teamMode == TEAMCHAT_ALLTEAM) ) {
        new team = GetClientTeam(author);
        
        // Push team message to all team members.
        for (new i = MaxClients; i > 0; --i) {
            if (IsClientInGame(i) && GetClientTeam(i) == team) {
                PushArrayCell(recipients, i);
            }
        }
    } else {
        for (new i = MaxClients; i > 0; --i) {
            if (IsClientInGame(i)) {
                PushArrayCell(recipients, i);
            }
        }
    }
    PrintToServer("Post-message from %s: %s (recipients %d)", name, message, GetArraySize(recipients));
    
    CreateTimer(0.01, Timer_UnsetChatDelay, author);
    return Plugin_Changed;
}

public Action:Timer_UnsetChatDelay(Handle:timer, any:client) {
    g_rgbReceivedMessage[client] = false;
}