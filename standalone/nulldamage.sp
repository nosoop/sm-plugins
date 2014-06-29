#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Global definitions
#define PLUGIN_VERSION "1.0.0"

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
    CreateConVar("sm_nullrekt_version", PLUGIN_VERSION, "Prints version number.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

    // Register commands.
    RegAdminCmd("sm_null", Command_Nullify, ADMFLAG_SLAY, "Prevents a client from dealing damage.");
    RegAdminCmd("sm_rekt", Command_Rektify, ADMFLAG_SLAY, "Toggles whether all damage on a client does 999 damage.");
    RegAdminCmd("sm_nullrekt_list", Command_NullifyList, ADMFLAG_SLAY, "List clients that take massive damage.");
    
    //RegAdminCmd("sm_nullify", Command_Nullify, ADMFLAG_SLAY, "Prevents a client from dealing damage.");
    //RegAdminCmd("sm_nullify_list", Command_NullifyList, ADMFLAG_SLAY, "List clients that do no damage.");
    //RegAdminCmd("sm_null_list", Command_NullifyList, ADMFLAG_SLAY, "List clients that have damage disabled.");
    
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
        ReplyToCommand(client, "Usage: sm_nullify <target>");
        return Plugin_Handled;
    }
 
    // Allocate and get the player argument.
    new String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
 
    // Attempt to find a matching player.
    new target = FindTarget(client, arg1);
    if (target == -1) {
        // FindTarget() automatically replies with the failure reason.
        return Plugin_Handled;
    }

    // Allocate memory to hold the name.
    new String:name[MAX_NAME_LENGTH];
    GetClientName(target, name, sizeof(name));
    
    // Allocate memory for name of client performing action.
    new String:clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));
    
    new String:message[80];
    
    // Toggle nullified damage on a client, displaying a message to admins with the slay flag.
    if (!g_bClientNullDamage[target]) {
        g_bClientNullDamage[target] = true;
        Format(message, sizeof(message), "[SM] %s: Made %s deal almost-zero damage.", clientName, name);
        PrintToAdmins(message, "f");
    } else {
        g_bClientNullDamage[target] = false;
        Format(message, sizeof(message), "[SM] %s: Made %s deal normal damage.", clientName, name);
        PrintToAdmins(message, "f");
    }

    return Plugin_Handled;
}

public Action:Command_Rektify(client, args) {
    // No player specified.
    if (args == 0) {
        ReplyToCommand(client, "Usage: sm_rekt <target>");
        return Plugin_Handled;
    }
 
    // Allocate and get the player argument.
    new String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
 
    // Attempt to find a matching player.
    new target = FindTarget(client, arg1);
    if (target == -1) {
        // FindTarget() automatically replies with the failure reason.
        return Plugin_Handled;
    }

    // Allocate memory to hold the name.
    new String:name[MAX_NAME_LENGTH];
    GetClientName(target, name, sizeof(name));
    
    // Allocate memory for name of client performing action.
    new String:clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));
    
    new String:message[80];
    
    // Toggle nullified damage on a client, displaying a message to admins with the slay flag.
    if (!g_bClientMassiveDamage[target]) {
        g_bClientMassiveDamage[target] = true;
        Format(message, sizeof(message), "[SM] %s: Made %s take stupid damage.", clientName, name);
        PrintToAdmins(message, "f");
    } else {
        g_bClientMassiveDamage[target] = false;
        Format(message, sizeof(message), "[SM] %s: Made %s take normal damage.", clientName, name);
        PrintToAdmins(message, "f");
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