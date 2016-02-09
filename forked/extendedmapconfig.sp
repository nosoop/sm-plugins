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
#include <tf2>

#define VERSION                      "1.3.0"

public Plugin:myinfo = {
	name        = "Extended Map Configs",
	author      = "Milo, nosoop",
	description = "Allows you to use seperate config files for each gametype and map.",
	version     = VERSION,
	url         = "http://sourcemod.corks.nl/"
};

#define GAME_CONFIG_PATH                "cfg"

#define MAPPATH_ROOT                    "mapconfig"
#define MAPPATH_SUBDIR_GAMETYPE         "gametype"
#define MAPPATH_SUBDIR_MAPS             "maps"
#define MAPPATH_SUBDIR_WORKSHOP         "workshop"

enum ConfigPathType {
    ConfigPath_Root = 0,
    ConfigPath_GameType,
    ConfigPath_Maps,
	ConfigPath_Workshop
};

public OnPluginStart() {
	CreateConVar("emc_version", VERSION, "Current version of the extended mapconfig plugin", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    // Attempts to set up EMC with stock configs.
	SetupEMC();
}

public OnAutoConfigsBuffered() {
    decl String:sMapName[128];
    GetCurrentMap(sMapName, sizeof(sMapName));
	FindMap(sMapName, sMapName, sizeof(sMapName));
	
	new workshop = GetWorkshopID(sMapName);
	
    TrimWorkshopMapName(sMapName, sizeof(sMapName));
    
    ExecuteGlobalConfig();
    ExecuteGameTypeConfig(sMapName);
	ExecuteMapPrefixConfigs(sMapName);
	ExecuteMapSpecificConfig(sMapName);
	
	if (workshop > 0) {
		ExecuteWorkshopConfig(workshop);
	}
}

ExecuteGlobalConfig() {
    ExecuteConfig(ConfigPath_Root, "all.cfg");
}

ExecuteGameTypeConfig(const String:sMapName[]) {
    decl String:sGamePrefix[16];
    
    if (SplitString(sMapName, "_", sGamePrefix, sizeof(sGamePrefix)) != -1) {
        ExecuteConfig(ConfigPath_GameType, "%s.cfg", sGamePrefix);
        
        if (StrEqual(sGamePrefix, "cp")) {
            ExecuteExtendedCPConfig();
        }
    }
}

/**
 * Special case to differentiate between different types of Control Point maps in TF2.
 * Source: https://forums.alliedmods.net/showthread.php?p=913024
 */
ExecuteExtendedCPConfig() {
    new iControlPoint = -1;
    while ((iControlPoint = FindEntityByClassname(iControlPoint, "team_control_point")) != -1) {
        if ((TFTeam:GetEntProp(iControlPoint, Prop_Send, "m_iTeamNum")) != TFTeam_Red) {
            // If there is a BLU CP or a neutral CP, then it's not an attack / defend map.
            ExecuteConfig(ConfigPath_GameType, "cp_push.cfg");
            return;
        }
    }
    ExecuteConfig(ConfigPath_GameType, "cp_ad.cfg");
}

ExecuteMapSpecificConfig(const String:sMapName[]) {
    ExecuteConfig(ConfigPath_Maps, "%s.cfg", sMapName);
}

ExecuteWorkshopConfig(workshopid) {
	ExecuteConfig(ConfigPath_Workshop, "%d.cfg", workshopid);
}

/**
 * Executes configurations for a map file, increasing in specifity.
 * (e.g., pl_pier_.cfg executes before pl_pier_b11_.cfg before pl_pier_b11_fix.cfg)
 */
ExecuteMapPrefixConfigs(const String:sMapName[]) {
    new nMapNamePortions;
    
    // [string][stringlength]
    new String:sMapNamePortions[16][48];
    decl String:sMapNameBuffer[PLATFORM_MAX_PATH];
    nMapNamePortions = ExplodeString(sMapName, "_", sMapNamePortions, sizeof(sMapNamePortions), sizeof(sMapNamePortions[]));
    
    // Underscores are appended?
    for (new i = 0; i < nMapNamePortions; i++) {
        StrCat(sMapNameBuffer, sizeof(sMapNameBuffer), sMapNamePortions[i]);
        if (i < nMapNamePortions - 1) {
            StrCat(sMapNameBuffer, sizeof(sMapNameBuffer), "_");
        }
        
        ExecuteConfig(ConfigPath_Maps, "%s.cfg", sMapNameBuffer);
    }
}

ExecuteConfig(ConfigPathType:type, const String:sConfigFormat[], any:...) {
    decl String:sConfigFullPath[PLATFORM_MAX_PATH], String:sConfigPath[PLATFORM_MAX_PATH];
    
    VFormat(sConfigPath, sizeof(sConfigPath), sConfigFormat, 3);
    BuildConfigPath(type, sConfigPath, sizeof(sConfigPath), sConfigPath);
    
    Format(sConfigFullPath, sizeof(sConfigFullPath), "cfg/%s", sConfigPath);
    
    if (FileExists(sConfigFullPath, true)) {
        PrintToServer("[emc] Executing config file %s ...", sConfigPath);
        ServerCommand("exec %s", sConfigPath);
    } else {
		PrintToServer("[emc] Config file %s does not exist.", sConfigPath);
	}
}

BuildConfigPath(ConfigPathType:type, String:buffer[], maxlength, const String:fmt[]="", any:...) {
    new String:sConfigBase[PLATFORM_MAX_PATH];
    VFormat(sConfigBase, sizeof(sConfigBase), fmt, 5);
    
    strcopy(buffer, maxlength, MAPPATH_ROOT);
    
    // Append mapconfig subdirectories as needed.
    switch (type) {
        case ConfigPath_GameType: {
            StrCat(buffer, maxlength, "/" ... MAPPATH_SUBDIR_GAMETYPE);
        }
        case ConfigPath_Maps: {
            StrCat(buffer, maxlength, "/" ... MAPPATH_SUBDIR_MAPS);
        }
		case ConfigPath_Workshop: {
			StrCat(buffer, maxlength, "/" ... MAPPATH_SUBDIR_WORKSHOP);
		}
    }
    Format(buffer, maxlength, "%s/%s", buffer, sConfigBase);
}

GenerateConfigDirectory(ConfigPathType:type) {
    decl String:sConfigDirectory[PLATFORM_MAX_PATH];
    BuildConfigPath(type, sConfigDirectory, sizeof(sConfigDirectory));
    Format(sConfigDirectory, sizeof(sConfigDirectory), "%s/%s", GAME_CONFIG_PATH, sConfigDirectory);

    if (!DirExists(sConfigDirectory)) {
        PrintToServer("[emc] Created directory file %s", sConfigDirectory);
        CreateDirectory(sConfigDirectory,  
            FPERM_U_READ + FPERM_U_WRITE + FPERM_U_EXEC + 
            FPERM_G_READ + FPERM_G_WRITE + FPERM_G_EXEC + 
            FPERM_O_READ + FPERM_O_WRITE + FPERM_O_EXEC
        );
    }
}

GenerateConfig(ConfigPathType:type, const String:sConfigName[], const String:sDescription[]) {
    new Handle:hFile = INVALID_HANDLE;
    decl String:sConfigPath[PLATFORM_MAX_PATH];
    
    BuildConfigPath(type, sConfigPath, sizeof(sConfigPath), "%s.cfg", sConfigName);
    Format(sConfigPath, sizeof(sConfigPath), "%s/%s", GAME_CONFIG_PATH, sConfigPath);
    
    if (FileExists(sConfigPath)) {
        return;
    }
	
    hFile = OpenFile(sConfigPath, "w+");
    if (hFile != INVALID_HANDLE) {
        PrintToServer("[emc] Created config file %s", sConfigPath);
        WriteFileLine(hFile, "// Configuration for %s", sDescription);
        CloseHandle(hFile);
    }
}

SetupEMC() {
    new String:game[64];
    GetGameFolderName(game, sizeof(game));
    
    GenerateConfigDirectory(ConfigPath_Root);
    GenerateConfigDirectory(ConfigPath_GameType);
    GenerateConfigDirectory(ConfigPath_Maps);
    GenerateConfigDirectory(ConfigPath_Workshop);
	
    GenerateConfig(ConfigPath_Root, "all", "All maps");

    if (strcmp(game, "tf", false) == 0) {
        // For Team Fortress 2
        GenerateConfig(ConfigPath_GameType, "cp", "Control Point maps");
        GenerateConfig(ConfigPath_GameType, "cp_push", "Control Point maps (Push)");
        GenerateConfig(ConfigPath_GameType, "cp_ad", "Control Point maps (Attack / Defend)");
        GenerateConfig(ConfigPath_GameType, "ctf", "Capture the Flag maps");
        GenerateConfig(ConfigPath_GameType, "pl", "Payload maps");
        GenerateConfig(ConfigPath_GameType, "arena", "Arena maps");
	} else if (strcmp(game, "cstrike", false) == 0) {
        // For Counter-strike and Counter-strike:Source
		GenerateConfig(ConfigPath_GameType, "cs", "Hostage maps");
		GenerateConfig(ConfigPath_GameType, "de", "Defuse maps");
		GenerateConfig(ConfigPath_GameType, "as", "Assasination maps");
		GenerateConfig(ConfigPath_GameType, "es", "Escape maps");
	}
}

stock TrimWorkshopMapName(String:map[], size) {
	if (StrContains(map, "workshop/", true) == 0) {
		// Trim off workshop directory
		strcopy(map, size, map[9]);
		
		// Strip off the map ID onwards
		strcopy(map, StrContains(map, ".ugc") + 1, map);
	}
}

stock _:GetWorkshopID(const String:map[]) {
	return StringToInt(map[StrContains(map, ".ugc") + 4]);
}