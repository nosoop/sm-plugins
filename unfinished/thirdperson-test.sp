#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

#define PLUGIN_VERSION          "0.0.1"     // Plugin version.

new bool:g_bIsThirdPerson[MAXPLAYERS+1];

new Handle:g_hCheats = INVALID_HANDLE,
    Handle:g_hMedieval = INVALID_HANDLE, Handle:g_hMedievalThirdPerson = INVALID_HANDLE;

public Plugin:myinfo = {
    name = "[TF2] Third-person?",
    author = "nosoop",
    description = "Testing for various third-person modes.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
}

public OnPluginStart() {
    CheckGame();
    
    RegConsoleCmd("sm_third", Command_ThirdPerson, "Toggles various methods of third-person mode.");
    
    g_hCheats = FindConVar("sv_cheats");
    g_hMedieval = FindConVar("tf_medieval");
    g_hMedievalThirdPerson = FindConVar("tf_medieval_thirdperson");
    
    HookEvent("teamplay_round_win", Hook_PostRoundWin, EventHookMode_Pre);
}

public Hook_PostRoundWin(Handle:event, const String:name[], bool:dontBroadcast) {
    // Respawn dead players during humiliation for the purpose of testing third-person on them.
    for (new x = 1; x <= MaxClients; x++) {
        if (IsClientInGame(x) && !IsPlayerAlive(x)) {
            TF2_RespawnPlayer(x);
            
            new hRagdoll = GetEntPropEnt(x, Prop_Send, "m_hRagdoll");
            if (IsValidEntity(hRagdoll)) {
                AcceptEntityInput(hRagdoll, "kill");
            }
        }
    }
}

public OnClientConnected(client) {
    g_bIsThirdPerson[client] = false;
}

public Action:Command_ThirdPerson(client, args) {
    new iThirdPersonType = -1;
    if (args > 0) {
        new String:sThirdPersonType[10];
        GetCmdArg(1, sThirdPersonType, sizeof(sThirdPersonType));
        iThirdPersonType = StringToInt(sThirdPersonType);
    }
    
    new bool:bThirdPerson = !g_bIsThirdPerson[client];
    
    // Netprop: CTFPlayer (type DT_TFPlayer)
    // Datamap: player ?
    
    switch (iThirdPersonType) {
        // Method 1: Taunt Camera
        // Works, but only before humiliation.
        case 1: {
            SetVariantInt(bThirdPerson ? 1 : 0);
            AcceptEntityInput(client, "SetForcedTauntCam");
        }
        // Method 2: Observer Target
        // Stuttery and lag-compensated as fuck.  Though it works otherwise.
        case 2: {
            // SetEntProp(client, Prop_Data, "m_bLagCompensation", bThirdPerson ? 0 : 1);
            // SetEntProp(client, Prop_Data, "m_bForcedObserverMode", bThirdPerson ? 1 : 0, 1);
            // SetEntProp(client, Prop_Data, "m_CollisionGroup", bThirdPerson ? 2 : 0);
            SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bThirdPerson ? -1 : client);
            // 0 is first-person, 1 is out-of-person, 2 shows killer, 3 shows map?
            SetEntProp(client, Prop_Send, "m_iObserverMode", bThirdPerson ? 1 : 0);
            SetEntProp(client, Prop_Send, "m_iFOV", bThirdPerson ? 100 : 90);
        }
        // Method 3: Cheats
        // Does not work because disabling cheats forces a return to first-person.
        // Keeping cheats enabled also opens up another can of worms.
        case 3: {
            SendConVarValue(client, g_hCheats, "1");
            ClientCommand(client, "%sperson", bThirdPerson ? "third" : "first");
            SendConVarValue(client, g_hCheats, "0");
        }
        // Method 4: Medieval mode flag.
        // Fails since FCVAR_SERVER_CAN_EXECUTE prevented server running command: tf_medieval_thirdperson
        // Also, medieval mode is set on next map notification.
        case 4: {
            SendConVarValue(client, g_hMedieval, "1");
            ClientCommand(client, "tf_medieval_thirdperson %s", bThirdPerson ? "1" : "0");
            // SendConVarValue(client, g_hMedievalThirdPerson, bThirdPerson ? "1" : "0");
            SendConVarValue(client, g_hMedieval, "0");
        }
        // Method 5: DISREGARD INPUTS, PUSH RAW DATA
        // Same issue as method 1, apparently.
        case 5: {
            SetEntProp(client, Prop_Send, "m_nForceTauntCam", bThirdPerson ? 2 : 0, 2);
            SetEntProp(client, Prop_Send, "m_bAllowMoveDuringTaunt", bThirdPerson ? 1 : 0);
        }
        default: {
        }
    }
    
    g_bIsThirdPerson[client] = bThirdPerson;
    return Plugin_Handled;
}

CheckGame() {
    new String:strGame[10];
    GetGameFolderName(strGame, sizeof(strGame));
    
    if(!StrEqual(strGame, "tf")) {
        SetFailState("[thirdperson] Detected game other than [TF2], plugin disabled.");
    }
}