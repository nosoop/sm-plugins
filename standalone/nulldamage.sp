#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Global definitions
#define PLUGIN_VERSION "1.2.0"

// Boolean arrays to determine which clients do 0.01 damage and take 9999.0 damage.
new bool:g_bClientNullDamage[MAXPLAYERS+1] = {false, ... };
new bool:g_bClientMassiveDamage[MAXPLAYERS+1] = {false, ... };

// Plugin information
public Plugin:myinfo =
{
    name = "[ALL] Nullify / Maximize Damage",
    author = "nosoop",
    description = "Prevents clients from dealing damage or makes them take stupid amounts thereof.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
};

// Plugin started
public OnPluginStart() {
    LoadTranslations("common.phrases");

    CreateConVar("sm_nullrekt_version", PLUGIN_VERSION, "Prints version number.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

    // Register commands.
    RegAdminCmd("sm_null", Command_Nullify, ADMFLAG_SLAY, "Prevents a client from dealing damage.");
    RegAdminCmd("sm_rekt", Command_Rektify, ADMFLAG_SLAY, "Toggles whether all damage on a client does 999 damage.");
    RegAdminCmd("sm_nullrekt_list", Command_NullifyList, ADMFLAG_SLAY, "List clients that take massive damage.");
    
    // Hook from all running clients.
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

// Client added to server.
public OnClientPutInServer(client) {
    // Hook event from new clients and reset the damage-nullified state.
    if (!IsClientReplay(client) && !IsClientSourceTV(client)) {
        g_bClientNullDamage[client] = false;
        g_bClientMassiveDamage[client] = false;
        SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public Action:Command_Nullify(client, args) {
    // No player specified.
    if (args == 0) {
        ReplyToCommand(client, "Usage: sm_null <target> [0|1]");
        return Plugin_Handled;
    }
 
    // Allocate argument values.
    decl String:arg1[32], String:arg2[32];
    
    // Get the player argument.
    GetCmdArg(1, arg1, sizeof(arg1));
    
    // Optional variable to force a setting, if multi-targetting, required.
    new bool:toggle = true, bool:overrideTo = false;
    if (args >= 2 && GetCmdArg(2, arg2, sizeof(arg2))) {
        toggle = false;
		overrideTo = StringToInt(arg2) == 1;
	}
 
    // Attempt to find a matching player(s).
    decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
    if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, 
            COMMAND_FILTER_ALIVE & COMMAND_FILTER_DEAD, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	// Allocate memory for name of client performing action.
    decl String:clientName[MAX_NAME_LENGTH], String:message[80];
    GetClientName(client, clientName, sizeof(clientName));
	
	if (target_count == 1) {
        new target = target_list[0];
        if (toggle) {
            g_bClientNullDamage[target] = !g_bClientNullDamage[target];
        } else {
            g_bClientNullDamage[target] = overrideTo;
        }
        
        Format(message, sizeof(message), "[SM] %s: Made %s deal %s damage.", clientName, target_name,
                g_bClientNullDamage[target_list[0]] ? "almost zero" : "normal");
        PrintToAdmins(message, "f");
	} else {
        if (!toggle) {
            for (new i = 0; i < target_count; i++) {
                g_bClientNullDamage[target_list[i]] = overrideTo;
            }
            
            Format(message, sizeof(message), "[SM] %s: Forced %s to deal %s damage.", clientName, target_name,
                overrideTo ? "almost zero" : "normal");
            PrintToAdmins(message, "f");
        } else {
            ReplyToCommand(client, "Usage: sm_null <target> [0|1]\nMissing required boolean parameter.");
        }
    }
    
    return Plugin_Handled;
}

public Action:Command_Rektify(client, args) {
    // No player specified.
    if (args == 0) {
        ReplyToCommand(client, "Usage: sm_rekt <target> [0|1]");
        return Plugin_Handled;
    }
 
    // Allocate argument values.
    decl String:arg1[32], String:arg2[32];
    
    // Get the player argument.
    GetCmdArg(1, arg1, sizeof(arg1));
    
    // Optional variable to force a setting, if multi-targetting, required.
    new bool:toggle = true, bool:overrideTo = false;
    if (args >= 2 && GetCmdArg(2, arg2, sizeof(arg2))) {
        toggle = false;
		overrideTo = StringToInt(arg2) == 1;
	}
 
    // Attempt to find a matching player(s).
    decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
    if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, 
            COMMAND_FILTER_ALIVE & COMMAND_FILTER_DEAD, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	// Allocate memory for name of client performing action.
    decl String:clientName[MAX_NAME_LENGTH], String:message[80];
    GetClientName(client, clientName, sizeof(clientName));
	
	if (target_count == 1) {
        new target = target_list[0];
        if (toggle) {
            g_bClientMassiveDamage[target] = !g_bClientMassiveDamage[target];
        } else {
            g_bClientMassiveDamage[target] = overrideTo;
        }
        
        Format(message, sizeof(message), "[SM] %s: Made %s take %s damage.", clientName, target_name,
                g_bClientMassiveDamage[target_list[0]] ? "stupid" : "normal");
        PrintToAdmins(message, "f");
	} else {
        if (!toggle) {
            for (new i = 0; i < target_count; i++) {
                g_bClientMassiveDamage[target_list[i]] = overrideTo;
            }
            
            Format(message, sizeof(message), "[SM] %s: Forced %s to take %s damage.", clientName, target_name,
                overrideTo ? "stupid" : "normal");
            PrintToAdmins(message, "f");
        } else {
            ReplyToCommand(client, "Usage: sm_rekt <target> [0|1]\nMissing required boolean parameter.");
        }
    }
    
    return Plugin_Handled;
}

public Action:Command_NullifyList(client, args) {
    ReplyToCommand(client, "[SM] List of clients with nullified damage:");
    
    new iNullifiedPlayers = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i)) {
            if (g_bClientNullDamage[i]) {
                new String:name[MAX_NAME_LENGTH];
                GetClientName(i, name, sizeof(name));
                ReplyToCommand(client, "%d: %s", i, name);
                iNullifiedPlayers++;
            }
        }
    }
    if (iNullifiedPlayers == 0) {
        // No players have damage disabled.
        ReplyToCommand(client, "There are currently no players that have damage nullified.");
    }
    
    ReplyToCommand(client, "\n[SM] List of clients that take stupid damage:");
    new iRektPlayers = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i)) {
            if (g_bClientMassiveDamage[i]) {
                new String:name[MAX_NAME_LENGTH];
                GetClientName(i, name, sizeof(name));
                ReplyToCommand(client, "%d: %s", i, name);
                iRektPlayers++;
            }
        }
    }
    if (iRektPlayers == 0) {
        // No players have damage disabled.
        ReplyToCommand(client, "There are currently no players that take stupid damage.");
    }
    return Plugin_Handled;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom) {
    if (attacker > 0 && attacker <= MaxClients && attacker != victim && g_bClientNullDamage[attacker]) {   
        // Makes the client do 0.01 damage.  Arbitrary number, but non-zero so crit notifications still show.
        // Minimal damage is inflicted on players that also take massive damage.
        damage = 0.01;
        return Plugin_Changed;
    }
    
    if (g_bClientMassiveDamage[victim]) {
        // Do stupid damage on players with this flag.
        damage = 9999.0;
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

// Prints to all admins with the specified flag set.
PrintToAdmins(const String:message[], const String:flags[]) {
    for (new x = 1; x <= MaxClients; x++) {
        if (IsValidClient(x) && IsValidAdmin(x, flags)) {
            PrintToChat(x, message);
        }
    }
}

// Checks whether or not a client is a valid entry.
bool:IsValidClient(client, bool:nobots = true) {
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client))) {
        return false;
    }
    return IsClientInGame(client);
}

// Checks if a client is an admin.
bool:IsValidAdmin(client, const String:flags[]) {
    new ibFlags = ReadFlagString(flags);
    if ((GetUserFlagBits(client) & ibFlags) == ibFlags) {
        return true;
    }
    if (GetUserFlagBits(client) & ADMFLAG_ROOT) {
        return true;
    }
    return false;
}