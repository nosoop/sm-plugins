/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items_giveweapon>
#include <morecolors>

#define PLUGIN_VERSION          "0.2.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Unofficial Spell Handler",
    author = "nosoop",
    description = "Plugin to handle Halloween spells because Valve won't!",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

public String:spellnames[12][32] = {
    "Fireball",
    "Swarm of Bats",
    "Overheal",
    "Pumpkin MIRV",
    "Blast Jump",
    "Stealth",
    "Shadow Leap (Instantarium)",
    "Ball o' Lightning",
    "Tiny and Athletic",
    "MONOCULUS!",
    "Meteor Shower",
    "Skeleton Horde"
};

public String:sSpellColor[][] = {
    "{LIGHTGREEN}", "{UNUSUAL}"
};

public String:tickSound[][] = {
    "misc/halloween/spelltick_02.wav",
    "misc/halloween/spelltick_01.wav",
    "misc/halloween/spelltick_set.wav"
};

new Float:rg_fLastSpellPickup[MAXPLAYERS+1], rg_nSpellTick[MAXPLAYERS+1];

public OnPluginStart() {
    CreateConVar("tf_spellbookcmds_version", PLUGIN_VERSION, "[TF2] Faux Spells version", FCVAR_NOTIFY|FCVAR_PLUGIN);
    LoadTranslations("common.phrases");
    
    RegAdminCmd("sm_spawnspellbook", Command_CreateSpell, ADMFLAG_GENERIC, "Spawns a spellbook.");
    
    // Custom spellbooks, one for most classes, another for Engineer / Spy.
    if (!TF2Items_CheckWeapon(9550)) {
        TF2Items_CreateWeapon(9550, "tf_weapon_spellbook", 1070, 4, 1, 1);
    }
    if (!TF2Items_CheckWeapon(9551)) {
        TF2Items_CreateWeapon(9551, "tf_weapon_spellbook", 1070, 5, 1, 1);
    }
    
    // TODO Add cvar to control fake ticking (to disable on Helltower)
    // TODO Add cvar to control automatic spellbook granting
    // TODO Remove spell commands
    // TODO Add custom spell support!  (Extended override handling on spellbooks)
    
    HookEvent("post_inventory_application", Hook_PostPlayerInventoryUpdate);
}

public OnMapStart() {
    CacheTickSounds();
    
    // Find existing spell pickups and hook them.
    new i = -1;
    while ((i = FindEntityByClassname(i, "tf_spell_pickup")) != -1) {
        SDKHook(i, SDKHook_Touch, SDKHook_OnTouch);
    }
    
    new gameRules = FindEntityByClassname(-1, "tf_gamerules");
    
    if (IsValidEntity(gameRules)) {
        SetEntProp(gameRules, Prop_Send, "m_bIsUsingSpells", 1);
        SetEntProp(gameRules, Prop_Send, "m_nMapHolidayType", 2);
    }
    
    new entHoliday = -1;
    while ( (entHoliday = FindEntityByClassname(entHoliday, "tf_logic_holiday")) != -1) {
        OnEntityCreated(entHoliday, "tf_logic_holiday");
    }
}

public OnEntityCreated(entity, const String:classname[]) {
    if (StrEqual(classname, "tf_logic_holiday")) {
        SetVariantBool(true);
        AcceptEntityInput(entity, "HalloweenSetUsingSpells");
    } else if (StrEqual(classname, "tf_spell_pickup")) {
        SDKHook(entity, SDKHook_Touch, SDKHook_OnTouch);
    }
}

CacheTickSounds() {
    decl String:soundPath[96];
    for (new i = 0; i < sizeof(tickSound); i++) {
        Format(soundPath, sizeof(soundPath), "sound/%s", tickSound[i]);
        PrecacheSound(soundPath, true);
    }
}

public Hook_PostPlayerInventoryUpdate(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    FindSpellbook(client);
}

public SDKHook_OnTouch(pickup, client) {
    // TODO Store spellbook entity index.
    // TODO Fix bug that if the entity is invisible but being touched, the timers will still run.
    new bool:isValidClient = client > 0 && client < MAXPLAYERS+1 && IsPlayerAlive(client);
    if ( isValidClient && GetTickedTime() - rg_fLastSpellPickup[client] > 2.0
            && GetEntProp(FindSpellbook(client, false), Prop_Send, "m_iSpellCharges") < 1 ) {
        rg_fLastSpellPickup[client] = GetTickedTime();
        CreateTimer(0.075, Timer_Spellbook, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(2.1, Timer_GetSpell, client, TIMER_FLAG_NO_MAPCHANGE);
    }
}

// Fake the spellbook ticking.
public Action:Timer_Spellbook(Handle:timer, any:client) {
    EmitSoundToClient(client, tickSound[rg_nSpellTick[client]++ % 2]);
    
    new Float:tickedDuration = GetTickedTime() - rg_fLastSpellPickup[client];
    if (tickedDuration > 2.0 ) {
        rg_nSpellTick[client] = 0;
        KillTimer(timer);
    } else if (rg_nSpellTick[client] > 12) {
        KillTimer(timer);
        CreateTimer(0.225, Timer_Spellbook, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    } else if (rg_nSpellTick[client] > 10) {
        KillTimer(timer);
        CreateTimer(0.151, Timer_Spellbook, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action:Timer_GetSpell(Handle:timer, any:client) {
    new spellbook = FindSpellbook(client, false);
    new charges = GetEntProp(spellbook, Prop_Send, "m_iSpellCharges");
    if (charges > 0) {
        new spell = GetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex");
        
        EmitSoundToClient(client, tickSound[2], _, _, _, _, 0.5);
        
        CPrintToChat(client, "You got %d uses of the spell %s%s{DEFAULT}!", charges, sSpellColor[spell > 6], spellnames[spell]);
    }
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
    // TODO Figure out cosmetics bug.
    if (createIfNonexistent) {
        new TFClassType:playerClass = TF2_GetPlayerClass(client);
        new spellbook = TF2Items_GiveWeapon(client, 9550 + _:(playerClass == TFClass_Spy || playerClass == TFClass_Engineer));
        SetEntProp(spellbook, Prop_Send, "m_bFiredAttack", false);
        CPrintToChat(client, "It's dangerous out there.  You've been given a {UNIQUE}Spellbook Magazine{DEFAULT}.");
        return spellbook;
    } else {
        return -1;
    }
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

/**
 * Client demos run at 66.6 ticks per second.  According to a test demo on Helltower...
 * 833 + 3 pick up spell, no sound, then the next ones tick at...
 * 836 + 5, 841 + 5, 846 + 5, 851 + 5, 856 + 6, 862 + 5, 867 + 6, 873 + 5, 878 + 6, 884 + 5,
 * 889 + 9, 898 + 11
 * 909 + 15, 924 + 15, 939 + 14, 953 + 16, 969 is spoop as we find out which spell we get (133 ticks = 2 seconds.
 * So we create a timer for 0.75 sec, play first 10, skip every other for next 2, skip two for next 4
*/