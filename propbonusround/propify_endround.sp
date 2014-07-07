/**
 * [TF2] Prop Bonus Round
 * Author(s): nosoop, "Prop Bonus Round" developers
 * File: propify_endround.sp
 * Description: Turns the losing team into random props during bonus round!
 *
 * 2.0.0 - Changed the original "Prop Bonus Round" into "Propify!", separating end-round functionality.
 *         I THINK I'VE GONE MAD JUST MESSING WITH THIS PLUGIN ALONE.  PLEASE SEND HELP
 * 1.0.0 - Forked from https://forums.alliedmods.net/showthread.php?p=1096024
 * Forked version was 1.3 in the original post.  See credits for their work there.  They deserve it!
 *
 * See the commits to https://github.com/nosoop/sm-plugins for improvements and updated notes.
 */

#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <propify>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define PLUGIN_VERSION          "2.1.1"     // Plugin version.  Am I doing semantic versioning right?

                                            // In humiliation...
#define UNPROP_DMG_NEVER        0           // Props are never lost from taking damage.
#define UNPROP_DMG_PLAYER       1           // Props are lost by taking damage from another player.
#define UNPROP_DMG_ANY          2           // Props are lost by taking any damage.

new Handle:Cvar_AdminFlag = INVALID_HANDLE;

// ConVars and junk.  For references, see OnPluginStart().
new Handle:g_hCPluginEnabled = INVALID_HANDLE,      bool:g_bPluginEnabled;      // sm_propbonus_enabled
new Handle:g_hCAdminOnly = INVALID_HANDLE,          bool:g_bAdminOnly;          // sm_propbonus_adminonly
new Handle:g_hCAnnouncePropRound = INVALID_HANDLE,  bool:g_bAnnouncePropRound;  // sm_propbonus_announcement
new Handle:g_hCDmgUnprops = INVALID_HANDLE,         g_iDmgUnprops;              // sm_propbonus_damageunprops
new Handle:g_hCHumiliationRespawn = INVALID_HANDLE, bool:g_bHumiliationRespawn; // sm_propbonus_forcespawn

new bool:g_bIsPlayerGlowing[MAXPLAYERS + 1];
new bool:g_bIsPlayerAdmin[MAXPLAYERS + 1];

// Humiliation mode handling.
new bool:g_bBonusRound, g_iWinningTeam;

new String:g_sCharAdminFlag[32];

public Plugin:myinfo = {
    name = "[TF2] Prop Bonus Round",
    author = "nosoop, Prop Bonus Round developers",
    description = "Turns the losing team into random props during bonus round!",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
}

public OnPluginStart() {
    CheckGame();

    CreateConVar("sm_propbonus_version", PLUGIN_VERSION, "Version of Prop Bonus Round", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    // Create and hook cvars.
    g_hCPluginEnabled = CreateConVar("sm_propbonus_enabled", "1", "Enable / disable prop bonus round plugin.");
    HookConVarChange(g_hCPluginEnabled, Cvars_Changed);
    
    g_hCAdminOnly = CreateConVar("sm_propbonus_adminonly", "0", "Enable props for admins only?");
    HookConVarChange(g_hCAdminOnly, Cvars_Changed);
    
    Cvar_AdminFlag = CreateConVar("sm_propbonus_flag", "b", "Admin flag to use if adminonly is enabled (only one).  Must be a in char format.");
    
    g_hCAnnouncePropRound = CreateConVar("sm_propbonus_announcement", "1", "Whether or not an announcement is made about the prop hunting end-round.");
    HookConVarChange(g_hCAnnouncePropRound, Cvars_Changed);

    g_hCDmgUnprops = CreateConVar("sm_propbonus_damageglow", "0", "Whether or not damage taken by hiding players during the humiliation round are set to glow, revealing them.\n" ...
            "  Value can be one of the following:\n" ...
            "  0 = Damage never makes them glow,\n" ...
            "  1 = Damage from other players makes them glow,\n" ...
            "  2 = Any damage makes them glow.");
    HookConVarChange(g_hCDmgUnprops, Cvars_Changed);

    g_hCHumiliationRespawn = CreateConVar("sm_propbonus_forcespawn", "0", "Whether or not dead players are respawned and turned into a prop.");
    HookConVarChange(g_hCHumiliationRespawn, Cvars_Changed);
        
    // Hook round events to set and unset props.
    HookPropBonusRoundPluginEvents(true);

    AutoExecConfig(true, "plugin.propifyendround");
}

HookPropBonusRoundPluginEvents(bool:bHook) {
    if (bHook) {
        // Hook round events to set and unset props.
        HookEvent("teamplay_round_win", Hook_PostRoundWin);
        
        // Hook player events to unset prop on death and remove prop on player when hit if desired.
        HookEvent("player_hurt", Hook_PostPlayerHurt);
        
        // Hook round start event to unset player glow.
        HookEvent("teamplay_round_start", Hook_PostRoundStart);
    } else {
        // Unhook events.
        UnhookEvent("teamplay_round_win", Hook_PostRoundWin);
        UnhookEvent("player_hurt", Hook_PostPlayerHurt);
        UnhookEvent("teamplay_round_start", Hook_PostRoundStart);
    }
}

public OnClientPostAdminCheck(client) {
    g_bIsPlayerAdmin[client] = IsValidAdmin(client, g_sCharAdminFlag);
}

public OnConfigsExecuted() {
    g_bBonusRound = false;

    g_bPluginEnabled = GetConVarBool(g_hCPluginEnabled);
    GetConVarString(Cvar_AdminFlag, g_sCharAdminFlag, sizeof(g_sCharAdminFlag));

    g_iDmgUnprops = GetConVarInt(g_hCDmgUnprops) != 0;
    g_bAdminOnly = GetConVarInt(g_hCAdminOnly) != 0;
    g_bAnnouncePropRound = GetConVarInt(g_hCAnnouncePropRound) != 0;
    g_bHumiliationRespawn = GetConVarInt(g_hCHumiliationRespawn) != 0;
}

public Hook_PostPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled || !g_bBonusRound || g_iDmgUnprops == UNPROP_DMG_NEVER)
        return;
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    if (g_bIsPlayerGlowing[client]) {
        return;
    }
    
    if (attacker < 1 && g_iDmgUnprops >= UNPROP_DMG_PLAYER) {
        g_bIsPlayerGlowing[client] = true;
    } else if (g_iDmgUnprops >= UNPROP_DMG_ANY) {
        g_bIsPlayerGlowing[client] = true;
    }
    
    if (g_bIsPlayerGlowing[client]) {
        SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1, 1);
        // TODO print hint message about being set to glow
    }
}

public Hook_PostRoundWin(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled)
        return;

    g_bBonusRound = true;
    g_iWinningTeam = GetEventInt(event, "team");
    
    if (!IsEntLimitReached()) {
        if (g_bAnnouncePropRound) {
            PrintToChatAll("\x01\x04-------------------------------------------\x01");
            PrintToChatAll("\x01\x04**Round-End Prop Hunt ACTIVE!**\x01");
            PrintToChatAll("\x01\x04-------------------------------------------\x01");
        }
        
        CreateTimer(0.1, Timer_EquipProps, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Hook_PostRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
    // Set unglow on all players that have glow set by the plugin.
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !g_bIsPlayerGlowing[i]) {
            SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0, 1);
            g_bIsPlayerGlowing[i] = false;
        }
    }
}

public Action:Timer_EquipProps(Handle:timer) {
    for (new x = 1; x <= MaxClients; x++) {
        if(!IsClientInGame(x)) {
            continue;
        }
        
        if(GetClientTeam(x) == g_iWinningTeam) {
            continue;
        }
                
        //If player is already a prop, skip id.
        if(IsClientProp(x)) {
            continue;
        }
        
        //If admin only cvar is enabled and not admin, skip id.
        if (g_bAdminOnly && !g_bIsPlayerAdmin[x]) {
            continue;
        }
        
        if (!IsPlayerAlive(x)) {
            if (g_bHumiliationRespawn) {
                TF2_RespawnPlayer(x);
                PropPlayer(x);
            }
            continue;
        }

        if(IsPlayerAlive(x)) {
            PropPlayer(x);
        }
    }
    return Plugin_Handled;
}

CheckGame() {
    new String:strGame[10];
    GetGameFolderName(strGame, sizeof(strGame));
    
    if(!StrEqual(strGame, "tf")) {
        SetFailState("[propbonusround] Detected game other than [TF2], plugin disabled.");
    }
}

stock bool:IsStringBlank(const String:input[]) {
    new len = strlen(input);
    for (new i=0; i<len; i++) {
        if (!IsCharSpace(input[i])) {
            return false;
        }
    }
    return true;
}

stock bool:IsValidAdmin(client, const String:flags[]) {
    if (!IsClientConnected(client))
        return false;
    
    new ibFlags = ReadFlagString(flags);
    if(!StrEqual(flags, "")) {
        if((GetUserFlagBits(client) & ibFlags) == ibFlags) {
            return true;
        }
    }
    
    return false;
}

stock bool:IsEntLimitReached() {
    new maxents = GetMaxEntities();
    new i, c = 0;
    
    for(i = MaxClients; i <= maxents; i++) {
        if(IsValidEntity(i))
            c++;
    }
    
    if (c >= (maxents-32)) {
        PrintToServer("Warning: Entity limit is nearly reached! Please switch or reload the map!");
        LogError("Entity limit is nearly reached: %d/%d", c, maxents);
        return true;
    } else {
        return false;
    }
}

public Cvars_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
    if(convar == g_hCPluginEnabled) {
        g_bPluginEnabled = StringToInt(newValue) != 0;
        HookPropBonusRoundPluginEvents(g_bPluginEnabled);
        
        if (!g_bPluginEnabled) {
            // Unprop and respawn the player when the plugin is disabled dynamically.
            for (new x = 1; x <= MaxClients; x++) {
                if(IsClientInGame(x) && IsPlayerAlive(x)) {
                    UnpropPlayer(x, true);
                }
            }
        }
    } else if (convar == g_hCDmgUnprops) {
        g_iDmgUnprops = StringToInt(newValue);
        
        if (g_iDmgUnprops == UNPROP_DMG_NEVER) {
            // Set unglow.
            for (new i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i))
                    SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0, 1);
            }
        }
    } else if (convar == g_hCAdminOnly) {
        g_bAdminOnly = StringToInt(newValue) != 0;
    } else if (convar == g_hCAnnouncePropRound) {
        g_bAnnouncePropRound = StringToInt(newValue) != 0;
    } else if (convar == g_hCHumiliationRespawn) {
        g_bHumiliationRespawn = StringToInt(newValue) != 0;
    }
}