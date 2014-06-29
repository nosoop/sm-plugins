#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

#define PL_VERSION "1.0.0"

#define TF_CLASS_SCOUT			1
#define TF_CLASS_SOLDIER		3
#define TF_CLASS_PYRO			7
#define TF_CLASS_DEMOMAN		4
#define TF_CLASS_HEAVY			6
#define TF_CLASS_ENGINEER		9
#define TF_CLASS_MEDIC			5
#define TF_CLASS_SNIPER			2
#define TF_CLASS_SPY			8
#define TF_CLASS_UNKNOWN		0
#define TF_CLASS_UNSET_NEXT     -1

#define TF_TEAM_BLU					3
#define TF_TEAM_RED					2

#define PANEL_CANCEL_ALREADYOPEN    -2
#define PANEL_CANCEL_TIMEOUT        -5

new g_iMenuToClass[9] = { TF_CLASS_SCOUT, TF_CLASS_SOLDIER, TF_CLASS_PYRO, TF_CLASS_DEMOMAN, TF_CLASS_HEAVY, TF_CLASS_ENGINEER, TF_CLASS_MEDIC, TF_CLASS_SNIPER, TF_CLASS_SPY };
new String:g_menuToString[9][10] = { "Scout", "Soldier", "Pyro", "Demoman", "Heavy", "Engineer", "Medic", "Sniper", "Spy" };
new g_iClientNextClass[MAXPLAYERS+1];

public Plugin:myinfo =
{
    name        = "[TF2] Queue Class Change",
    author      = "nosoop",
    description = "Allows a player to queue a class change, mainly for Arena mode.",
    version     = PL_VERSION,
    url         = "https://github.com/nosoop/sm-plugins"
}

public OnPluginStart() {
    CreateConVar("sm_arenaclasschange_version", PL_VERSION, "Prints plugin version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    
    // Overrides +showroundinfo (default bind on F1) for convenience.
    AddCommandListener(Event_ChangeClass, "+showroundinfo");
    AddCommandListener(Event_ChangeClass2, "-showroundinfo");
    
    // TODO Register a console command to open up a custom menu.
    
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public PanelHandler1(Handle:menu, MenuAction:action, client, selection) {
	if (action == MenuAction_Select) {
        // Notify of next class as needed.
        if (g_iMenuToClass[selection-1] != g_iClientNextClass[client]) {
            PrintToChat(client, "*You will respawn as %s", g_menuToString[selection-1]);
            //PrintToChat(client, "#game_respawn_as", "_s", g_menuToString[selection-1]);
            g_iClientNextClass[client] = g_iMenuToClass[selection-1];
		}
	}
}
 
public Action:Event_ChangeClass(client, const String:command[], argc) {
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "Class selection:");
	
	for (new i = 0; i < 9; i++) {
        DrawPanelItem(panel, g_menuToString[i]);
	}

	SendPanelToClient(panel, client, PanelHandler1, 20);
	CloseHandle(panel);
 
	return Plugin_Handled;
}

public Action:Event_ChangeClass2(client, const String:command[], argc) {
    // Do nothing; just prevent reporting -showroundinfo as an unknown command.
	return Plugin_Handled;
}

public OnClientPutInServer(client) {
    g_iClientNextClass[client] = TF_CLASS_UNSET_NEXT;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new iClient = GetClientOfUserId(GetEventInt(event, "userid")),
        iClass = GetEventInt(event, "class");
	
	// Change class if valid class type and we are not currently that class.
	if (g_iClientNextClass[iClient] != TF_CLASS_UNSET_NEXT && iClass != g_iClientNextClass[iClient]) {
        TF2_SetPlayerClass(iClient, TFClassType:g_iClientNextClass[iClient]);
        TF2_RespawnPlayer(iClient);
    }
    
    // Set next class as current class, meaning there's no class to switch to.
    g_iClientNextClass[iClient] = iClass;
}
