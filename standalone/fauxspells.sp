/**
 * Sourcemod Plugin Template
 */

// This plugin is intended for use with Halloween enabled.
// The following Stripper:Source filter will enable the Spellbook UI to work properly.
// http://pikatf2.serverpit.com/tf/configfiles/strippersource/_global_filters.cfg

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items_giveweapon>
#include <morecolors>

#define PLUGIN_VERSION          "1.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Free Magazines",
    author = "nosoop",
    description = "Plugin to handle Halloween spells because Valve won't!",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

new g_rgiClientNotified[MAXPLAYERS+1];

public OnPluginStart() {
    CreateConVar("tf_spellbookcmds_version", PLUGIN_VERSION, "[TF2] Faux Spells version", FCVAR_NOTIFY|FCVAR_PLUGIN);
    LoadTranslations("common.phrases");
    
    RegAdminCmd("sm_spawnspellbook", Command_CreateSpell, ADMFLAG_GENERIC, "Spawns a spellbook.");
    
    // Custom spellbooks, one for most classes, another for Engineer / Spy (since slot 4 is their PDA).
    // TODO Avoid conflicts with existing items another way?
    if (!TF2Items_CheckWeapon(9550)) {
        TF2Items_CreateWeapon(9550, "tf_weapon_spellbook", 1070, 4, 1, 1);
    }
    if (!TF2Items_CheckWeapon(9551)) {
        TF2Items_CreateWeapon(9551, "tf_weapon_spellbook", 1070, 5, 1, 1);
    }
    
    HookEvent("post_inventory_application", Hook_PostPlayerInventoryUpdate);
}

public Hook_PostPlayerInventoryUpdate(Handle:event, const String:name[], bool:dontBroadcast) {
    // If not Halloween, then spellbooks are assumed to be disabled.
    if (!TF2_IsHolidayActive(TFHoliday_HalloweenOrFullMoon)) {
        return;
    }

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    FindSpellbook(client);
}

public Action:Command_CreateSpell(client, args) {
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_forcespell_create <rare 0|1>");
        return Plugin_Handled;
    }
    
    new bool:tier;
    if (args < 2) {
        new String:argbuf[10];
        GetCmdArg(1, argbuf, sizeof(argbuf));
        tier = StringToInt(argbuf) == 1;
    }
    
    new spellbook = CreateEntityByName("tf_spell_pickup");
    
    decl Float:pos[3];
    
    if (SetTeleportEndPoint(client, pos)) {
        SetEntProp(spellbook, Prop_Data, "m_nTier", tier);
        DispatchKeyValue(spellbook, "OnPlayerTouch", "!self,Kill,,0,-1");	// Remove this spell pickup.
        
        TeleportEntity(spellbook, pos, NULL_VECTOR, NULL_VECTOR);
        DispatchSpawn(spellbook);
    }

    return Plugin_Handled;
}

stock FindSpellbook(client, bool:createIfNonexistent = true) {  //GetPlayerWeaponSlot was giving me some issues
    new i = -1;
    while ((i = FindEntityByClassname(i, "tf_weapon_spellbook")) != -1) {
        if (IsValidEntity(i) && GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(i, Prop_Send, "m_bDisguiseWeapon")) {
            return i;
        }
    }
    
    while ((i = FindEntityByClassname(i, "tf_powerup_bottle")) != -1) {
        if (IsValidEntity(i) && GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == client) {
            AcceptEntityInput(i, "Kill");
        }
    }
    
    // Create a custom spellbook.  (If Spy, Engineer use the 5-slot version)
    // TODO Figure out cosmetics bug?
    if (createIfNonexistent) {
        return GrantSpellbook(client);
    } else {
        return -1;
    }
}

GrantSpellbook(client) {
    new activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    new TFClassType:playerClass = TF2_GetPlayerClass(client);
    new spellbook = TF2Items_GiveWeapon(client, 9550 + _:(playerClass == TFClass_Spy || playerClass == TFClass_Engineer));
    SetEntProp(spellbook, Prop_Send, "m_bFiredAttack", false);
    
    // Notify client once.
    new clientAccountId = GetSteamAccountID(client);
    if (g_rgiClientNotified[client] != clientAccountId) {
        CPrintToChat(client, "It's dangerous out there.  You've been given a {UNIQUE}Spellbook Magazine{DEFAULT}.");
        CPrintToChat(client, "Pick up a {LIGHTGREEN}spell{DEFAULT} and use your action slot key to cast spells.");
        g_rgiClientNotified[client] = clientAccountId;
    }
    
    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", activeWeapon);
    
    return spellbook;
}

SetTeleportEndPoint(client, Float:vector[3]) {
	new Float:vAngles[3];
	new Float:vOrigin[3];
	decl Float:vBuffer[3];
	decl Float:vStart[3];
	decl Float:Distance;
	
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
    // Get point to spawn taken from pheadxdll's Pumpkins plugin.
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit(trace)) {   	 
   	 	TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		Distance = -35.0;
   	 	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		vector[0] = vStart[0] + (vBuffer[0]*Distance);
		vector[1] = vStart[1] + (vBuffer[1]*Distance);
		vector[2] = vStart[2] + (vBuffer[2]*Distance);
	} else {
		CloseHandle(trace);
		return false;
	}
	
	CloseHandle(trace);
	return true;
}

public bool:TraceEntityFilterPlayer(entity, contentsMask) {
	return entity > GetMaxClients() || !entity;
}
