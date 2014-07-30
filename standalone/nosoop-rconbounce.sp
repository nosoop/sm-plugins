/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <smrcon>

#define PLUGIN_VERSION          "1.0.1"     // Plugin version.

// Configuration file name.
#define CONFIG_NAME             "configs/rconbounce.cfg"

// Configuration keys.
#define CONFIGKEY_NOLOG         "nolog"     // Reads the value as a number to determine whether or not to log the command.
#define CONFIGKEY_ADDRESS       "address"   // Reads as a String value and is compared to the connecting IP to determine whether or not authentication is accepted.
#define CONFIGKEY_NOTES         "notes"     // Not read.

#define RCON_MAX_CONNECTIONS    10          // Maximum number of alive connections to rcon before previous sessions are overwritten.
#define RCON_PASSWORD_LENGTH    64          // Maximum length of an rcon password.
#define IPADDR_MAXLENGTH        16          // Maximum length of a String representing an IP address.

public Plugin:myinfo = {
    name = "[ANY] RCON Bouncer",
    author = "nosoop",
    description = "Quick little plugin to set up multi-user rcon authentication, restricting passwords by IP.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new Handle:keyValues = INVALID_HANDLE;
new String:sConfigFullPath[PLATFORM_MAX_PATH];

new sessionCount;
new sessionIds[RCON_MAX_CONNECTIONS];
new String:sessionPasswords[RCON_MAX_CONNECTIONS][RCON_PASSWORD_LENGTH];

public OnPluginStart() {
    RegAdminCmd("sm_rconbounce_reload", Command_ReloadConfig, ADMFLAG_ROOT, "sm_rconbounce_reload -- reloads the rconbounce config file (don't screw it up or you'll have to remote in)");

    PrepareConfigPath();
}

public OnMapStart() {
    ReloadConfig();
}

public Action:Command_ReloadConfig(client, args) {
    ReloadConfig();
    ReplyToCommand(client, "[RCON Bouncer] Reloaded config.");
}

public Action:SMRCon_OnAuth(rconId, const String:address[], const String:password[], &bool:allow) {
    new bool:bAccess = HasRconAccess(address, password);
    if (bAccess) {
        allow = true;
        
        new sessionIndex = sessionCount % RCON_MAX_CONNECTIONS;
        sessionIds[sessionIndex] = rconId;
        strcopy(sessionPasswords[sessionIndex], RCON_PASSWORD_LENGTH, password);
        sessionCount++;
        
        return Plugin_Changed;
    }
    allow = false;
    return Plugin_Changed;
}

public Action:SMRCon_OnLog(rconId, const String:address[], const String:logdata[]) {
    new Action:result = Plugin_Continue;
    new sessionIndex = GetRconSessionIndex(rconId);
    
    if (sessionIndex > -1) {
        decl String:savedPassword[RCON_PASSWORD_LENGTH];
        savedPassword = sessionPasswords[sessionIndex];
        
        new bool:bAccess = KvJumpToKey(keyValues, savedPassword);
        if (bAccess) {
            new bLog = KvGetNum(keyValues, CONFIGKEY_NOLOG, 0);
            
            if (bLog > 0) {
                result = Plugin_Handled;
            }
        }
        KvRewind(keyValues);
    }
    return result;
}

bool:HasRconAccess(const String:address[], const String:password[]) {
    new bool:bAccess = KvJumpToKey(keyValues, password);
    
    if (bAccess) {
        // Deny access by address if desired.
        decl String:addressRestrict[IPADDR_MAXLENGTH];
        KvGetString(keyValues, CONFIGKEY_ADDRESS, addressRestrict, IPADDR_MAXLENGTH);
        
        if (strlen(addressRestrict) > 0) {
            bAccess = StrEqual(address, addressRestrict);
        }
    }
    
    KvRewind(keyValues);
    return bAccess;
}

ReloadConfig() {
    if (keyValues != INVALID_HANDLE) {
        CloseHandle(keyValues);
    }
    keyValues = CreateKeyValues("rconbounce");
    FileToKeyValues(keyValues, sConfigFullPath);
    KvRewind(keyValues);
}

GetRconSessionIndex(rconId) {
    for (new i = 0; i < RCON_MAX_CONNECTIONS; i++) {
        if (sessionIds[i] == rconId) {
            return i;
        }
    }
    return -1;
}

PrepareConfigPath() {
    BuildPath(Path_SM, sConfigFullPath, sizeof(sConfigFullPath), CONFIG_NAME);
    
    // Create a configuration file with the default rcon_password cvar.
    if (!FileExists(sConfigFullPath)) {
        decl String:rconPassword[256];
        GetConVarString(FindConVar("rcon_password"), rconPassword, sizeof(rconPassword));
        keyValues = CreateKeyValues("rconbounce");
        KvJumpToKey(keyValues, rconPassword, true);
        KvSetString(keyValues, CONFIGKEY_NOTES, "Imported from rcon_password convar.  Delete or restrict.");
        KvRewind(keyValues);
        KeyValuesToFile(keyValues, sConfigFullPath);
        CloseHandle(keyValues);
        
        keyValues = INVALID_HANDLE;
    }
}