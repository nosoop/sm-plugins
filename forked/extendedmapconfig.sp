/**
 * Application:      extendedmapconfig.smx
 * Author:           Milo <milo@corks.nl>
 * Target platform:  Sourcemod 1.6.0 + Metamod 1.10.1 + Team Fortress 2 (20140817)
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * This plugin was forked: https://forums.alliedmods.net/showthread.php?t=85551
 * 
 * Changed to support OnAutoConfigsBuffered() instead of OnConfigsExecuted() to
 * properly update convars before methods that run on config execution are called.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define VERSION                      "1.0.2"

#define PATH_PREFIX_ACTUAL           "cfg/"
#define PATH_PREFIX_VISIBLE          "mapconfig/"
#define PATH_PREFIX_VISIBLE_GENERAL  "mapconfig/"
#define PATH_PREFIX_VISIBLE_GAMETYPE "mapconfig/gametype/"
#define PATH_PREFIX_VISIBLE_MAP      "mapconfig/maps/"

#define PATH_MAPCONFIG_DIR              "mapconfig"
#define PATH_MAPCONFIG_DIR_SLASH        "mapconfig/"

#define TYPE_GENERAL                    0
#define TYPE_MAP                        1
#define TYPE_GAMETYPE                   2

public Plugin:myinfo = {
	name        = "Extended mapconfig package",
	author      = "Milo, nosoop",
	description = "Allows you to use seperate config files for each gametype and map.",
	version     = VERSION,
	url         = "http://sourcemod.corks.nl/"
};

public OnPluginStart() {
	CreateConVar("emc_version", VERSION, "Current version of the extended mapconfig plugin", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	createConfigFiles();
}

public OnAutoConfigsBuffered() {
    decl String:sMapName[128];
    GetCurrentMap(sMapName, sizeof(sMapName));
    
    ExecuteGlobalConfig();
    ExecuteGameTypeConfig(sMapName);
    ExecuteMapSpecificConfig(sMapName);
}

ExecuteGlobalConfig() {
    ExecuteConfig("%s/%s.cfg", PATH_MAPCONFIG_DIR, "all");
}

ExecuteGameTypeConfig(const String:sMapName[]) {
    decl String:sMapDir[PLATFORM_MAX_PATH], String:sGamePrefix[16];
    Format(sMapDir, sizeof(sMapDir), "%s/gametype", PATH_MAPCONFIG_DIR);
    
    if (SplitString(sMapName, "_", sGamePrefix, sizeof(sGamePrefix)) != -1) {
        ExecuteConfig("%s/%s.cfg", sMapDir, sGamePrefix);
        
        if (StrEqual(sGamePrefix, "cp")) {
            ExecuteExtendedCPConfig();
        }
    }
}

ExecuteExtendedCPConfig() {
    // Source:
    // https://forums.alliedmods.net/showthread.php?p=913024
    decl String:sMapDir[PLATFORM_MAX_PATH];
    Format(sMapDir, sizeof(sMapDir), "%s/gametype", PATH_MAPCONFIG_DIR);

    new iTeam, iEnt = -1;
    while ((iEnt = FindEntityByClassname(iEnt, "team_control_point")) != -1) {
        iTeam = GetEntProp(iEnt, Prop_Send, "m_iTeamNum");
        // If there is a blu CP or a neutral CP, then it's not an attack/defend map
        if (iTeam != 2) {
            ExecuteConfig("%s/cp_push.cfg", sMapDir);
            return;
        }
    }
    ExecuteConfig("%s/cp_ad.cfg", sMapDir);
}

ExecuteMapSpecificConfig(const String:sMapName[]) {
    ExecuteConfig("%s/maps/%s.cfg", PATH_MAPCONFIG_DIR, sMapName);
}

ExecuteConfig(const String:sConfigFormat[], any:...) {
    decl String:sConfigFullPath[PLATFORM_MAX_PATH], String:sConfigPath[PLATFORM_MAX_PATH];
    VFormat(sConfigPath, sizeof(sConfigPath), sConfigFormat, 2);
    Format(sConfigFullPath, sizeof(sConfigFullPath), "cfg/%s", sConfigPath);
    
    if (FileExists(sConfigFullPath, true)) {
        PrintToServer("[emc] Executing config file %s ...", sConfigPath);
        ServerCommand("exec %s", sConfigPath);
    }
}

createConfigDir(const String:filename[], const String:prefix[]="") {
	new String:dirname[PLATFORM_MAX_PATH];
	Format(dirname, sizeof(dirname), "%s%s", prefix, filename);
	CreateDirectory(
		dirname,  
		FPERM_U_READ + FPERM_U_WRITE + FPERM_U_EXEC + 
		FPERM_G_READ + FPERM_G_WRITE + FPERM_G_EXEC + 
		FPERM_O_READ + FPERM_O_WRITE + FPERM_O_EXEC
	);
}

GenerateGameTypeConfig(const String:sGamePrefix[], const String:sGameDescription[]) {
    new Handle:hFile = INVALID_HANDLE;
    decl String:sConfigPath[PLATFORM_MAX_PATH];
    
    Format(sConfigPath, sizeof(sConfigPath), "cfg/%s/gametype/%s.cfg", PATH_MAPCONFIG_DIR, sGamePrefix);
    
    if (FileExists(sConfigPath)) {
        return;
    }
	
    hFile = OpenFile(sConfigPath, "w+");
    if (hFile != INVALID_HANDLE) {
        WriteFileLine(hFile, "// Configuration for %s", sGameDescription);
        CloseHandle(hFile);
    }
}

createConfigFiles() {
	new String:game[64];
	// Fetch the current game/mod
	GetGameFolderName(game, sizeof(game));
	// Create the directory structure (if it doesnt exist already)
	createConfigDir(PATH_PREFIX_VISIBLE,           PATH_PREFIX_ACTUAL);
	createConfigDir(PATH_PREFIX_VISIBLE_GENERAL,   PATH_PREFIX_ACTUAL);
	createConfigDir(PATH_PREFIX_VISIBLE_GAMETYPE,  PATH_PREFIX_ACTUAL);
	createConfigDir(PATH_PREFIX_VISIBLE_MAP,       PATH_PREFIX_ACTUAL);
	// Create general config
	createConfigFile("all",     TYPE_GENERAL,  "All maps");
	// For Team Fortress 2
	if (strcmp(game, "tf", false) == 0) {
        GenerateGameTypeConfig("cp", "Control-point maps");
        GenerateGameTypeConfig("cp_push", "Control-point maps (Push-style)");
        GenerateGameTypeConfig("cp_ad", "Control-point maps (Attack / Defend)");
        GenerateGameTypeConfig("ctf", "Capture-the-Flag maps");
        GenerateGameTypeConfig("pl", "Payload maps");
        GenerateGameTypeConfig("arena", "Arena-style maps");
	} else if (strcmp(game, "cstrike", false) == 0) {
        // For Counter-strike and Counter-strike:Source
		GenerateGameTypeConfig("cs", "Hostage maps");
		GenerateGameTypeConfig("de", "Defuse maps");
		GenerateGameTypeConfig("as", "Assasination maps");
		GenerateGameTypeConfig("es", "Escape maps");
	}
    
    // Removed automatic map config generation.
}

createConfigFile(const String:filename[], type=TYPE_MAP, const String:label[]="") {
    decl String:configFilename[PLATFORM_MAX_PATH];
    new Handle:fileHandle = INVALID_HANDLE;
    
    Format(
        configFilename, sizeof(configFilename), "%s%s%s.cfg", PATH_PREFIX_ACTUAL, (
        type == TYPE_GENERAL ? PATH_PREFIX_VISIBLE_GENERAL : (type == TYPE_GAMETYPE ? PATH_PREFIX_VISIBLE_GAMETYPE : PATH_PREFIX_VISIBLE_MAP)
        ), filename
    );
    
    // Check if config exists
    if (FileExists(configFilename))
        return;
    
    // If it doesnt, create it
    fileHandle = OpenFile(configFilename, "w+");
    
    if (fileHandle != INVALID_HANDLE) {
        WriteFileLine(fileHandle, "// Configfile for: %s", (strlen(label) > 0) ? label : configFilename);
        CloseHandle(fileHandle);
    }
}