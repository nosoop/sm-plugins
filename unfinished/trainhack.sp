#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Global definitions
#define PLUGIN_VERSION "1.0.0"
#define MAX_FILE_LEN 80

// Cvar handler and related thing.
new bool:bTrainModEnabled = false;
new Handle:g_enable = INVALID_HANDLE;

// Plugin information
public Plugin:myinfo =
{
    name = "[TF2] Train Speed",
    author = "nosoop",
    description = "Quick hack to try and change cart speed.",
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
    
    g_enable = CreateConVar("sm_train_modifyspeed", "1", "Toggles train speed modification.", FCVAR_PLUGIN);
    HookConVarChange(g_enable, OnConVarChanged_Enable);
    bTrainModEnabled = GetConVarBool(g_enable);
}

public OnMapStart() {
    if (bTrainModEnabled) {
        new entIndex = -2;
        while ((entIndex = FindEntityByClassname(entIndex + 1, "func_tracktrain")) != -1) {
            new m_maxSpeed = GetEntProp(entIndex, Prop_Data, "m_maxSpeed");
            
            LogMessage("Max speed of train: %f.", m_maxSpeed);
        }
    }
}

public OnConVarChanged_Enable(Handle:convar, const String:oldValue[], const String:newValue[]) {
    bTrainModEnabled = GetConVarBool(g_enable);
}
