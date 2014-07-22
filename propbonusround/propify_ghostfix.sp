/**
 * [TF2] Propify! Ghost Fix
 * Author(s): nosoop
 * File: propify_ghostfix.sp
 * Description: Fixes the glow effect from ghost props remaining on players after they are not ghosts.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <propify>

#define PLUGIN_VERSION          "0.0.1"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Propify! Ghost Fix",
    author = "nosoop",
    description = "Fixes glow remaining on players that use the ghost model.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new bool:g_bIsGhost[MAXPLAYERS+1];
new Handle:g_hModelPaths = INVALID_HANDLE;

new String:g_saGhostModels[][] = {
    "ghost_no_hat.mdl",
    "ghost.mdl"
};

public OnPluginStart() {
    g_hModelPaths = GetModelPathsArray();
}

public OnPropListLoaded() {
    g_hModelPaths = GetModelPathsArray();
}

// TODO Add checks on plugin reload and properly close handles?

public OnPropified(client, propIndex) {
    // Check if we are currently a ghost.
    new bool:bIsGhostNow;
    if (propIndex < 0) {
        // We aren't propped at all.
        bIsGhostNow = false;
    } else {
        // Declare a string for the model path.
        new String:sModelPath[PLATFORM_MAX_PATH];
        GetArrayString(g_hModelPaths, propIndex, sModelPath, sizeof(sModelPath));
        
        // We are a ghost if the model path contains one of the strings mentioned above.
        for (new i = 0; i < sizeof(g_saGhostModels); i++) {
            bIsGhostNow = bIsGhostNow || StrContains(sModelPath, g_saGhostModels[i]) != -1;
        }
    }
    
    // If we were a ghost and we aren't now, kill off the glow particle effect.
    if (!bIsGhostNow && g_bIsGhost[client]) {
        // Fix sourced from the Ghost Mode Redux plugin:
        // https://forums.alliedmods.net/showthread.php?p=1883875
        SetVariantString("ParticleEffectStop");
        AcceptEntityInput(client, "DispatchEffect");
    }
    
    // Update spooky status.
    g_bIsGhost[client] = bIsGhostNow;
}
