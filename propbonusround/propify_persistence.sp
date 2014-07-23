/**
 * Allows an admin to make a specific player a prop.
 */

#pragma semicolon 1

#include <sourcemod>
#include <propify>

#define PLUGIN_VERSION          "0.2.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Propify! Persistence",
    author = "nosoop",
    description = "Persist being a prop between lives!",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new g_iPersistProp[MAXPLAYERS+1] = { -1, ... };
new bool:g_bPersistPropOnPlayer[MAXPLAYERS+1];

public OnPluginStart() {
    LoadTranslations("common.phrases");
    
    RegAdminCmd("sm_pprop", Command_PropPersist, ADMFLAG_SLAY, "sm_pprop <#userid|name> <0|1> - toggles persistent prop on a player");
    HookEvent("player_spawn", Hook_PostPlayerSpawn);
}

// TODO Add checks for player disconnect.

public Propify_OnPropified(client, propIndex) {
    if (propIndex != -1) {
        g_iPersistProp[client] = propIndex;
    }
}

public Action:Command_PropPersist(client, args) {
    decl String:target[MAX_TARGET_LENGTH];
    decl String:target_name[MAX_TARGET_LENGTH];
    decl target_list[MAXPLAYERS];
    decl target_count;
    decl bool:tn_is_ml;
    new bool:bEnabled;
    
    if (args < 2) {
        ReplyToCommand(client, "[SM] Usage: sm_pprop <#userid|name> <0|1> - toggles persistent prop on a player.");
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

public Hook_PostPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    CreateTimer(0.01, Timer_RepropPlayer, client);
}

public Action:Timer_RepropPlayer(Handle:timer, any:client) {
    if (g_bPersistPropOnPlayer[client]) {
        Propify_PropPlayer(client, g_iPersistProp[client]);
    }
}