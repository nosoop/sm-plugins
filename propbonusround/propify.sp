/**
 * [TF2] Propify!
 * Author(s): nosoop, "Prop Bonus Round" developers
 * File: propify.sp
 * Description: Turns players into props!  Also exposes the proppening of players by other plugins.
 *
 * 2.0.0 - Changed "Prop Bonus Round" into "Propify!" and moved endround functionality to another plugin.
 *         As such, version numbers will not be synchronized for functionality patches.
 * 1.0.0 - Forked from https://forums.alliedmods.net/showthread.php?p=1096024
 * Forked version was 1.3 in the original post.  See credits for their work there.  They deserve it!
 *
 * See the commits to https://github.com/nosoop/sm-plugins for improvements and updated notes.
 */

#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define PLUGIN_VERSION          "2.1.5"     // Plugin version.  Am I doing semantic versioning right?

#define PROP_COMMAND            "sm_prop"   // Default prop command name.
#define PROP_NO_CUSTOM_SPEED    0           // Special value of sm_propbonus_forcespeed that disables the speed override.
                                            // (Keep unchanged as 0 isn't a valid speed anyways.)

#define PROP_RANDOM             -1          // Value for an unspecified prop to force a player into.
#define PROP_RANDOM_TOGGLE      -2          // Value to turn a player into a random prop or to turn them out of a prop.

#define PROPLIST_BASEFILE       "base"      // Base configuration file.
#define PROPLIST_ROOT           0           // Constants for sections of the configuration. (No reads.)
#define PROPLIST_PROPS          1           // KV: "prop name" "models/path/to/prop/file.mdl"
#define PROPLIST_INCLUDELIST    2           // KV: "any value" "file name to load another propconfig"
#define PROPLIST_SPAWNPOS       3           // KV: "any value" "X Y Z P Y R" (spawn positions and angles?)
                                            // TODO Move PROPLIST_SPAWNPOS into the Prop End Round plugin.

#define PROPNAME_LENGTH         32          // The maximum length of a prop name.

new Handle:hAdminMenu = INVALID_HANDLE;

// Arrays for prop models, names, and a list of additional files to load.
new g_iPropListSection = PROPLIST_ROOT;
new Handle:g_hModelNames = INVALID_HANDLE, Handle:g_hModelPaths = INVALID_HANDLE;
new Handle:g_hIncludePropLists = INVALID_HANDLE;

// ConVars and junk.  For references, see OnPluginStart().
new Handle:g_hCPluginEnabled = INVALID_HANDLE,      bool:g_bPluginEnabled;      // sm_propify_enabled
new Handle:g_hCPropSpeed = INVALID_HANDLE,          g_iPropSpeed;               // sm_propify_forcespeed

// Boolean flags for prop functions.
new bool:g_bIsProp[MAXPLAYERS+1],
    bool:g_bIsPropLocked[MAXPLAYERS+1], bool:g_bRecentlySetPropLock[MAXPLAYERS+1],
    bool:g_bIsInThirdPerson[MAXPLAYERS+1], bool:g_bRecentlySetThirdPerson[MAXPLAYERS+1];

/**
 * Sets whether or not we use the hackish method of setting third-person mode.
 * We need this for props that toggle views during endround.
 */
new bool:g_bUseDirtyHackForThirdPerson;

public Plugin:myinfo = {
    name = "[TF2] Propify!",
    author = "nosoop, Prop Bonus Round developers",
    description = "Turn players into props!",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
}

public OnPluginStart() {
    CheckGame();

    CreateConVar("sm_propify_version", PLUGIN_VERSION, "Version of Propify!", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    // Create and hook cvars.
    g_hCPluginEnabled = CreateConVar("sm_propify_enabled", "1", "Enable / disable the propify plugin.  Disabling the plugin unprops all propped players.");
    HookConVarChange(g_hCPluginEnabled, Cvars_Changed);
    
    g_hCPropSpeed = CreateConVar("sm_propify_forcespeed", "0", "Force all props to a specific speed, in an integer representing HU/s.  Setting this to 0 allows props to move at their default class speed.");
    HookConVarChange(g_hCPropSpeed, Cvars_Changed);
    
    // Command to prop a player.
    RegAdminCmd(PROP_COMMAND, Command_Propplayer, ADMFLAG_SLAY, "sm_prop <#userid|name> [propindex] - toggles prop on a player");
    RegAdminCmd("sm_propify_reloadlist", Command_ReloadPropList, ADMFLAG_ROOT, "sm_propify_reloadlist - reloads list of props");
    
    // Hook round events to set and unset props.
    HookPropifyPluginEvents(true);

    // Attach player prop option to menu.
    new Handle:topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE)) {
        OnAdminMenuReady(topmenu);
    }
    
    AutoExecConfig(true, "plugin.propify");
}

public APLRes:AskPluginLoad2(Handle:hMySelf, bool:bLate, String:strError[], iMaxErrors) {
    RegPluginLibrary("nosoop-propify");
    CreateNative("PropPlayer", Native_PropPlayer);
    CreateNative("UnpropPlayer", Native_UnpropPlayer);
    CreateNative("IsClientProp", Native_IsClientProp);

    return APLRes_Success;
}

HookPropifyPluginEvents(bool:bHook) {
    if (bHook) {
        // Hook round events to determine which third-person mode to use and to unset props at round start.
        HookEvent("teamplay_round_start", Hook_PostRoundStart);
        HookEvent("teamplay_round_win", Hook_PreRoundWin, EventHookMode_Pre);

        // Hook player events to unset prop on death.
        HookEvent("player_death", Hook_PostPlayerDeath);
        
        // Hook resupply and spawn to restrip props of cosmetics and items.
        HookEvent("player_spawn", Hook_PostPlayerSpawn);
        HookEvent("post_inventory_application", Hook_PostPlayerInventoryUpdate);
    } else {
        // Unhook events.
        UnhookEvent("teamplay_round_start", Hook_PostRoundStart);
        UnhookEvent("teamplay_round_win", Hook_PreRoundWin, EventHookMode_Pre);
        UnhookEvent("player_death", Hook_PostPlayerDeath);
        UnhookEvent("player_spawn", Hook_PostPlayerSpawn);
        UnhookEvent("post_inventory_application", Hook_PostPlayerInventoryUpdate);
    }
}

public OnClientPostAdminCheck(client) {
    g_bIsInThirdPerson[client] = false;
    g_bIsProp[client] = false;
}

public OnConfigsExecuted() {
    g_bUseDirtyHackForThirdPerson = false;
    g_bPluginEnabled = GetConVarBool(g_hCPluginEnabled);
}

// Client disconnect - unset client prop settings.
public OnClientDisconnect(client) {
    g_bIsInThirdPerson[client] = false;
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

public Hook_PostPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled)
        return;

    new deathflags = GetEventInt(event, "death_flags");
    
    if(deathflags & TF_DEATHFLAG_DEADRINGER)
        return;
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if(client < 1 || !IsClientInGame(client))
        return;

    UnpropPlayer(client);
}

public Hook_PostRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled)
        return;

    // Unprop all propped players.
    for (new x = 1; x <= MaxClients; x++) {
        UnpropPlayer(x);
    }
    g_bUseDirtyHackForThirdPerson = false;
}

public Hook_PreRoundWin(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled)
        return;

    g_bUseDirtyHackForThirdPerson = true;
}

public Hook_PostPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    // If they switched classes or something, unprop them for now.
    // TODO Fix?
    UnpropPlayer(client, true);
}

public Hook_PostPlayerInventoryUpdate(Handle:event, const String:name[], bool:dontBroadcast) {
    if(!g_bPluginEnabled)
        return;

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_bIsProp[client]) {
        // Restrip players of items.
        HidePlayerItemsAndDoPropStuff(client);
    }
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
    new propIndex = PROP_RANDOM_TOGGLE;
    
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_prop <#userid|name> [propindex] - toggles prop on a player.\n" ...
                "  propindex can be one of the following:\n" ...
                "  -2 = toggle into and out of a random prop (default),\n" ...
                "  -1 = random prop, rerolling if already a prop,\n" ...
                "  [0, ...) = one of the props on the list,\n" ...
                "  (..., -3] = force unprop.");
        return Plugin_Handled;
    }
    
    GetCmdArg(1, target, sizeof(target));
    
    if (args > 1) {
        new String:propIndexStr[16];
        GetCmdArg(2, propIndexStr, sizeof(propIndexStr));
        propIndex = StringToInt(propIndexStr);
    }
    
    if((target_count = ProcessTargetString(target, client, target_list, 
            MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }
    
    for(new i = 0; i < target_count; i++) {
        if(IsClientInGame(target_list[i]) && IsPlayerAlive(target_list[i])) {
            PerformPropPlayer(client, target_list[i], propIndex, target_count == 1);
        }
    }
    if (target_count > 1) {
        ShowActivity(client, "Toggled prop on %N", target_name);
    }
    return Plugin_Handled;
}

public Native_IsClientProp(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    return g_bIsProp[client];
}

// Turns a client into a prop.  Return value is the index value of the prop selected.
PropPlayer(client, propIndex = PROP_RANDOM) {
    new iModelIndex;
    // If the index is a negative number, we are picking a random prop.
    // Prop toggles and force-disabling props are special values for sm_prop, disregard here.
    if (propIndex <= PROP_RANDOM) {
        // GetRandomInt is inclusive, so last model index = size of array minus one.
        iModelIndex = GetRandomInt(0, GetArraySize(g_hModelNames) - 1);
    } else {
        iModelIndex = propIndex;
    }
    
    new String:sPath[PLATFORM_MAX_PATH], String:sName[PROPNAME_LENGTH];
    GetArrayString(g_hModelNames, iModelIndex, sName, sizeof(sName));
    GetArrayString(g_hModelPaths, iModelIndex, sPath, sizeof(sPath));

    // Set to prop model and enable prop rotation.
    SetVariantString(sPath);
    AcceptEntityInput(client, "SetCustomModel");
    
    // Print prop name and such to the client.
    PrintToChat(client,"\x01You are disguised as a \x04%s\x01!", sName);

    // If the client was already a prop, the model change is all that needs to be done.
    if (g_bIsProp[client]) {
        return iModelIndex;
    }
    
    g_bIsProp[client] = true;
    
    SetVariantInt(1);
    AcceptEntityInput(client, "SetCustomModelRotates");
    
    // Set client to third-person and strip weapons and force speed override if desired.
    SetThirdPerson(client, true, g_bUseDirtyHackForThirdPerson);
    HidePlayerItemsAndDoPropStuff(client);
        
    return iModelIndex;
}

// Exposed PropPlayer method.
public Native_PropPlayer(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    new propIndex = numParams > 1 ? GetNativeCell(2) : PROP_RANDOM;
    
    if(client >= 1 && client <= MAXPLAYERS && IsClientInGame(client) && IsPlayerAlive(client)) {
        PropPlayer(client, propIndex);
        return true;
    }
    
    return false;
}

// Turns a client into a not-prop if they are.  The only reason to respawn them is to return weapons to them on unprop (in the case of toggling).
UnpropPlayer(client, bool:respawn = false) {
    if (!g_bIsProp[client] || !IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    // Clear custom model.
    if (IsValidEntity(client)) {
        SetVariantString("");
        AcceptEntityInput(client, "SetCustomModel");
    }
    
    if(g_bIsInThirdPerson[client])    {
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

// Exposed UnpropPlayer method.
public Native_UnpropPlayer(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    new bool:respawn = numParams > 1 ? GetNativeCell(2) : false;
    
    if(client >= 1 && client <= MAXPLAYERS && IsClientInGame(client) && IsPlayerAlive(client)) {
        UnpropPlayer(client, respawn);
        return true;
    }
    
    return false;
}

// Very descriptive, isn't it.  Things to do to a prop that has their items.
HidePlayerItemsAndDoPropStuff(client) {
    // Strip weapons from propped player and hide Demoman eyeglow.
    StripWeapons(client);
    TF2_RemoveCondition(client, TFCond_DemoBuff);
    
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
}

KillClientOwnedEntity(client, const String:sEntityName[], const String:sServerEntityName[]) {
    new ent = -1;
    while((ent = FindEntityByClassname(ent, sEntityName)) != -1) {      
        if (GetEntDataEnt2(ent, FindSendPropOffs(sServerEntityName, "m_hOwnerEntity")) == client) {
            AcceptEntityInput(ent, "Kill");
        }
    }
}

// Action to prop a player.  Do not show activity here if targetting multiple players.
PerformPropPlayer(client, target, propIndex = PROP_RANDOM_TOGGLE, bool:bShowActivity = true) {
    if(!IsClientInGame(target) || !IsPlayerAlive(target))
        return;
    
    // If not a prop or we are forcing a prop by using a value >= PROP_RANDOM...
    if(!g_bIsProp[target] || propIndex >= PROP_RANDOM) {
        if (propIndex < PROP_RANDOM_TOGGLE || (g_bIsProp[target] && propIndex == PROP_RANDOM_TOGGLE) ) {
            // Unprop the player if they are a prop and set to untoggle or if it's a larger negative number.
            UnpropPlayer(target, true);
        } else {
            // Otherwise, check the bounds and turn the player into a prop if it's a valid entry.
            new iModelCount = GetArraySize(g_hModelNames) - 1;
            if (propIndex > iModelCount) {
                ReplyToCommand(client, "[SM] Failed to prop %N: prop index must be between -1 (random prop) and %d.", target, iModelCount);
                return;
            }
            PropPlayer(target, propIndex);
        }
    } else {
        UnpropPlayer(target, true);
    }
    
    LogAction(client, target, "\"%L\" %s prop on \"%L\"", client, g_bIsProp[target] ? "set" : "removed", target);
    if (bShowActivity) {
        ShowActivity(client, "%s prop on %N.", g_bIsProp[target] ? "Set" : "Removed", target);
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
    
    g_bIsInThirdPerson[client] = bEnabled;
}

// Global forward to test if a propped client wants to toggle proplock or third-person mode.
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
    if (g_bIsProp[client]) {
        // +attack toggles prop locking.
        if ((buttons & IN_ATTACK) == IN_ATTACK) {
            if (!g_bRecentlySetPropLock[client]) {
                SetPropLockState(client, !g_bIsPropLocked[client]);
                
                // Lock in the proplock settings for one second, as this code path is reached while +attack is held.
                g_bRecentlySetPropLock[client] = true;
                CreateTimer(1.0, UnsetPropLockToggleDelay, client);
            }
        }
        
        // +attack2 toggles third-person state.
        if ((buttons & IN_ATTACK2) == IN_ATTACK2) {
            if (!g_bRecentlySetThirdPerson[client]) {
                SetThirdPerson(client, !g_bIsInThirdPerson[client], g_bUseDirtyHackForThirdPerson);
                PrintHintText(client, "%s third person mode.", g_bIsInThirdPerson[client] ? "Enabled" : "Disabled");
                
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
ProcessConfigFile() {
    // Create arrays if they are nonexistent.
    if (g_hModelNames == INVALID_HANDLE) {
        g_hModelNames = CreateArray(PROPNAME_LENGTH, 0);
        g_hModelPaths = CreateArray(PLATFORM_MAX_PATH, 0);
        g_hIncludePropLists = CreateArray(PLATFORM_MAX_PATH, 0);
    }

    ClearArray(g_hModelNames);
    ClearArray(g_hModelPaths);

    // Push a read from the base proplist.
    PushArrayString(g_hIncludePropLists, PROPLIST_BASEFILE);

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

ReadPropConfigurationFile(const String:fileName[]) {
    new String:sPropFileFullPath[PLATFORM_MAX_PATH];
    new String:sPropFilePath[128];
    Format(sPropFilePath, sizeof(sPropFilePath), "data/propify/%s.txt", fileName);
    BuildPath(Path_SM, sPropFileFullPath, sizeof(sPropFileFullPath), sPropFilePath);

    if (!FileExists(sPropFileFullPath) && StrEqual(fileName, PROPLIST_BASEFILE)) {
        // Base configuration file file does not exist. Create a basic prop list file before precache.
        LogMessage("Models file not found at %s. Auto-creating file...", sPropFilePath);
        
        new String:sConfigDir[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, sConfigDir, sizeof(sConfigDir), "data/propify/");
        if (!DirExists(sConfigDir)) {
            CreateDirectory(sConfigDir, 511);
        }
        
        SetupDefaultProplistFile(sPropFileFullPath);
        
        if (!FileExists(sPropFileFullPath)) {
            // Second fail-safe check. Somehow, the file did not get created, so it is disable time.
            SetFailState("Models file (%s) still not found.", sPropFilePath);
        }
    }
    
    if (FileExists(sPropFileFullPath)) {
        new Handle:hParser = SMC_CreateParser();
        new line, col;
        new String:error[128];

        SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
        SMC_SetParseEnd(hParser, Config_End);

        new SMCError:mapResult = SMC_ParseFile(hParser, sPropFileFullPath, line, col);
        CloseHandle(hParser);
        
        if (mapResult != SMCError_Okay) {
            SMC_GetErrorString(mapResult, error, sizeof(error));
            LogError("%s on line %d, col %d of %s", error, line, col, sPropFileFullPath);
            LogError("Failed to parse proplist %s.", sPropFileFullPath);
            
            if (StrEqual(fileName, PROPLIST_BASEFILE)) {
                SetFailState("Could not parse file %s", sPropFileFullPath);
            }
        }
    } else {
        LogMessage("Could not find proplist %s.", sPropFileFullPath);
    }
}

public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes) {
    // Read the current config section.
    if (StrEqual(section, "proplist")) {
        g_iPropListSection = PROPLIST_PROPS;
    } else if (StrEqual(section, "includes")) {
        g_iPropListSection = PROPLIST_INCLUDELIST;
    } else if (StrEqual(section, "spawns")) {
        g_iPropListSection = PROPLIST_SPAWNPOS;
    } else {
        g_iPropListSection = PROPLIST_ROOT;
    }
    return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes) {
    // Check which section we are in and read accordingly.
    switch(g_iPropListSection) {
        case PROPLIST_PROPS: {
            // Currently in the prop list section.  Add to appropriate prop arrays.
            PushArrayString(g_hModelNames, key);
            PushArrayString(g_hModelPaths, value);
        }
        case PROPLIST_INCLUDELIST: {
            // Read any values that aren't already in the external prop list array.
            if (FindStringInArray(g_hIncludePropLists, value) == -1) {
                PushArrayString(g_hIncludePropLists, value);
            }
        }
        case PROPLIST_SPAWNPOS: {
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

public AdminMenu_Propplayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength ) {
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
    } else if (action == MenuAction_Cancel)    {
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

SetupDefaultProplistFile(const String:sConfigPath[]) {
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

public Cvars_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
    if(convar == g_hCPluginEnabled) {
        g_bPluginEnabled = StringToInt(newValue) != 0;
        HookPropifyPluginEvents(g_bPluginEnabled);
        
        if (!g_bPluginEnabled) {
            // Unprop and respawn the player when the plugin is disabled dynamically.
            for (new x = 1; x <= MaxClients; x++) {
                if(IsClientInGame(x) && IsPlayerAlive(x)) {
                    UnpropPlayer(x, true);
                }
            }
        }
    } else if(convar == g_hCPropSpeed) {
        g_iPropSpeed = StringToInt(newValue);
    }
}