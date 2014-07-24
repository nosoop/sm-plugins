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

#define PLUGIN_VERSION          "0.0.6"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Propify! Ghost Fix",
    author = "nosoop",
    description = "Fixes glow effect remaining on players that use the ghost model.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new bool:g_bGhostFixRequired;

new String:g_saGhostModels[][] = {
    "models/props_halloween/ghost_no_hat.mdl",
    "models/props_halloween/ghost.mdl"
};

public OnPluginStart() {
    CheckForGhostModel();
}

public OnPropListLoaded() {
    CheckForGhostModel();
}

// Checks to see if the ghost model is in the current prop list.
CheckForGhostModel() {
    new Handle:hModelPaths = Propify_GetModelPathsArray();
    
    g_bGhostFixRequired = false;
    for (new i = 0; i < sizeof(g_saGhostModels); i++) {
        g_bGhostFixRequired = g_bGhostFixRequired || FindStringInArray(hModelPaths, g_saGhostModels[i]) > -1;
    }
    CloseHandle(hModelPaths);
}

// TODO Add checks on plugin reload and properly close handles?

public Propify_OnPropified(client, propIndex) {
    // None of the props are ghost props, so we don't need to process it.
    if (!g_bGhostFixRequired) {
        return;
    }

    // Check if we are currently a ghost.
    new bool:bIsGhostNow;
    if (propIndex < 0) {
        // We aren't propped at all.
        bIsGhostNow = false;
    } else {
        // Declare a string for the model path.
        new String:sModelPath[PLATFORM_MAX_PATH];
        
        new Handle:hModelPaths = Propify_GetModelPathsArray();
        GetArrayString(hModelPaths, propIndex, sModelPath, sizeof(sModelPath));
        
        // We are a ghost if the model path contains one of the strings mentioned above.
        for (new i = 0; i < sizeof(g_saGhostModels); i++) {
            bIsGhostNow = bIsGhostNow || StrEqual(sModelPath, g_saGhostModels[i]);
        }
        
        CloseHandle(hModelPaths);
    }
    
    // If we aren't a ghost now, kill off the glow particle effect.
    // We shouldn't call this if the prop is currently a ghost, so we're leaving it as a separate plugin.
    if (!bIsGhostNow) {
        // Fix sourced from the Ghost Mode Redux plugin:
        // https://forums.alliedmods.net/showthread.php?p=1883875
        SetVariantString("ParticleEffectStop");
        AcceptEntityInput(client, "DispatchEffect");
    }
}
