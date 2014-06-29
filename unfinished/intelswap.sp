#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Global definitions
#define PLUGIN_VERSION "1.0.0"
#define MAX_FILE_LEN 80

// Cvar handler and related thing.
new bool:bIntelSwapEnabled = false;
new Handle:g_enable = INVALID_HANDLE;

// Plugin information
public Plugin:myinfo =
{
    name = "[TF2] Intel Swap",
    author = "nosoop",
    description = "Mail the intelligence to the enemy base. ... Don't ask.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
};

// Plugin started
public OnPluginStart() {
    // Check game.
    decl String:game[32];
    GetGameFolderName(game, sizeof(game));
    if(!(StrEqual(game, "tf"))) {
        SetFailState("This plugin is only for TF2, not %s.", game);
    }
    
    g_enable = CreateConVar("sm_intelswap", "1", "Toggles intel team swapping.", FCVAR_PLUGIN);
    HookConVarChange(g_enable, OnConVarChanged_Enable);
    bIntelSwapEnabled = GetConVarBool(g_enable);
}

public OnMapStart() {
    if (bIntelSwapEnabled) {
        new entIndex = -2;
        
        while ((entIndex = FindEntityByClassname(entIndex + 1, "item_teamflag")) != -1) {
            new iTeamNum = GetEntProp(entIndex, Prop_Send, "m_iTeamNum");
            
            if (iTeamNum == 3) {
                SetEntProp(entIndex, Prop_Send, "m_iTeamNum", 2);
                //DispatchKeyValue(entIndex, "TeamNum", "2");
            } else if (iTeamNum == 2) {
                SetEntProp(entIndex, Prop_Send, "m_iTeamNum", 3);
                //DispatchKeyValue(entIndex, "TeamNum", "3");
            }
        }
        
        entIndex = -2;
        while ((entIndex = FindEntityByClassname(entIndex + 1, "func_capturezone")) != -1) {
            new iTeamNum = GetEntProp(entIndex, Prop_Send, "m_iTeamNum");
            
            if (iTeamNum == 3) {
                SetEntProp(entIndex, Prop_Send, "m_iTeamNum", 2);
                //DispatchKeyValue(entIndex, "TeamNum", "2");
            } else if (iTeamNum == 2) {
                SetEntProp(entIndex, Prop_Send, "m_iTeamNum", 3);
                //DispatchKeyValue(entIndex, "TeamNum", "3");
            }
        }
    }
}

public OnConVarChanged_Enable(Handle:convar, const String:oldValue[], const String:newValue[]) {
    bIntelSwapEnabled = GetConVarBool(g_enable);
}
