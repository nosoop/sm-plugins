/**
 * Disables the spray command.
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools_hooks>

#pragma newdecls required

#define PLUGIN_VERSION "0.0.0"
public Plugin myinfo = {
	name = "Spray Disabler",
	author = "nosoop",
	description = "Prevents usage of the spray command.",
	version = PLUGIN_VERSION,
	url = "https://redd.it/5embg0"
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse) {
	if (impulse == 201) {
		impulse = 0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}