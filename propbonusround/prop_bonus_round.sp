/**
 * Prop Bonus Round (TF2) 
 * Author(s): retsam, cleaned up by nosoop
 * File: prop_bonus_round.sp
 * Description: Turns the losing team into random props during bonus round!
 *
 * Credits to: strontiumdog for the idea based off his DODS version.
 * Credits to: Antithasys for SMC Parser/SM auto-cmds code and much help!
 *
 * 1.0.0 - Forked from https://forums.alliedmods.net/showthread.php?p=1096024
 * Forked version was 1.3 in the original post.
 *
 * See the commits to https://github.com/nosoop/sm-plugins for updated notes.
 */

#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <adminmenu>

// Plugin version.
#define PLUGIN_VERSION          "1.10.0"

// Default prop command name.
#define PROP_COMMAND            "sm_prop"

// Special value of sm_propbonus_forcespeed that disables the speed override.
// Do not change, as it so happens that a speed of 0 does not work anywhere else.
#define PROP_NO_CUSTOM_SPEED    0

// Base configuration file.
#define PROPCONFIG_BASE         "base"

// Constants for sections of the configuration.
#define PROPCONFIG_ROOT         0
#define PROPCONFIG_PROPLIST     1
#define PROPCONFIG_INCLUDELIST  2
#define PROPCONFIG_SPAWNPOS     3

// The maximum length of a prop name.  32 characters should be enough for all cases.
#define PROPNAME_LENGTH         32

new Handle:hAdminMenu = INVALID_HANDLE;
new Handle:Cvar_AdminFlag = INVALID_HANDLE;

// Arrays for prop models, names, and an list of additional files to load.
new g_iPropListSection = PROPCONFIG_ROOT;
new Handle:g_hModelNames = INVALID_HANDLE;
new Handle:g_hModelPaths = INVALID_HANDLE;
new Handle:g_hIncludePropLists = INVALID_HANDLE;

// ConVars and junk.  For references, see OnPluginStart().
new Handle:g_hCPluginEnabled = INVALID_HANDLE,      bool:g_bPluginEnabled;      // sm_propbonus_enabled
new Handle:g_hCAdminOnly = INVALID_HANDLE,          bool:g_bAdminOnly;          // sm_propbonus_adminonly
new Handle:g_hCHumiliationRespawn = INVALID_HANDLE, bool:g_bHumiliationRespawn; // sm_propbonus_forcespawn
new Handle:g_hCDmgUnprops = INVALID_HANDLE,         bool:g_bDmgUnprops;         // sm_propbonus_damageunprops
new Handle:g_hCAnnouncePropRound = INVALID_HANDLE,  bool:g_bAnnouncePropRound;  // sm_propbonus_announcement
new Handle:g_hCPropSpeed = INVALID_HANDLE,          g_iPropSpeed;               // sm_propbonus_forcespeed

// Boolean flags for prop functions.
new bool:g_bIsProp[MAXPLAYERS+1] = { false, ... };
new bool:g_bIsInThirdperson[MAXPLAYERS+1] = { false, ... };
new bool:g_bIsPropLocked[MAXPLAYERS+1] = { false, ... };
new bool:g_bRecentlySetPropLock[MAXPLAYERS+1] = { false, ... };
new bool:g_bRecentlySetThirdPerson[MAXPLAYERS+1] = { false, ... };

new bool:g_bIsPlayerAdmin[MAXPLAYERS + 1] = { false, ... };

// Humiliation mode handling.
new bool:g_bBonusRound = false;
new g_iWinningTeam;

new String:g_sCharAdminFlag[32];

public Plugin:myinfo = {
    name = "Prop Bonus Round",
    author = "retsam (www.multiclangaming.net), nosoop",
    description = "Turns the losing team into random props during bonus round!",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
}

public OnPluginStart() {
    CheckGame();

    CreateConVar("sm_propbonus_version", PLUGIN_VERSION, "Version of Prop Bonus Round", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    // Create and hook cvars.
    g_hCPluginEnabled = CreateConVar("sm_propbonus_enabled", "1", "Enable/Disable prop bonus round plugin.");
    HookConVarChange(g_hCPluginEnabled, Cvars_Changed);
    
    g_hCAdminOnly = CreateConVar("sm_propbonus_adminonly", "0", "Enable plugin for admins only?");
    HookConVarChange(g_hCAdminOnly, Cvars_Changed);
    
    Cvar_AdminFlag = CreateConVar("sm_propbonus_flag", "b", "Admin flag to use if adminonly is enabled (only one).  Must be a in char format.");
    
    g_hCAnnouncePropRound = CreateConVar("sm_propbonus_announcement", "1", "Public announcement msg at start of bonus round?");
    HookConVarChange(g_hCAnnouncePropRound, Cvars_Changed);

    g_hCDmgUnprops = CreateConVar("sm_propbonus_damageunprops", "0", "Remove player prop once they take damage?");
    HookConVarChange(g_hCDmgUnprops, Cvars_Changed);

    g_hCHumiliationRespawn = CreateConVar("sm_propbonus_forcespawn", "0", "Respawn dead players at start of bonusround?");
    HookConVarChange(g_hCHumiliationRespawn, Cvars_Changed);
    
    g_hCPropSpeed = CreateConVar("sm_propbonus_forcespeed", "0", "Force all props to a specific speed, in an integer representing HU/s.  Setting this to 0 allows props to move at default speed.");
    HookConVarChange(g_hCPropSpeed, Cvars_Changed);

    // Command to prop a player.
    RegAdminCmd(PROP_COMMAND, Command_Propplayer, ADMFLAG_BAN, "sm_prop <#userid|name> - toggles prop on a player");
    RegAdminCmd("sm_propbonus_reloadlist", Command_ReloadPropList, ADMFLAG_ROOT, "sm_propbonus_reloadlist - reloads list of props");
    
    // Hook round events to set and unset props.
    HookPropBonusRoundPluginEvents(true);

    // Attach player prop option to menu.
    new Handle:topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE)) {
        OnAdminMenuReady(topmenu);
    }
    
    AutoExecConfig(true, "plugin.propbonusround");
}

HookPropBonusRoundPluginEvents(bool:bHook) {
    if (bHook) {
        // Hook round events to set and unset props.
        HookEvent("teamplay_round_start", Hook_RoundStart, EventHookMode_Post);
        HookEvent("teamplay_round_win", Hook_RoundWin, EventHookMode_Post);
        
        // Hook player events to unset prop on death and remove prop on player when hit if desired.
        HookEvent("player_death", Hook_Playerdeath, EventHookMode_Post);
        HookEvent("player_hurt", Hook_PlayerHurt, EventHookMode_Post);
    } else {
        // Unhook events.
        UnhookEvent("teamplay_round_start", Hook_RoundStart, EventHookMode_Post);
        UnhookEvent("teamplay_round_win", Hook_RoundWin, EventHookMode_Post);
        UnhookEvent("player_death", Hook_Playerdeath, EventHookMode_Post);
        UnhookEvent("player_hurt", Hook_PlayerHurt, EventHookMode_Post);
    }
}

public OnClientPostAdminCheck(client) {
    g_bIsPlayerAdmin[client] = IsValidAdmin(client, g_sCharAdminFlag);

    g_bIsInThirdperson[client] = false;
    g_bIsProp[client] = false;
}

public OnConfigsExecuted() {
    g_bBonusRound = false;

    g_bPluginEnabled = GetConVarBool(g_hCPluginEnabled);
    GetConVarString(Cvar_AdminFlag, g_sCharAdminFlag, sizeof(g_sCharAdminFlag));

    g_bDmgUnprops = GetConVarInt(g_hCDmgUnprops) != 0;
    g_bAdminOnly = GetConVarInt(g_hCAdminOnly) != 0;
    g_bAnnouncePropRound = GetConVarInt(g_hCAnnouncePropRound) != 0;
    g_bHumiliationRespawn = GetConVarInt(g_hCHumiliationRespawn) != 0;
}

// Client disconnect - unset client prop settings.
public OnClientDisconnect(client) {
    g_bIsInThirdperson[client] = false;
    g_bIsProp[client] = false;
    g_bIsPropLocked[client] = false;
}

public OnMapStart() {
    // Reload the prop listings.
    ProcessConfigFile();

    //Precache all models.
    decl String:sPath[PLATFORM_MAX_PATH];
    for(new i = 0; i < GetArraySize(g_hModelNames); i++) {
        GetArrayString(g_hModelPaths, i, sPath, sizeof(sPath));
        PrecacheModel(sPath, true);
    }
}

public Hook_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled || !g_bBonusRound || !g_bDmgUnprops)
        return;
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    if(client < 1 || attacker < 1 || client == attacker)
        return;

    // Unprop player if attacked by another player.
    if(g_bIsProp[client]) {
        UnpropPlayer(client);
    }
}

public Hook_Playerdeath(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled)
        return;

    new deathflags = GetEventInt(event, "death_flags");
    
    if(deathflags & TF_DEATHFLAG_DEADRINGER)
        return;
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if(client < 1 || !IsClientInGame(client))
        return;

    if(g_bIsProp[client]) {
        UnpropPlayer(client);
    }
}

public Hook_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled)
        return;

    // Unprop all propped players.
    for(new x = 1; x <= MaxClients; x++) {
        if(!IsClientInGame(x)) {
            continue;
        }
        
        if(g_bIsProp[x]) {
            UnpropPlayer(x);
        }
    }
    
    g_bBonusRound = false;
}

public Hook_RoundWin(Handle:event, const String:name[], bool:dontBroadcast) {
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

public Action:Timer_EquipProps(Handle:timer) {
    for (new x = 1; x <= MaxClients; x++) {
        if(!IsClientInGame(x)) {
            continue;
        }
        
        if(GetClientTeam(x) == g_iWinningTeam) {
            continue;
        }
                
        //If player is already a prop, skip id.
        if(g_bIsProp[x]) {
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
                
                SetThirdPerson(x, true, true);
            }
            continue;
        }

        if(IsPlayerAlive(x)) {
            PropPlayer(x);
        }
    }
    return Plugin_Handled;
}

// Toggles prop status on a player.
public Action:Command_Propplayer(client, args) {
    if (!g_bPluginEnabled) {
        return Plugin_Handled;
    }

    decl String:target[MAX_TARGET_LENGTH];
    decl String:target_name[MAX_TARGET_LENGTH];
    decl target_list[MAXPLAYERS];
    decl target_count;
    decl bool:tn_is_ml;
    
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_prop <#userid|name>");
        return Plugin_Handled;
    }
    
    GetCmdArg(1, target, sizeof(target));
    
    if((target_count = ProcessTargetString(target, client, target_list, 
            MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }
    
    for(new i = 0; i < target_count; i++) {
        if(IsClientInGame(target_list[i]) && IsPlayerAlive(target_list[i])) {
            PerformPropPlayer(client, target_list[i], target_count == 1);
        }
    }
    if (target_count > 1) {
        ShowActivity(client, " Toggled prop on %N", target_name);
    }
    return Plugin_Handled;
}

// Turns a client into a prop.  Return value is the index value of the prop selected.
PropPlayer(client) {
    // GetRandomInt is inclusive.
    new iModelIndex = GetRandomInt(0, GetArraySize(g_hModelNames) - 1);
    
    new String:sPath[PLATFORM_MAX_PATH], String:sName[PROPNAME_LENGTH];
    GetArrayString(g_hModelNames, iModelIndex, sName, sizeof(sName));
    GetArrayString(g_hModelPaths, iModelIndex, sPath, sizeof(sPath));
    
    g_bIsProp[client] = true;

    // Set to prop model.
    SetVariantString(sPath);
    AcceptEntityInput(client, "SetCustomModel");
    
    // Enable rotation on the custom model.
    SetVariantInt(1);
    AcceptEntityInput(client, "SetCustomModelRotates");
    
    // Set client to third-person.
    SetThirdPerson(client, true);
    
    // Strip weapons from propped player.
    StripWeapons(client);
    
    SetDemomanEyeGlow(client, false);
    
    // Hide viewmodels for cleanliness.  We don't have any weapons, so it's fine.
    SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
    
    // Kill wearables so Unusual effects do not show.  No worries, they'll be remade on spawn.
    KillClientOwnedEntity(client, "tf_wearable", "CTFWearable");
    
    // Remove canteens, too.  (Merged from PBR v1.5, Sillium.)
    KillClientOwnedEntity(client, "tf_powerup_bottle", "CTFPowerupBottle");
    
    // And remove Demo shields.  Buggy sometimes, though.
    KillClientOwnedEntity(client, "tf_wearable_demoshield", "CTFWearableDemoShield");
    
    // Force prop speed.
    if (g_iPropSpeed != PROP_NO_CUSTOM_SPEED) {
        SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", float(g_iPropSpeed));
    }

    //Print Model name info to client
    PrintCenterText(client, "You are a %s!", sName);
    PrintToChat(client,"\x01You are disguised as a \x04%s\x01 Go hide!", sName);
    
    return iModelIndex;
}

// Turns a client into a not-prop.  The only reason to respawn them is to return weapons to them on unprop (in the case of toggling).
UnpropPlayer(client, bool:respawn = false) {
    // Clear custom model.
    if (IsValidEntity(client)) {
        SetVariantString("");
        AcceptEntityInput(client, "SetCustomModel");
    }
    
    if(g_bIsInThirdperson[client])	{
        SetThirdPerson(client, false);
    }
    
    // Clear prop and proplock flag.
    g_bIsProp[client] = false;
    g_bIsPropLocked[client] = false;
    
    // Reset speed to default.
    TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
    
    // Reset viewmodel.
    SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
    
    // If respawn is set, return their weapons.
    if (respawn) {
        // Store position, angle, and velocity before respawning.
        decl Float:origin[3], Float:angle[3], Float:velocity[3];
        GetClientAbsOrigin(client, origin);
        GetClientEyeAngles(client, angle);
        GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
        
        // Store health to reset to on respawn.
        new iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
        
        // Also force them back to their current class.
        // Can't do anything if they switch loadouts on the class while being a prop, but eh.
        decl TFClassType:class;
        class = TF2_GetPlayerClass(client);
        TF2_SetPlayerClass(client, class);
        TF2_RespawnPlayer(client);
        
        // Return health and position.
        SetEntityHealth(client, iHealth);
        TeleportEntity(client, origin, angle, velocity);
    }
}

KillClientOwnedEntity(client, const String:sEntityName[], const String:sServerEntityName[]) {
    new ent = -1;
    while((ent = FindEntityByClassname(ent, sEntityName)) != -1) {      
        if (GetEntDataEnt2(ent, FindSendPropOffs(sServerEntityName, "m_hOwnerEntity")) == client) {
            AcceptEntityInput(ent, "Kill");
        }
    }
}

SetDemomanEyeGlow(client, bool:enable) {
    new TFClassType:class = TF2_GetPlayerClass(client);
    if (class == TFClass_DemoMan) {
        new decapitations = GetEntProp(client, Prop_Send, "m_iDecapitations");
        if (decapitations >= 1) {
            if(!enable) {
                //Removes Glowing Eye
                TF2_RemoveCondition(client, TFCond_DemoBuff);
            } else {
                //Add Glowing Eye
                TF2_AddCondition(client, TFCond_DemoBuff, -1.0);
            }
        }
    }
}

// Action to prop a player.  Do not show activity here if targetting multiple players.
PerformPropPlayer(client, target, bool:bShowActivity = true) {
    if(!IsClientInGame(target) || !IsPlayerAlive(target))
        return;
    
    if(!g_bIsProp[target]) {
        PropPlayer(target);
        LogAction(client, target, "\"%L\" set prop on \"%L\"", client, target);
        if (bShowActivity) {
            ShowActivity(client, "Set prop on %N", target);
        }
    } else {
        UnpropPlayer(target, true);
        LogAction(client, target, "\"%L\" removed prop on \"%L\"", client, target);
        if (bShowActivity) {
            ShowActivity(client, "Removed prop on %N", target);
        }
    }
}

// Enables and disables third-person mode.
SetThirdPerson(client, bool:bEnabled, bool:bUseDirtyHack = false) {
    if (!g_bIsProp[client]) {
        return;
    }
    
    if (!bUseDirtyHack) {
        // Default behavior.
        // Source: https://forums.alliedmods.net/showthread.php?p=1694178?p=1694178
        SetVariantInt(bEnabled ? 1 : 0);
        AcceptEntityInput(client, "SetForcedTauntCam");
    } else {
        // Prepare to use dirty hack by forcing first-person mode otherwise.
        SetVariantInt(0);
        AcceptEntityInput(client, "SetForcedTauntCam");
        ClientCommand(client, "firstperson");
    
        /**
         * Can't force third-person mode through the taunt camera during humiliation,
         * so we will use some entity dickery to create third-person mode.
         *
         * This third-person mode is a bit laggy when acting on a player, so we only
         * use it during the special case mentioned above.
         */
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bEnabled ? -1 : client);
        SetEntProp(client, Prop_Send, "m_iObserverMode", bEnabled ? 1 : 0);
        SetEntProp(client, Prop_Send, "m_iFOV", bEnabled ? 110 : 90);
    }
    
    g_bIsInThirdperson[client] = bEnabled;
}

// Global forward to test if a client wants to toggle proplock or third-person mode.
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
    // Only run the checks when the client is a prop.
    if (g_bIsProp[client]) {
        // +attack toggles prop locking.
        if ((buttons & IN_ATTACK) == IN_ATTACK) {
            if (!g_bRecentlySetPropLock[client]) {
                // Toggle proplock state.
                SetPropLockState(client, !g_bIsPropLocked[client]);
                
                // Lock in the proplock settings for one second, as this code path is run while +attack is held.
                g_bRecentlySetPropLock[client] = true;
                CreateTimer(1.0, UnsetPropLockToggleDelay, client);
            }
        }
        
        if ((buttons & IN_ATTACK2) == IN_ATTACK2) {
            if (!g_bRecentlySetThirdPerson[client]) {
                // Toggle proplock state.
                SetThirdPerson(client, !g_bIsInThirdperson[client], g_bBonusRound);
                PrintHintText(client, "%s third person mode.", g_bIsInThirdperson[client] ? "Enabled" : "Disabled");
                
                // Lock in the third-person settings for a second, for the same reason as proplock.
                g_bRecentlySetThirdPerson[client] = true;
                CreateTimer(1.0, UnsetThirdPersonToggleDelay, client);
            }
        }
        
        /**
         * Remove proplock state on jump if we are proplocked.
         * Looks better than blocking the jump, as client-side lag comp forces the player back down after it believes it worked.
         */
        if ((buttons & IN_JUMP) == IN_JUMP) {
            if (g_bIsPropLocked[client]) {
                SetPropLockState(client, false);
            }
        }
    }
    return Plugin_Continue;
}

// Sets prop locked state on a client.
SetPropLockState(client, bool:bPropLocked) {
    if (!g_bIsProp[client])
        return;

    // Disable ability to rotate model when proplock is enabled.
    SetVariantInt(bPropLocked ? 0 : 1);
    AcceptEntityInput(client, "SetCustomModelRotates");
    
    // Disable all movement if proplock is enabled.
    if (bPropLocked) {
        SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
    } else {
        // Override speed again if needed.
        if (g_iPropSpeed != PROP_NO_CUSTOM_SPEED) {
            SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", float(g_iPropSpeed));
        } else {
            // Stunning the player resets their speed to default.
            TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
        }
    }
    
    // Show hint text if toggling state in case.
    if (g_bIsPropLocked[client] != bPropLocked)
        PrintHintText(client, "%s prop lock.", bPropLocked ? "Enabled" : "Disabled");
    
    // Update global state.
    g_bIsPropLocked[client] = bPropLocked;
}

public Action:UnsetPropLockToggleDelay(Handle:timer, any:client) {
    // Clear lock on proplock settings.
	g_bRecentlySetPropLock[client] = false;
}

public Action:UnsetThirdPersonToggleDelay(Handle:timer, any:client) {
    // Clear lock on third-person mode.
	g_bRecentlySetThirdPerson[client] = false;
}

public Action:Command_ReloadPropList(client, args) {
    if (!g_bPluginEnabled) {
        return Plugin_Handled;
    }
    
    ProcessConfigFile();
    ReplyToCommand(client, "[SM] %d props reloaded from prop list.", GetArraySize(g_hModelNames));
    
    return Plugin_Handled;
}

// Credit for SMC Parser related code goes to Antithasys!
stock ProcessConfigFile() {
    // Create arrays if they are nonexistent.
    if (g_hModelNames == INVALID_HANDLE) {
        g_hModelNames = CreateArray(PROPNAME_LENGTH, 0);
        g_hModelPaths = CreateArray(PLATFORM_MAX_PATH, 0);
        g_hIncludePropLists = CreateArray(PLATFORM_MAX_PATH, 0);
    }

    ClearArray(g_hModelNames);
    ClearArray(g_hModelPaths);

    // Push a read from the base proplist.
    PushArrayString(g_hIncludePropLists, PROPCONFIG_BASE);

    // Push a read from the map-specific proplist.
    new String:mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    PushArrayString(g_hIncludePropLists, mapName);
    
    // Run through all prop lists, importing new ones.
    // Recheck GetArraySize as other files may have been imported.
    new iCurrentPropCount = 0;
    for (new i = 0; i < GetArraySize(g_hIncludePropLists); i++) {
        new String:propList[PLATFORM_MAX_PATH];
        GetArrayString(g_hIncludePropLists, i, propList, sizeof(propList));
        
        ReadPropConfigurationFile(propList);
        
        new iUpdatedPropCount = GetArraySize(g_hModelNames);
        LogMessage("%d props added from %s.", iUpdatedPropCount - iCurrentPropCount, propList);
        iCurrentPropCount = iUpdatedPropCount;
    }
    
    ClearArray(g_hIncludePropLists);
}

ReadPropConfigurationFile(String:fileName[]) {
    new String:sConfigPath[PLATFORM_MAX_PATH];
    new String:mapFilePath[128];
    Format(mapFilePath, sizeof(mapFilePath), "data/propbonusround/%s.txt", fileName);
    BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), mapFilePath);

    if (!FileExists(sConfigPath) && StrEqual(fileName, PROPCONFIG_BASE)) {
        // Base configuration file file does not exist. Create a basic prop list file before precache.
        LogMessage("Models file not found at %s. Auto-creating file...", mapFilePath);
        
        new String:sConfigDir[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, sConfigDir, sizeof(sConfigDir), "data/propbonusround/");
        if (!DirExists(sConfigDir)) {
            CreateDirectory(sConfigDir, 511);
        }
        
        SetupDefaultProplistFile(sConfigPath);
        
        if (!FileExists(sConfigPath)) {
            // Second fail-safe check. Somehow, the file did not get created, so it is disable time.
            SetFailState("Models file (%s) still not found.", mapFilePath);
        }
    }
    
    if (FileExists(sConfigPath)) {
        new Handle:hParser = SMC_CreateParser();
        new line, col;
        new String:error[128];

        SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
        SMC_SetParseEnd(hParser, Config_End);

        new SMCError:mapResult = SMC_ParseFile(hParser, sConfigPath, line, col);
        CloseHandle(hParser);
        
        if (mapResult != SMCError_Okay) {
            SMC_GetErrorString(mapResult, error, sizeof(error));
            LogError("%s on line %d, col %d of %s", error, line, col, sConfigPath);
            LogError("Failed to parse proplist %s.", sConfigPath);
            
            if (StrEqual(fileName, PROPCONFIG_BASE)) {
                SetFailState("Could not parse file %s", sConfigPath);
            }
        }
    } else {
        LogMessage("Could not find proplist %s.", sConfigPath);
    }
}

public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes) {
    // Read the current config section.
    if (StrEqual(section, "proplist")) {
        g_iPropListSection = PROPCONFIG_PROPLIST;
    } else if (StrEqual(section, "includes")) {
        g_iPropListSection = PROPCONFIG_INCLUDELIST;
    } else if (StrEqual(section, "spawns")) {
        g_iPropListSection = PROPCONFIG_SPAWNPOS;
    } else {
        g_iPropListSection = PROPCONFIG_ROOT;
    }
    return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes) {
    // Check which section we are in and read accordingly.
    switch(g_iPropListSection) {
        case PROPCONFIG_PROPLIST: {
            // Currently in the prop list section.  Add to appropriate prop arrays.
            PushArrayString(g_hModelNames, key);
            PushArrayString(g_hModelPaths, value);
        }
        case PROPCONFIG_INCLUDELIST: {
            // Read any values that aren't already in the external prop list array.
            if (FindStringInArray(g_hIncludePropLists, value) == -1) {
                PushArrayString(g_hIncludePropLists, value);
            }
        }
        case PROPCONFIG_SPAWNPOS: {
            // To be implemented:
            // Custom spawn positions for spawning dead players.
        }
        default: {
        }
    }
    return SMCParse_Continue;
}

public SMCResult:Config_EndSection(Handle:parser) {	
    return SMCParse_Continue;
}

public Config_End(Handle:parser, bool:halted, bool:failed) {
    if (failed) {
        SetFailState("Plugin configuration error");
    }
}

public OnLibraryRemoved(const String:name[]) {
    if (StrEqual(name, "adminmenu")) {
        hAdminMenu = INVALID_HANDLE;
    }
}

public OnAdminMenuReady(Handle:topmenu) {
    if (topmenu == hAdminMenu) {
        return;
    }
    
    hAdminMenu = topmenu;

    new TopMenuObject:player_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_PLAYERCOMMANDS);

    if (player_commands != INVALID_TOPMENUOBJECT) {
        AddToTopMenu(hAdminMenu, PROP_COMMAND, TopMenuObject_Item, AdminMenu_Propplayer, player_commands, PROP_COMMAND, ADMFLAG_ROOT);
    }
}

public AdminMenu_Propplayer( Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength ) {
    if (action == TopMenuAction_DisplayOption) {
        Format(buffer, maxlength, "Prop player");
    } else if (action == TopMenuAction_SelectOption) {
        DisplayPlayerMenu(param);
    }
}

DisplayPlayerMenu(client) {
    new Handle:menu = CreateMenu(MenuHandler_Players);
    
    decl String:title[100];
    Format(title, sizeof(title), "Choose Player:");
    SetMenuTitle(menu, title);
    SetMenuExitBackButton(menu, true);
    
    AddTargetsToMenu(menu, client, true, true);
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Players(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_End) {
        CloseHandle(menu);
    } else if (action == MenuAction_Cancel)	{
        if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE) {
            DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
        }
    } else if (action == MenuAction_Select) {
        decl String:info[32];
        new userid, target;
        
        GetMenuItem(menu, param2, info, sizeof(info));
        userid = StringToInt(info);

        if ((target = GetClientOfUserId(userid)) == 0) {
            PrintToChat(param1, "[SM] %s", "Player no longer available");
        } else if (!CanUserTarget(param1, target)) {
            PrintToChat(param1, "[SM] %s", "Unable to target");
        } else {					
            PerformPropPlayer(param1, target);
        }
        
        // Re-draw the menu if they're still valid
        if (IsClientInGame(param1) && !IsClientInKickQueue(param1)) {
            DisplayPlayerMenu(param1);
        }
    }
}

SetupDefaultProplistFile(String:sConfigPath[]) {
    new Handle:hKVBuildProplist = CreateKeyValues("propbonusround");

    KvJumpToKey(hKVBuildProplist, "proplist", true);
    KvSetString(hKVBuildProplist, "Dynamite Crate", "models/props_2fort/miningcrate001.mdl");
    KvSetString(hKVBuildProplist, "Metal Bucket", "models/props_2fort/metalbucket001.mdl");
    KvSetString(hKVBuildProplist, "Milk Jug", "models/props_2fort/milkjug001.mdl");
    KvSetString(hKVBuildProplist, "Mop and Bucket", "models/props_2fort/mop_and_bucket.mdl");
    KvSetString(hKVBuildProplist, "Cow Cutout", "models/props_2fort/cow001_reference.mdl");
    KvSetString(hKVBuildProplist, "Wood Pallet", "models/props_farm/pallet001.mdl");
    KvSetString(hKVBuildProplist, "Hay Patch", "models/props_farm/haypile001.mdl");
    KvSetString(hKVBuildProplist, "Grain Sack", "models/props_granary/grain_sack.mdl");
    KvSetString(hKVBuildProplist, "Skull Sign", "models/props_mining/sign001.mdl");
    KvSetString(hKVBuildProplist, "Terminal Chair", "models/props_spytech/terminal_chair.mdl");

    KvRewind(hKVBuildProplist);			
    KeyValuesToFile(hKVBuildProplist, sConfigPath);
    
    //Phew...glad thats over with.
    CloseHandle(hKVBuildProplist);
}

StripWeapons(client) {
    if(IsClientInGame(client) && IsPlayerAlive(client)) {
        TF2_RemoveAllWeapons(client);
    }
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
                    if(g_bIsProp[x]) {
                        UnpropPlayer(x, true);
                    }
                }
            }
        }
    } else if(convar == g_hCDmgUnprops) {
        g_bDmgUnprops = StringToInt(newValue) != 0;
    } else if(convar == g_hCAdminOnly) {
        g_bAdminOnly = StringToInt(newValue) != 0;
    } else if(convar == g_hCAnnouncePropRound) {
        g_bAnnouncePropRound = StringToInt(newValue) != 0;
    } else if(convar == g_hCHumiliationRespawn) {
        g_bHumiliationRespawn = StringToInt(newValue) != 0;
    } else if(convar == g_hCPropSpeed) {
        g_iPropSpeed = StringToInt(newValue);
    }
}