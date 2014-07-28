/**
 * [TF2] Propify! Plus
 * Author(s): nosoop
 * File: propify_plus.sp
 * Description: Contains a bunch of extended commands to handle props.
 */

#pragma semicolon 1

#include <sourcemod>
#include <propify>

#define PLUGIN_VERSION          "0.5.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Propify! Plus",
    author = "nosoop",
    description = "Extended commands to use with Propify!",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

// Prop Persistence
new g_iPersistProp[MAXPLAYERS+1] = { -1, ... };     // Which prop should the player be spawned as?
new bool:g_bPersistPropOnPlayer[MAXPLAYERS+1];      // Should the player be repropped?

public OnPluginStart() {
    LoadTranslations("common.phrases");
    
    // Prop Persistence
    RegAdminCmd("sm_prop_persist", Command_PropPersist, ADMFLAG_SLAY, "sm_prop_persist <#userid|name> <0|1> - sets whether a player remains a prop between lives");
    RegAdminCmd("sm_propp", Command_PropPersist, ADMFLAG_SLAY);
    HookEvent("player_spawn", Hook_PostPlayerSpawnReprop);
    
    // Prop By Name
    RegAdminCmd("sm_propbyname", Command_PropByName, ADMFLAG_SLAY, "sm_propbyname <#userid|name> <prop name> - attempts to force a prop on a player by name");
    RegAdminCmd("sm_propn", Command_PropByName, ADMFLAG_SLAY);
    
    RegAdminCmd("sm_addprop", Command_AddProp, ADMFLAG_ROOT, "sm_addprop <prop name> <prop path> - temporarily adds a prop to the prop list");
    
    // Filtering targets by whether they are propped or not.
    AddMultiTargetFilter("@props", TargetFilter_Propify, "all props", false);
    AddMultiTargetFilter("@!props", TargetFilter_Propify, "all not-props", false);
}

public Propify_OnPropified(client, propIndex) {
    if (propIndex != -1) {
        g_iPersistProp[client] = propIndex;
    }
}

// Marks a player to remain propped.
public Action:Command_PropPersist(client, args) {
    decl String:target[MAX_TARGET_LENGTH];
    decl String:target_name[MAX_TARGET_LENGTH];
    decl target_list[MAXPLAYERS];
    decl target_count;
    decl bool:tn_is_ml;
    new bool:bEnabled;
    
    if (args < 2) {
        ReplyToCommand(client, "[SM] Usage: sm_prop_persist <#userid|name> <0|1> - toggles persistent prop on a player.");
        return Plugin_Handled;
    }
    
    GetCmdArg(1, target, sizeof(target));
    
    new String:propIndexStr[16];
    GetCmdArg(2, propIndexStr, sizeof(propIndexStr));
    bEnabled = StringToInt(propIndexStr) != 0;
    
    if((target_count = ProcessTargetString(target, client, target_list, 
            MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }
    
    for(new i = 0; i < target_count; i++) {
        if (IsClientInGame(target_list[i])) {
            g_bPersistPropOnPlayer[target_list[i]] = bEnabled;
        }
    }
    
    ShowActivity2(client, "[SM] ", "Toggled prop persistence on %s.", target_name);
    
    return Plugin_Handled;
}

public Hook_PostPlayerSpawnReprop(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    CreateTimer(0.01, Timer_RepropPlayer, client);
}

public Action:Timer_RepropPlayer(Handle:timer, any:client) {
    if (g_bPersistPropOnPlayer[client]) {
        Propify_PropPlayer(client, g_iPersistProp[client]);
    }
}


/**
 * Sets a prop on a player by name.
 */
public Action:Command_PropByName(client, args) {
    decl String:target_name[MAX_TARGET_LENGTH];
    decl target_list[MAXPLAYERS];
    decl target_count;
    decl bool:tn_is_ml;
    
    if (args < 2) {
        ReplyToCommand(client, "[SM] Usage: sm_propbyname <#userid|name> <prop name> - attempts to force a prop on a player by name");
        return Plugin_Handled;
    }
    
    // Get the first argument -- target string of player(s).
    decl String:target[MAX_TARGET_LENGTH];
    GetCmdArg(1, target, sizeof(target));
    
    if((target_count = ProcessTargetString(target, client, target_list, 
            MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }
    
    // Get the second argument -- a substring of a name of a prop.
    decl String:sPropPartialName[32];
    GetCmdArg(2, sPropPartialName, sizeof(sPropPartialName));
    
    // Grab a handle on the model names.
    new Handle:hModelNames = Propify_GetModelNamesArray();
    new nModelCount = GetArraySize(hModelNames);
    
    // Array containing found props.
    new propIndex[4], iUnfilledPropIndex;
    
    // Loop through the prop names until we have gone over the entire prop index or exhausted the found props array.
    for (new i = 0; i < nModelCount && iUnfilledPropIndex < sizeof(propIndex); i++) {
        decl String:sPropName[32];
        GetArrayString(hModelNames, i, sPropName, sizeof(sPropName));
        if (StrContains(sPropName, sPropPartialName, false) > -1) {
            propIndex[iUnfilledPropIndex++] = i;
        }
    }
    CloseHandle(hModelNames);
    
    if (iUnfilledPropIndex > 0) {
        for (new i = 0; i < target_count; i++) {
            if (IsClientInGame(target_list[i])) {
                Propify_PropPlayer(target_list[i], propIndex[0]);
            }
        }
        ShowActivity2(client, "[SM] ", "Forced prop by name on %s.", target_name);
    } else {
        ReplyToCommand(client, "[SM] Could not find prop name with that as a substring.");
    }
    
    return Plugin_Handled;
}


/**
 * Adds a prop to the prop list.  The prop remains until the prop list is reloaded manually or on map change.
 */
public Action:Command_AddProp(client, args) {
    decl String:propName[32], String:propPath[PLATFORM_MAX_PATH];
    
    if (args < 2) {
        ReplyToCommand(client, "sm_addprop <prop name> <prop path>");
        return Plugin_Handled;
    }
    
    GetCmdArg(1, propName, sizeof(propName));
    GetCmdArg(2, propPath, sizeof(propPath));
    
    Propify_AddModelData(propName, propPath);
    ReplyToCommand(client, "[SM] Added prop '%s'.", propName);
    return Plugin_Handled;
}

/**
 * Target filters.
 */
public bool:TargetFilter_Propify(const String:strPattern[], Handle:hClients) {
    new bool:bInvert = (strPattern[1] == '!');
    
    for(new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (Propify_IsClientProp(i) != bInvert)
                PushArrayCell(hClients, i);
        }
    }
    return true;
}

