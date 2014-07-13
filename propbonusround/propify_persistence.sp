/**
 * Allows an admin to make a specific player a prop.
 */

#pragma semicolon 1

#include <sourcemod>
#include <propify>

#define PLUGIN_VERSION          "0.1.0"     // Plugin version.
#define PROP_RANDOM_TOGGLE      -2          // Value to turn a player into a random prop or to turn them out of a prop.

public Plugin:myinfo = {
    name = "[TF2] Propify! Persistence",
    author = "nosoop",
    description = "Persist being a prop between lives!",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new g_iPersistProp[MAXPLAYERS+1] = { -1, ... };

public OnPluginStart() {
    RegAdminCmd("sm_pprop", Command_PropPersist, ADMFLAG_SLAY, "sm_pprop <#userid|name> [propindex] - toggles persistent prop on a player");
    
    HookEvent("player_spawn", Hook_PostPlayerSpawn);
}

// TODO Add checks for player disconnect.

public Action:Command_PropPersist(client, args) {
    decl String:target[MAX_TARGET_LENGTH];
    decl String:target_name[MAX_TARGET_LENGTH];
    decl target_list[MAXPLAYERS];
    decl target_count;
    decl bool:tn_is_ml;
    new propIndex = PROP_RANDOM_TOGGLE;
    
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_pprop <#userid|name> [propindex] - toggles persistent prop on a player.");
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
        if (IsClientInGame(target_list[i]) && IsPlayerAlive(target_list[i])) {
            PerformPropPlayer(client, target_list[i], propIndex);
        }
    }
    
    ShowActivity2(client, "[SM] ", "Toggled persistent prop on %s.", target_name);
    
    return Plugin_Handled;
}

PerformPropPlayer(client, target, propIndex = PROP_RANDOM_TOGGLE) {
    if(!IsClientInGame(target) || !IsPlayerAlive(target))
        return;
    
    // If not a prop or we are forcing a prop by using a value >= PROP_RANDOM...
    if(IsClientProp(target) || propIndex >= PROP_RANDOM) {
        propIndex = PropPlayer(target, propIndex) == 1 ? propIndex : -1;
    } else {
        UnpropPlayer(target, true);
        propIndex = -1;
    }
    
    LogAction(client, target, "\"%L\" %s persistent prop on \"%L\"", client, IsClientProp(target) ? "set" : "removed", target);
    g_iPersistProp[client] = propIndex;
}

public Hook_PostPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    CreateTimer(0.01, Timer_RepropPlayer, client);
}

public Action:Timer_RepropPlayer(Handle:timer, any:client) {
    if (g_iPersistProp[client] >= 0) {
        PropPlayer(client, g_iPersistProp[client]);
    }
}