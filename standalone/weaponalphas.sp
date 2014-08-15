/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[ANY?] Viewmodel Transparency",
    author = "nosoop",
    description = "Allows a client to set the transparency of their own viewmodel.",
    version = PLUGIN_VERSION,
    url = "localhost"
}

public OnPluginStart() {
    HookEvent("post_inventory_application", Event_PostInventoryApplication);
}

public Event_PostInventoryApplication(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (IsValidClient(client)) {
        // TODO Add client preferences, send default alpha values to other clients
        SetWeaponInvis(client, 128);
    }
}

stock IsValidClient(client) {
    return client > 0 && client < MaxClients && IsClientInGame(client);
}

// Stock copied from ddhoward's Friendly Mode plugin, which was apparently from FlamingSarge.
stock SetWeaponInvis(client, alpha) {
	for (new i = 0; i < 5; i++) {
		new entity = GetPlayerWeaponSlot(client, i);
		if (entity != -1) {
			SetEntityRenderMode(entity, alpha == 255 ? RENDER_NORMAL : RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, _, _, _, alpha);
		}
	}
}