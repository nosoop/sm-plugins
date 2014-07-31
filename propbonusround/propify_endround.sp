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

#define PLUGIN_VERSION          "2.3.6"     // Plugin version.  Am I doing semantic versioning right?

                                            // In humiliation...
#define UNPROP_DMG_NEVER        0           // Props are never lost from taking damage.
#define UNPROP_DMG_PLAYER       1           // Props are lost by taking damage from another player.
#define UNPROP_DMG_ANY          2           // Props are lost by taking any damage.

public Plugin:myinfo = {
    name = "[TF2] Prop Bonus Round",
    author = "nosoop, Prop Bonus Round developers",
    description = "Turns the losing team into random props during bonus round!",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
}

new bool:g_bIsPropifyLoaded;                // Checks whether Propify! is loaded or not.

new Handle:Cvar_AdminFlag = INVALID_HANDLE;

// ConVars and junk.  For references, see OnPluginStart().
new Handle:g_hCPluginEnabled = INVALID_HANDLE,      bool:g_bPluginEnabled,      // sm_propbonus_enabled
    Handle:g_hCAdminOnly = INVALID_HANDLE,          bool:g_bAdminOnly,          // sm_propbonus_adminonly
    Handle:g_hCAnnouncePropRound = INVALID_HANDLE,  bool:g_bAnnouncePropRound,  // sm_propbonus_announcement
    Handle:g_hCDmgUnprops = INVALID_HANDLE,         g_iDmgUnprops,              // sm_propbonus_damageunprops
    Handle:g_hCHumiliationRespawn = INVALID_HANDLE, bool:g_bHumiliationRespawn, // sm_propbonus_forcespawn
    Handle:g_hCTargetRound = INVALID_HANDLE,        Float:g_fTargetRound;       // sm_propbonus_targetroundchance    

// Check plugin-controlled glow state.
new bool:g_bIsPlayerGlowing[MAXPLAYERS + 1];

// Check if a player is part of the admin group to be propped.
new bool:g_bIsPlayerAdmin[MAXPLAYERS + 1];

// Humiliation mode handling.
new bool:g_bBonusRound, TFTeam:g_iWinningTeam;

new String:g_sCharAdminFlag[32];

// Special target practice round -- all players are turned into the training targets of their respective class.
new bool:g_bTargetPracticeAvailable;        // If the special mode is available.  Requires all the prop models to be loaded.
new rg_iClassModels[9];                     // The indices of the class models in the prop list.
new String:rg_sClassModelPaths[][] = {      // Paths of models to check for, in class ordinal order so we can just pass the player's current class int value imto the array.
    "models/props_training/target_scout.mdl",
    "models/props_training/target_sniper.mdl",
    "models/props_training/target_soldier.mdl",
    "models/props_training/target_demoman.mdl",
    "models/props_training/target_medic.mdl",
    "models/props_training/target_heavy.mdl",
    "models/props_training/target_pyro.mdl",    
    "models/props_training/target_spy.mdl",
    "models/props_training/target_engineer.mdl"
};

enum BonusRoundMode {
    BonusRoundMode_Normal = 0,
    BonusRoundMode_TargetPractice = 1
};

new Handle:rg_SpawnPositions;

public OnPluginStart() {
    CheckGame();

    CreateConVar("sm_propbonus_version", PLUGIN_VERSION, "Version of Prop Bonus Round", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    // Create and hook cvars.
    g_hCPluginEnabled = CreateConVar("sm_propbonus_enabled", "1", "Enable / disable prop bonus round plugin.", _, true, 0.0, true, 1.0);
    HookConVarChange(g_hCPluginEnabled, Cvars_Changed);
    
    g_hCAdminOnly = CreateConVar("sm_propbonus_adminonly", "0", "Enable props for admins only?", _, true, 0.0, true, 1.0);
    HookConVarChange(g_hCAdminOnly, Cvars_Changed);
    
    Cvar_AdminFlag = CreateConVar("sm_propbonus_flag", "b", "Admin flag to use if adminonly is enabled (only one).  Must be a in char format.");
    
    g_hCAnnouncePropRound = CreateConVar("sm_propbonus_announcement", "1", "Whether or not an announcement is made about the prop hunting end-round.", _, true, 0.0, true, 1.0);
    HookConVarChange(g_hCAnnouncePropRound, Cvars_Changed);

    g_hCDmgUnprops = CreateConVar("sm_propbonus_damageglow", "0", "Whether or not damage taken by hiding players during the humiliation round are set to glow, revealing them.\n" ...
            "  Value can be one of the following:\n" ...
            "  0 = Never,\n" ...
            "  1 = From other players,\n" ...
            "  2 = Any source.", _, true, 0.0, true, 2.0);
    HookConVarChange(g_hCDmgUnprops, Cvars_Changed);

    g_hCHumiliationRespawn = CreateConVar("sm_propbonus_forcespawn", "0", "Whether or not dead players are respawned and turned into a prop.", _, true, 0.0, true, 1.0);
    HookConVarChange(g_hCHumiliationRespawn, Cvars_Changed);
    
    g_hCTargetRound = CreateConVar("sm_propbonus_targetroundchance", "0.0", "Chance that the bonus round will make all losing players wooden targets.", _, true, 0.0, true, 1.0);
    HookConVarChange(g_hCTargetRound, Cvars_Changed);
        
    // Hook round events to set and unset props.
    HookPropBonusRoundPluginEvents(true);

    AutoExecConfig(true, "plugin.propifyendround");
    
    rg_SpawnPositions = CreateArray(5);
}

public OnPluginEnd() {
    Propify_UnregisterConfigHandlers();
}

public OnAllPluginsLoaded() {
    g_bIsPropifyLoaded = LibraryExists("nosoop-propify");
    
    if (g_bIsPropifyLoaded) {
        Propify_RegisterConfigHandler("spawnpos", ConfigHandler_SpawnPositions);
        Propify_OnPropListLoaded();
    }
}

public Propify_OnPropListCleared() {
    ClearArray(rg_SpawnPositions);
}

public Propify_OnPropListLoaded() {
    g_bTargetPracticeAvailable = false;
    
    new Handle:hModelPaths = Propify_GetModelPathsArray();
    if (hModelPaths != INVALID_HANDLE) {
        g_bTargetPracticeAvailable = true;
        for (new i = 0; i < sizeof(rg_sClassModelPaths); i++) {
            rg_iClassModels[i] = FindStringInArray(hModelPaths, rg_sClassModelPaths[i]);
            
            // We keep the mode enabled if we find the model to use.
            g_bTargetPracticeAvailable &= (rg_iClassModels[i] > -1);
        }
    }
}

// ConfigHandler -- reads key "x y z" and angle "yaw" to spawn in
public ConfigHandler_SpawnPositions(const String:key[], const String:value[]) {
    new String:sSpawnCoords[3][12];
    ExplodeString(key, " ", sSpawnCoords, sizeof(sSpawnCoords), sizeof(sSpawnCoords[]));
    
    new String:sSpawnAngs[2][12];
    ExplodeString(value, " ", sSpawnAngs, sizeof(sSpawnAngs), sizeof(sSpawnAngs[]));
    
    new Float:iSpawnCoords[5];  // x y z pitch yaw
    iSpawnCoords[0] = StringToFloat(sSpawnCoords[0]);
    iSpawnCoords[1] = StringToFloat(sSpawnCoords[1]);
    iSpawnCoords[2] = StringToFloat(sSpawnCoords[2]);
    
    iSpawnCoords[3] = StringToFloat(sSpawnAngs[0]);
    iSpawnCoords[4] = StringToFloat(sSpawnAngs[1]);
    
    PushArrayArray(rg_SpawnPositions, iSpawnCoords);
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
    if(!IsPluginUsable() || !g_bBonusRound || g_iDmgUnprops == UNPROP_DMG_NEVER)
        return;
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    if (g_bIsPlayerGlowing[client]) {
        return;
    }
    
    if (attacker > 0 && attacker == client && g_iDmgUnprops >= UNPROP_DMG_PLAYER) {
        SetPlayerGlow(client, true);
        PrintToChat(client, "Another player attacked you and made you visible; run!");
    } else if (g_iDmgUnprops >= UNPROP_DMG_ANY) {
        SetPlayerGlow(client, true);
        PrintToChat(client, "You've taken damage and now the enemy team can see you!");
    }
}

public Hook_PostRoundWin(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!IsPluginUsable())
        return;

    g_bBonusRound = true;
    g_iWinningTeam = TFTeam:GetEventInt(event, "team");
    
    if (g_bAnnouncePropRound) {
        PrintToChatAll("\x01* Round-End Prop Hunt is \x04active\x01!");
    }
    CreateTimer(0.1, Timer_EquipProps, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_EquipProps(Handle:timer) {
    // Roll for any special modes.
    new BonusRoundMode:iMode = (GetRandomFloat() < g_fTargetRound * _:g_bTargetPracticeAvailable) ?
            BonusRoundMode_TargetPractice : BonusRoundMode_Normal;

    for (new x = 1; x <= MaxClients; x++) {
        new bool:bClientJustRespawned;
        
        if(!IsClientInGame(x) || IsFakeClient(x)) {
            continue;
        }
        
        // Prevent turning ghosts or soon-to-be ghosts into props.
        if (TF2_IsPlayerInCondition(x, TFCond_HalloweenInHell) ||
                TF2_IsPlayerInCondition(x, TFCond_HalloweenGhostMode)) {
            continue;
        }
        
        if (TFTeam:GetClientTeam(x) == g_iWinningTeam) {
            continue;
        }
                
        //If player is already a prop, skip id.
        if (Propify_IsClientProp(x)) {
            continue;
        }
        
        //If admin only cvar is enabled and not admin, skip id.
        if (g_bAdminOnly && !g_bIsPlayerAdmin[x]) {
            continue;
        }
        
        if (!IsPlayerAlive(x)) {
            if (g_bHumiliationRespawn) {
                TF2_RespawnPlayer(x);
                TeleportToRandomSpawnLocation(x);
                bClientJustRespawned = true;
                // Player will not be in third-person by default.
            }
        }

        if (IsPlayerAlive(x)) {
            // Kill off any existing ragdoll entities to prevent the camera from focusing on it.
            new hRagdoll = GetEntPropEnt(x, Prop_Send, "m_hRagdoll");
            if (IsValidEntity(hRagdoll)) {
                AcceptEntityInput(hRagdoll, "kill");
            }
            
            EndRoundPropPlayer(x, bClientJustRespawned, iMode);
            
            if (g_iWinningTeam != TFTeam_Unassigned) {
                PrintCenterText(x, "You've been turned into a prop!  Blend in!");
            } else {
                PrintCenterText(x, "Everyone's been turned into a prop!");
            }
        }
    }
    return Plugin_Handled;
}

TeleportToRandomSpawnLocation(client) {
    new spawnLocationCount = GetArraySize(rg_SpawnPositions);
    if (GetArraySize(rg_SpawnPositions) == 0) {
        return;
    }
    
    new Float:selectedSpawn[5];
    GetArrayArray(rg_SpawnPositions, GetRandomInt(0, spawnLocationCount - 1), selectedSpawn);
    
    new Float:pos[3], Float:ang[3];
    pos[0] = selectedSpawn[0]; pos[1] = selectedSpawn[1]; pos[2] = selectedSpawn[2];
    ang[0] = selectedSpawn[3]; ang[1] = selectedSpawn[4];
    
    TeleportEntity(client, pos, ang, NULL_VECTOR);
}

EndRoundPropPlayer(client, bool:bClientJustRespawned, BonusRoundMode:iMode) {
    // Prop the player based on the mode.
    switch (iMode) {
        case BonusRoundMode_Normal: {
            Propify_PropPlayer(client, _, bClientJustRespawned);
        }
        case BonusRoundMode_TargetPractice: {
            new iClassPropIndex = rg_iClassModels[_:TF2_GetPlayerClass(client) - 1];
            Propify_PropPlayer(client, iClassPropIndex, bClientJustRespawned);
        }
    }
}

public Hook_PostRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
    // Not humiliation anymore.
    g_bBonusRound = false;

    // Set unglow on all players that have glow set by the plugin.
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && g_bIsPlayerGlowing[i]) {
            SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0, 1);
            g_bIsPlayerGlowing[i] = false;
        }
    }
}

SetPlayerGlow(client, bool:bGlowEnabled) {
    SetEntProp(client, Prop_Send, "m_bGlowEnabled", _:bGlowEnabled, 1);
    g_bIsPlayerGlowing[client] = true;
}

IsPluginUsable() {
    return g_bPluginEnabled && g_bIsPropifyLoaded;
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

public OnLibraryRemoved(const String:name[]) {
    g_bIsPropifyLoaded &= !StrEqual(name, "nosoop-propify");
}

public OnLibraryAdded(const String:name[]) {
    g_bIsPropifyLoaded |= StrEqual(name, "nosoop-propify");
    
    if (g_bIsPropifyLoaded) {
        Propify_RegisterConfigHandler("spawnpos", ConfigHandler_SpawnPositions);
    }
}

public Cvars_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
    if(convar == g_hCPluginEnabled) {
        g_bPluginEnabled = StringToInt(newValue) != 0;
        HookPropBonusRoundPluginEvents(g_bPluginEnabled);
        
        if (!g_bPluginEnabled && g_bIsPropifyLoaded) {
            // Unprop and respawn the player when the plugin is disabled dynamically.
            for (new x = 1; x <= MaxClients; x++) {
                if(IsClientInGame(x) && IsPlayerAlive(x)) {
                    Propify_UnpropPlayer(x, true);
                }
            }
        }
    } else if (convar == g_hCDmgUnprops) {
        g_iDmgUnprops = StringToInt(newValue);
        
        if (g_iDmgUnprops == UNPROP_DMG_NEVER) {
            // Set unglow.
            for (new i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i))
                    SetPlayerGlow(i, false);
            }
        }
    } else if (convar == g_hCAdminOnly) {
        g_bAdminOnly = StringToInt(newValue) != 0;
    } else if (convar == g_hCAnnouncePropRound) {
        g_bAnnouncePropRound = StringToInt(newValue) != 0;
    } else if (convar == g_hCHumiliationRespawn) {
        g_bHumiliationRespawn = StringToInt(newValue) != 0;
    } else if (convar == g_hCTargetRound) {
        g_fTargetRound = StringToFloat(newValue);
    }
}
