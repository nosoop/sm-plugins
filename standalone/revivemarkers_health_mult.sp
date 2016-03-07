/**
 * Revive Markers utility helper to change the health required to revive players.
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdkhooks>

#include <ReviveMarkers>
#pragma newdecls required

#define PLUGIN_VERSION "0.0.1"
public Plugin myinfo = {
    name = "[TF2] Revive Markers: Scale Revive Health",
    author = "nosoop",
    description = "Scales the health required to revive players.",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?t=280022"
}

ConVar g_ConVarReviveMarkerHealthScalar;
bool g_bReviveMarkersAvailable;

public void OnAllPluginsLoaded() {
	g_bReviveMarkersAvailable = LibraryExists("revivemarkers");
}
 
public void OnLibraryRemoved(const char[] name) {
	if (StrEqual(name, "revivemarkers")) {
		g_bReviveMarkersAvailable = false;
	}
}
 
public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "revivemarkers")) {
		g_bReviveMarkersAvailable = true;
	}
}

public void OnPluginStart() {
	g_ConVarReviveMarkerHealthScalar = CreateConVar("sm_revivemarker_health_scale", "1.0",
			"Scales the amount of health required to revive a player.", _, true, 0.0);
}

/**
 * Called before a Marker is spawned.  Properties are available for modification.
 * ... except for m_iMaxHealth, apparently.
 */
public Action OnReviveMarkerSpawn(int client, int marker) {
	if (g_bReviveMarkersAvailable) {
		// It's still uninitialized at SpawnPost, so I decided on hooking the first ThinkPost.
		SDKHook(marker, SDKHook_ThinkPost, OnReviveMarkerThinkPost);
	}
	return Plugin_Continue;
}

public void OnReviveMarkerThinkPost(int marker) {
	int iMaxHealth = GetEntProp(marker, Prop_Data, "m_iMaxHealth");
		
	float flScaleValue = g_ConVarReviveMarkerHealthScalar.FloatValue;
	
	SetEntProp(marker, Prop_Send, "m_iMaxHealth", RoundFloat(iMaxHealth * flScaleValue));
	
	SDKUnhook(marker, SDKHook_ThinkPost, OnReviveMarkerThinkPost);
}