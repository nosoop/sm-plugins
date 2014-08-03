/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Robot Destruction Modded",
    author = "nosoop",
    description = "Provides functions to set start score and such.",
    version = PLUGIN_VERSION,
    url = "localhost"
}

new Handle:g_hCScoreStartRed = INVALID_HANDLE,      g_nScoreStartRed = 100,     // sm_rdm_redstartscore
    Handle:g_hCScoreStartBlu = INVALID_HANDLE,      g_nScoreStartBlu = 100;     // sm_rdm_blustartscore

public OnPluginStart() {
    // netprops:
    // Member: m_nMaxPoints (offset 1312) (type integer) (bits 32) (Unsigned|VarInt)
    // Member: m_nBlueScore (offset 1316) (type integer) (bits 32) (Unsigned|VarInt)
    // Member: m_nRedScore (offset 1320) (type integer) (bits 32) (Unsigned|VarInt)
    // Member: m_nStolenBlueScore (offset 1324) (type integer) (bits 32) (Unsigned|VarInt)
    // Member: m_nStolenRedScore (offset 1328) (type integer) (bits 32) (Unsigned|VarInt)

    g_hCScoreStartRed = CreateConVar("sm_rdm_redstartscore", "100", "Starting number of cores for RED.", _, true, 0.0);
    HookConVarChange(g_hCScoreStartRed, OnConVarChange);
    
    g_hCScoreStartBlu = CreateConVar("sm_rdm_blustartscore", "100", "Starting number of cores for BLU.", _, true, 0.0);
    HookConVarChange(g_hCScoreStartBlu, OnConVarChange);
    
    HookEvent("teamplay_round_start", Hook_RoundStart);
}

public OnMapStart() {
    // TODO Entity logic for timers.
}

public Hook_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
    new ent = FindEntityByClassname(-1, "tf_logic_robot_destruction");
    if (ent > -1) {
        // TODO Replicate the change locally.
        SetEntProp(ent, Prop_Send, "m_nRedScore", g_nScoreStartRed);
        SetEntProp(ent, Prop_Send, "m_nBlueScore", g_nScoreStartBlu);
        
        /*new entityTimer = FindEntityByClassname(-1, "team_round_timer");
        if (entityTimer > -1) {
            SetVariantInt(1200);
            AcceptEntityInput(entityTimer, "AddTime");
            AcceptEntityInput(entityTimer, "Enable");
        }*/
    }
}

public OnConVarChange(Handle:cvar, const String:oldValue[], const String:newValue[]) {
    if (cvar == g_hCScoreStartRed) {
        g_nScoreStartRed = StringToInt(newValue);
    } else if (cvar == g_hCScoreStartBlu) {
        g_nScoreStartBlu = StringToInt(newValue);
    }
}

