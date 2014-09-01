/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Spell Randomizer",
    author = "Author!",
    description = "Description!",
    version = PLUGIN_VERSION,
    url = "localhost"
}

new Handle:g_hCRandomSpells = INVALID_HANDLE,      bool:g_bRandomSpells = true,
    Handle:g_hCSpellTimes = INVALID_HANDLE,        Float:g_fSpellTimes = 2.5,
    Handle:g_hCRareSpellRate = INVALID_HANDLE,     Float:g_fRareSpellRate = 0.05;

public OnPluginStart() {
    g_hCRandomSpells = CreateConVar("sm_spellrand_enabled", "1", "Whether or not random spells are enabled.", FCVAR_PLUGIN|FCVAR_SPONLY, true, 0.0, true, 1.0);
    HookConVarChange(g_hCRandomSpells, OnConVarChanged);
    
    g_hCSpellTimes = CreateConVar("sm_spellrand_rolltime", "2.5", "Amount of time between rolls.", FCVAR_PLUGIN|FCVAR_SPONLY, true, 2.0);
    HookConVarChange(g_hCSpellTimes, OnConVarChanged);
    
    g_hCRareSpellRate = CreateConVar("sm_spellrand_rarerate", "0.05", "Chance that a rare spell is rolled.", FCVAR_PLUGIN|FCVAR_SPONLY, true, 0.0, true, 1.0);
    HookConVarChange(g_hCRareSpellRate, OnConVarChanged);
}

public OnMapStart() {
    CreateTimer(g_fSpellTimes, Timer_RollSpell, _, TIMER_REPEAT);
}

public Action:Timer_RollSpell(Handle:timer, any:data) {
    for (new i = MaxClients; i > 0; --i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
            RollSpell(i, GetRandomFloat() < g_fRareSpellRate);
        }
    }
    
    return Plugin_Handled;
}


RollSpell(client, bool:bRare) {
    if (!g_bRandomSpells) {
        return;
    }
    new spellbook = CreateEntityByName("tf_spell_pickup");
    
    decl iSpellbook;
    if ( (iSpellbook = FindSpellbook(client)) != -1 ) {
        if (GetEntProp(iSpellbook, Prop_Send, "m_iSpellCharges") == 0) {
            decl Float:pos[3], Float:vel[3];
            GetClientEyePosition(client, pos);
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
            
            SetEntProp(spellbook, Prop_Data, "m_nTier", bRare);
            DispatchKeyValue(spellbook, "OnPlayerTouch", "!self,Kill,,0,-1");	// Remove this spell pickup.
            
            TeleportEntity(spellbook, pos, NULL_VECTOR, vel);
            DispatchSpawn(spellbook);
        }
    }
}

public OnConVarChanged(Handle:hConVar, const String:sOldValue[], const String:sNewValue[]) {
    if (hConVar == g_hCRandomSpells) {
        g_bRandomSpells = StringToInt(sNewValue) > 0;
    } else if (hConVar == g_hCSpellTimes) {
        g_fSpellTimes = StringToFloat(sNewValue);
    } else if (hConVar == g_hCRareSpellRate) {
        g_fRareSpellRate = StringToFloat(sNewValue);
    }
}

// Stock taken from FlaminSarge's Spellbook Commands
// https://forums.alliedmods.net/showthread.php?p=2056211
stock FindSpellbook(client)	{
    new i = -1;
    while ((i = FindEntityByClassname(i, "tf_weapon_spellbook")) != -1) {
        if (IsValidEntity(i) && GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(i, Prop_Send, "m_bDisguiseWeapon")) {
            return i;
        }
    }
    return -1;
}