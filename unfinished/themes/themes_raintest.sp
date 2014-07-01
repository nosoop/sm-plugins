/**
 * vim: set ts=4 :
 * =============================================================================
 * Themes by J-Factor
 * Dynamically change the theme of maps! Enjoy a dark night, sweeping storm or a
 * frosty blizzard without being forced to download another map. Modifiable
 * attributes include the skybox, lighting, fog, particles, soundscapes and
 * color correction.
 * 
 * Credits:
 *			CrimsonGT				Environmental Tools plugin
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
 
/* PREPROCESSOR ***************************************************************/
#pragma semicolon 1

/* INCLUDES *******************************************************************/
#include <sourcemod>
#include <sdktools>

/* CONSTANTS ******************************************************************/

// Plugin ----------------------------------------------------------------------
#define PLUGIN_NAME		"Themes (Rain test)"
#define PLUGIN_AUTHOR	"J-Factor, nosoop"
#define PLUGIN_DESC		"Attempt to precache rain for theming."
#define PLUGIN_VERSION	"0.8"
#define PLUGIN_URL		"http://j-factor.com/"

// Debug -----------------------------------------------------------------------
// #define DEBUG		1 

// General ---------------------------------------------------------------------
#define MAX_STAGES		8  // Maximum number of stages in a given map
#define MAX_THEMES		32 // Maximum number of themes in a given map

#define TEAM_RED		2
#define TEAM_BLU		3

#define STYLE_RANDOM	0
#define STYLE_TIME		1

/* VARIABLES ******************************************************************/

// Convars ---------------------------------------------------------------------
new Handle:cvPluginEnable  = INVALID_HANDLE;
new Handle:cvNextTheme	   = INVALID_HANDLE;
new Handle:cvAnnounce	   = INVALID_HANDLE;
new Handle:cvParticles     = INVALID_HANDLE;

// Plugin ----------------------------------------------------------------------
new bool:pluginEnabled = false;
new Handle:pluginTimer = INVALID_HANDLE;

// Key Values ------------------------------------------------------------------
new Handle:kvMaps = INVALID_HANDLE;
new Handle:kvThemes = INVALID_HANDLE;
new Handle:kvThemeSets = INVALID_HANDLE;

// General ---------------------------------------------------------------------
new currentStage = 0; // The current stage of the map
new numStages = 0;    // The number of stages defined for the theme

new Handle:windTimer = INVALID_HANDLE;

// Map Attributes --------------------------------------------------------------
new String:map[64];

// Theme
new String:mapTheme[32];
new String:mapTag[32];

// Particles
new String:mapParticle[64];
new Float:mapParticleHeight;


// Map Region
new bool:mapEstimateRegion;
new Float:mapX1[MAX_STAGES], Float:mapX2[MAX_STAGES],
	Float:mapY1[MAX_STAGES], Float:mapY2[MAX_STAGES],
	Float:mapZ[MAX_STAGES];
	
	
/* PLUGIN *********************************************************************/
public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

/* METHODS ********************************************************************/

/* OnPluginStart()
**
** When the plugin is loaded.
** -------------------------------------------------------------------------- */
public OnPluginStart()
{
	// Confirm this is TF2
	decl String:strModName[32]; GetGameFolderName(strModName, sizeof(strModName));
	if (!StrEqual(strModName, "tf")) SetFailState("This plugin is TF2 only.");

	// Convars
	CreateConVar("sm_themes_version", PLUGIN_VERSION, "Themes version", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvAnnounce =     CreateConVar("sm_themes_announce", "1", "Whether or not to announce the current theme", FCVAR_PLUGIN);
	cvParticles =    CreateConVar("sm_themes_particles", "1", "Enables or disables custom particles for themes", FCVAR_PLUGIN);

	// Configuration
	kvMaps = CreateKeyValues("Maps");
	
	// Initialize
	Initialize();
	
    UpdateDownloadsTable();
}

/* Event_EnableChange()
**
** When the plugin is enabled/disabled.
** -------------------------------------------------------------------------- */
public Event_EnableChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	Initialize();
}

/* Initialize()
**
** Initializes the plugin.
** -------------------------------------------------------------------------- */
public Initialize()
{
	if (!pluginEnabled) {
		// Enable!
		HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("teamplay_round_win", Event_RoundEnd);
		HookEvent("teamplay_round_stalemate", Event_RoundEnd);
	
		pluginEnabled = true;
		
	} else if (!pluginEnabled) {
		// Disable!
		UnhookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", Event_RoundEnd);
		UnhookEvent("teamplay_round_stalemate", Event_RoundEnd);
		
		KillTimer(pluginTimer);
		KillTimer(windTimer);
		pluginEnabled = false;
		
	}
}

/* OnMapStart()
**
** When the a map starts.
** -------------------------------------------------------------------------- */
public OnMapStart()
{
	if (pluginEnabled) {
		// Initializes the configuration
		InitConfig();

        // Updates the downloads table
        UpdateDownloadsTable();
        
        // Log the theme values
        LogTheme();
        
        // Applys the loaded configuration for the map
        ApplyConfigMap();
        
        // Applys the loaded configuration for the current round
        ApplyConfigRound();
	}
}

/* InitConfig()
**
** Initializes the configuration, resetting the previous map attributes.
** -------------------------------------------------------------------------- */
InitConfig()
{
	// Reset the map attributes
	map = "";
	
	mapTheme = "Default";
	mapTag = "{olive}";
	
	// Region
	numStages = 0;
	mapEstimateRegion = true;
	
	for (new i = 0; i < MAX_STAGES; i++) {
		mapX1[i] = 0.0;
		mapX2[i] = 0.0;
		mapY1[i] = 0.0;
		mapY2[i] = 0.0;
		mapZ[i] = 1024.0;
	}
}

/* UpdateDownloadsTable()
**
** Updates the downloads table.
** -------------------------------------------------------------------------- */
UpdateDownloadsTable()
{
	decl String:filename[96];
	
	// Handle Particles
    HandleParticleFiles();
}

CacheParticleFile() {
    //
}

/* HandleParticleFiles()
**
** Handles custom particle files.
** -------------------------------------------------------------------------- */
HandleParticleFiles()
{
	decl String:file[96];
	
	Format(file, sizeof(file), "particles/themes_collidingrain.pcf");
	
    AddFileToDownloadsTable(file);
    LogMessage("Rain particles queued for download.");
    
    PrecacheGeneric("particles/themes_collidingrain.pcf", true);
    PrecacheParticleSystem("env_rain_001_collision");
    PrecacheParticleSystem("themes_collidingrain");
    
    Format(file, sizeof(file), "particles/water.pcf");
	
    AddFileToDownloadsTable(file);
    LogMessage("Default hackish rain particles queued for download.");
    
    PrecacheGeneric("particles/water.pcf", true);
}

stock PrecacheParticleSystem( const String:p_strEffectName[] )
{
	static s_numStringTable = INVALID_STRING_TABLE;

	if ( s_numStringTable == INVALID_STRING_TABLE  )
		s_numStringTable = FindStringTable( "ParticleEffectNames" );

	AddToStringTable( s_numStringTable, p_strEffectName );
}

/* ApplyConfigMap()
**
** Applys the loaded configuration to the current map. Not all attributes can be
** applied here. Some must be reapplied every round start.
** -------------------------------------------------------------------------- */
ApplyConfigMap()
{	
	// Estimate Map Region
	if (mapEstimateRegion) {
		EstimateMapRegion();
	}
}

/* ApplyConfigRound()
**
** Applys the loaded configuration to the current map. Not all attributes can be
** applied here. Some must be reapplied every round start.
** -------------------------------------------------------------------------- */
ApplyConfigRound()
{	// Apply Particles
	if (GetConVarBool(cvParticles)) {
		CreateParticles();
	}
}

/* CreateParticles()
**
** Creates particles around the map.
** -------------------------------------------------------------------------- */
CreateParticles()
{
    // Remove old particles
    new ent = -1;
    new num = 0;
    
    while ((ent = FindEntityByClassname(ent, "info_particle_system")) != -1) {
        if (IsValidEntity(ent)) {
            decl String:name[32];
            
            GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name));
            
            if (StrContains(name, "themes_particle") != -1) {
                AcceptEntityInput(ent, "Kill");
            }
        }
    }
    
    new x, y, nx, ny, Float:w, Float:h, Float:ox, Float:oy;
    
    w = mapX2[currentStage] - mapX1[currentStage];
    h = mapY2[currentStage] - mapY1[currentStage];
    
    nx = RoundToFloor(w/1024.0) + 1;
    ny = RoundToFloor(h/1024.0) + 1;
    
    ox = (((RoundToFloor(w/1024.0) + 1) * 1024.0) - w)/2;
    oy = (((RoundToFloor(h/1024.0) + 1) * 1024.0) - h)/2;
    
    for (x = 0; x < nx; x++) {
        for (y = 0; y < ny; y++) {
            new particle = CreateEntityByName("info_particle_system");

            // Check if it was created correctly
            if (IsValidEdict(particle)) {
                decl Float:pos[3];
                
                pos[0] = mapX1[currentStage] + x*1024.0 + 512.0 - ox;
                pos[1] = mapY1[currentStage] + y*1024.0 + 512.0 - oy;
                pos[2] = mapParticleHeight + mapZ[currentStage];
                
                // Teleport, set up
                TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
                DispatchKeyValue(particle, "effect_name", "env_rain_001");
                DispatchKeyValue(particle, "targetname", "themes_particle");
                
                // Patch in weather flag
                SetEntProp(particle, Prop_Data, "m_bWeatherEffect", 1);
                DispatchKeyValue(particle, "flag_as_weather", "1");
                
                // Patch in solid? flag
                //SetEntProp(particle, Prop_Data, "m_nSolidType", 1);
                DispatchKeyValue(particle, "solid", "1");
                
                // Spawn and start
                DispatchSpawn(particle);
                ActivateEntity(particle);
                AcceptEntityInput(particle, "Start");
            }
            
            num++;
            
            if (num > 64) {
                LogMessage("Error: Too many particles!");
                return;
            }
        }
    }
    
    LogMessage("Created %i particles of type %s", num, mapParticle);
}

/* EstimateMapRegion()
**
** Estimates the region of the map by finding the minimum and maximum position
** of entities. Only used for particles.
** -------------------------------------------------------------------------- */
EstimateMapRegion()
{
    new maxEnts = GetMaxEntities();
    
    for (new i = MaxClients + 1; i <= maxEnts; i++) {
        if (!IsValidEntity(i)) continue;
        
        decl String:name[32];
        GetEntityNetClass(i, name, 32);
        
        if (FindSendPropOffs(name, "m_vecOrigin") != -1) {
            decl Float:pos[3];
            GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos);
            
            if (pos[0] < mapX1[0]) {
                mapX1[0] = pos[0];
            }
            if (pos[0] > mapX2[0]) {
                mapX2[0] = pos[0];
            }
            
            if (pos[1] < mapY1[0]) {
                mapY1[0] = pos[1];
            }
            if (pos[1] > mapY2[0]) {
                mapY2[0] = pos[1];
            }
        }
    }
    
    for (new i = 1; i < MAX_STAGES; i++) {
        mapX1[i] = mapX1[0];
        mapX2[i] = mapX2[0];
        mapY1[i] = mapY1[0];
        mapY2[i] = mapY2[0];
    }
    
    LogMessage("Map region estimated: (%f, %f) to (%f, %f) [%f x %f]", mapX1[0], mapY1[0], mapX2[0], mapY2[0], mapX2[0] - mapX1[0], mapY2[0] - mapY1[0]);
}

/* LogTheme()
**
** Prints all of the current theme's attributes.
** -------------------------------------------------------------------------- */
LogTheme()
{
	LogMessage("Loaded theme: %s", mapTheme);
}

/* Event_RoundEnd()
**
** When a round ends.
** -------------------------------------------------------------------------- */
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (pluginEnabled) {
		// Check if a full round has completed
		if (GetEventInt(event, "full_round")) {
			currentStage = 0;
		} else if (currentStage < numStages - 1) {
			currentStage++;
		}
	}
	
	return Plugin_Continue;
}

/* Event_RoundStart()
**
** When a round starts.
** -------------------------------------------------------------------------- */
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (pluginEnabled) {
		// Need to wait at least 0.2 before bloom is able to be set
		// Increased delay as possible fix for CC and particles
		CreateTimer(2.0, Timer_RoundStart);
	}
	
	return Plugin_Continue;
}

/* Timer_RoundStart()
**
** Timer for round start.
** ------------------------------------------------------------------------- */
public Action:Timer_RoundStart(Handle:timer, any:data)
{
	ApplyConfigRound();
}