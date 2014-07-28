/**
 * 2spooky.  sospooky
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION          "0.1.0"     // Plugin version.

#define TIME_EYELANDER_MEAN     60.0        // Final: 60.0
#define TIME_EYELANDER_DEV      10.0        // Final: 10.0

#define TIME_UNDERWORLD_MEAN    17.0        // Final: ???
#define TIME_UNDERWORLD_DEV     12.8        // Final: ???

public Plugin:myinfo = {
    name = "[TF2] Dodgeball...?",
    author = "nosoop",
    description = "Description!",
    version = PLUGIN_VERSION,
    url = "localhost"
}

new String:g_sSoundEyelander[15][64], String:g_sSoundUnderworld[30][64];

public OnPluginStart() {
    // Hook round start event to reset fog.
    HookEvent("teamplay_round_start", Hook_PostRoundStart);
    
    // Hook spawn to set blindness.
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public OnMapStart() {
    PrecacheNoises();
    
    ApplySoundscape("Halloween.Inside", "Halloween.Inside");
    
    WelcomeToHell();
    SetDarkness();
    
    CreateTimer(GetRandomFloatDeviation(TIME_EYELANDER_MEAN, TIME_EYELANDER_DEV), Timer_PlayEyelanderNoise);
    CreateTimer(GetRandomFloatDeviation(TIME_UNDERWORLD_MEAN, TIME_UNDERWORLD_DEV), Timer_PlayUnderworldNoise);
    CreateTimer(GetRandomFloatDeviation(90.0, 10.0), Timer_RandomDamage);
}

public Hook_PostRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
    SetDarkness();
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (IsClientInGame(client) && !IsFakeClient(client)) {
        // Apply Skybox Fog Color
        SetEntProp(client, Prop_Send, "m_skybox3d.fog.enable", 1);
        SetEntProp(client, Prop_Send, "m_skybox3d.fog.colorPrimary", 0);
        SetEntProp(client, Prop_Send, "m_skybox3d.fog.colorSecondary", 0);
        
        // Apply Skybox Fog Start
        SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.start", 10.0);
        
        // Apply Skybox Fog End
        SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.end", 20.0);
        
        SetPlayerBlindness(client, 220);
    }
    return Plugin_Continue;
}

SetDarkness() {
    // Fog taken from themes plugin https://forums.alliedmods.net/showthread.php?t=105608
    new ent = FindEntityByClassname(-1, "env_fog_controller");
    
    if (ent == -1) {
        ent = CreateEntityByName("env_fog_controller");
        DispatchSpawn(ent);
    }
    
    if (ent != -1) {
        // Apply Fog Color
        SetVariantColor( { 0, 0, 0, 0 } );
        AcceptEntityInput(ent, "SetColor");
        SetVariantColor( { 0, 0, 0, 0 } );
        AcceptEntityInput(ent, "SetColorSecondary");
        
        // Apply Fog Start
        SetVariantFloat(-10.0);
        AcceptEntityInput(ent, "SetStartDist");
        
        // Apply Fog End
        SetVariantFloat(300.0);
        AcceptEntityInput(ent, "SetEndDist");
        
        // Apply Fog Density
        DispatchKeyValueFloat(ent, "fogmaxdensity", 1.0);
        
        AcceptEntityInput(ent, "TurnOn");
    }
    
    DispatchKeyValue(0, "skyname", "sky_halloween_night_01");
    
    while ((ent = FindEntityByClassname(ent, "env_sun")) != -1) {
        AcceptEntityInput(ent, "Kill");
    }
    
    SetLightStyle(0, "s");
}

SetPlayerBlindness(target, amount) {
    new UserMsg:g_FadeUserMsgId = GetUserMessageId("Fade");
    new targets[2];
    targets[0] = target;
    
    new duration = 1536;
    new holdtime = 1536;
    new flags;
    if (amount == 0) {
        flags = (0x0001 | 0x0010);
    } else {
        flags = (0x0002 | 0x0008);
    }
    
    new color[4] = { 0, 0, 0, 0 };
    color[3] = amount;
    
    new Handle:message = StartMessageEx(g_FadeUserMsgId, targets, 1);
    if (GetUserMessageType() == UM_Protobuf) {
        PbSetInt(message, "duration", duration);
        PbSetInt(message, "hold_time", holdtime);
        PbSetInt(message, "flags", flags);
        PbSetColor(message, "clr", color);
    } else {
        BfWriteShort(message, duration);
        BfWriteShort(message, holdtime);
        BfWriteShort(message, flags);        
        BfWriteByte(message, color[0]);
        BfWriteByte(message, color[1]);
        BfWriteByte(message, color[2]);
        BfWriteByte(message, color[3]);
    }
    
    EndMessage();
}

public Action:Timer_RandomDamage(Handle:data) {
    new client = GetRandomClient();
    
    if (GetRandomFloat() < 0.025) {
        SDKHooks_TakeDamage(client, client, client, 999.0, DMG_CRIT);
    } else {
        SDKHooks_TakeDamage(client, 0, 0, 0.01, DMG_BULLET);
    }
    
    CreateTimer(GetRandomFloatDeviation(30.0, 5.0), Timer_RandomDamage);
}

public WelcomeToHell() {
    new shakeEntity = CreateEntityByName("env_shake");
    DispatchKeyValueFloat(shakeEntity, "amplitude", 15.0);
    DispatchKeyValueFloat(shakeEntity, "frequency", 220.0);
    DispatchKeyValueFloat(shakeEntity, "duration", 5.0);
    DispatchKeyValueFloat(shakeEntity, "radius", -1.0);
    DispatchSpawn(shakeEntity);
    
    AcceptEntityInput(shakeEntity, "StartShake");
    CreateTimer(10.0, Timer_KillShake, shakeEntity);
    
    EmitSoundToAll("misc/halloween/gotohell.wav", _, _, _, _, 0.8);
}

public Action:Timer_KillShake(Handle:data, any:entity) {
    AcceptEntityInput(entity, "kill");
}

PrecacheNoises() {
    // Eyelander noises -- loads 15 Eyelander sounds.
    for (new i = 0; i < 15; i++) {
        decl String:soundName[64];
        Format(soundName, sizeof(soundName), "vo/sword_idle%02d.wav", i+1);
        g_sSoundEyelander[i] = soundName;
        
        PrecacheSound(soundName, true);
    }
    
    // Viaduct Event underworld screams -- loads female screams 01~10 and male screams 03~23 for a total of 30 sounds.
    for (new i = 0; i < 30; i++) {
        decl String:soundName[64];
        Format(soundName, sizeof(soundName), "ambient/halloween/%s_scream_%02d.wav",
                i >= 10 ? "male" : "female",
                i >= 10 ? i+3 - 10 : i+1);
        g_sSoundUnderworld[i] = soundName;
        
        PrecacheSound(soundName, true);
    }
    
    PrecacheSound("misc/halloween/gotohell.wav", true);
}

public Action:Timer_PlayEyelanderNoise(Handle:data) {
    if (GetClientCount(true) > 0) {
        PlayRandomSoundToClient(GetRandomClient(), g_sSoundEyelander, sizeof(g_sSoundEyelander), 0.5, 0.8);
    }
    
    CreateTimer(GetRandomFloatDeviation(TIME_EYELANDER_MEAN, TIME_EYELANDER_DEV), Timer_PlayEyelanderNoise);
}

public Action:Timer_PlayUnderworldNoise(Handle:data) {
    if (GetClientCount(true) > 0 && GetRandomFloat() < 0.8) {
        PlayRandomSoundToClient(GetRandomClient(), g_sSoundUnderworld, sizeof(g_sSoundUnderworld), 0.1, 0.3);
    }

    CreateTimer(GetRandomFloatDeviation(TIME_UNDERWORLD_MEAN, TIME_UNDERWORLD_DEV), Timer_PlayUnderworldNoise);
}

PlayRandomSoundToClient(client, const String:soundFiles[][], nSoundFiles, Float:minVolume, Float:maxVolume) {
    decl String:soundName[PLATFORM_MAX_PATH];
    
    strcopy(soundName, sizeof(soundName), soundFiles[GetRandomInt(0, nSoundFiles - 1)]);
    
    new iSource = SOUND_FROM_PLAYER;
    new Float:fVolume = GetRandomFloat(minVolume, maxVolume);
    
    EmitSoundToClient(client, soundName, iSource, _, _, _, fVolume);
}

ApplySoundscape(String:mapSoundscapeInside[], String:mapSoundscapeOutside[]) {
    // Soundscape code from the Themes plugin.
    new ent = -1, proxy = -1, scape = -1;
    decl Float:org[3];
    decl String:target[32];
    
    // Find all soundscape proxies and determine if they're inside or outside
    while ((ent = FindEntityByClassname(ent, "env_soundscape_proxy")) != -1) {
        proxy = GetEntDataEnt2(ent, FindDataMapOffs(ent, "m_hProxySoundscape"));
        
        if (proxy != -1) {
            GetEntPropString(proxy, Prop_Data, "m_iName", target, sizeof(target));
            
            if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1) ||
                    (StrContains(target, "outside", false) != -1) || (StrContains(target, "outdoor", false) != -1)) {
                // Create new soundscape using loaded attributes
                scape = CreateEntityByName("env_soundscape");

                if (IsValidEntity(scape)) {
                    GetEntPropVector(ent, Prop_Data, "m_vecOrigin", org);
                    TeleportEntity(scape, org, NULL_VECTOR, NULL_VECTOR);
                    
                    DispatchKeyValueFloat(scape, "radius", GetEntDataFloat(ent, FindDataMapOffs(ent, "m_flRadius")));
                    
                    if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1)) {
                        DispatchKeyValue(scape, "soundscape", mapSoundscapeInside);
                        DispatchKeyValue(scape, "targetname", mapSoundscapeInside);
                    } else if ((StrContains(target, "outside", false) != -1) || (StrContains(target, "outdoor", false) != -1)) {
                        DispatchKeyValue(scape, "soundscape", mapSoundscapeOutside);
                        DispatchKeyValue(scape, "targetname", mapSoundscapeOutside);
                    }
                    
                    DispatchSpawn(scape);
                }
            }
        }
        
        AcceptEntityInput(ent, "Kill");
    }
    
    // Do the same to normal soundscapes
    while ((ent = FindEntityByClassname(ent, "env_soundscape")) != -1) {
        GetEntPropString(ent, Prop_Data, "m_iName", target, sizeof(target));
        
        if (!StrEqual(target, mapSoundscapeInside) && !StrEqual(target, mapSoundscapeOutside)) {
            scape = CreateEntityByName("env_soundscape");
        
            if (IsValidEntity(scape)) {
                GetEntPropVector(ent, Prop_Data, "m_vecOrigin", org);
                TeleportEntity(scape, org, NULL_VECTOR, NULL_VECTOR);
                
                DispatchKeyValueFloat(scape, "radius", GetEntDataFloat(ent, FindDataMapOffs(ent, "m_flRadius")));
                
                if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1)) {
                    DispatchKeyValue(scape, "soundscape", mapSoundscapeInside);
                    DispatchKeyValue(scape, "targetname", mapSoundscapeInside);
                } else {
                    DispatchKeyValue(scape, "soundscape", mapSoundscapeOutside);
                    DispatchKeyValue(scape, "targetname", mapSoundscapeOutside);
                }
                
                DispatchSpawn(scape);
            }
        
            AcceptEntityInput(ent, "Kill");
        }
    }
}

GetRandomClient() {
    new activeClients[MAXPLAYERS+1], nActiveClients;
    for (new x = 1; x <= MaxClients; x++) {
        // Push the client into an empty position of the array and add to the number of reported active clients.
        if (IsValidClient(x)) {
            activeClients[nActiveClients++] = x;
        }
    }
    
    return activeClients[GetRandomInt(0, nActiveClients - 1)];
}

bool:IsValidClient(entity) {
    return entity > 0 && IsValidEntity(entity) && IsClientInGame(entity) && !IsFakeClient(entity);
}

public Float:GetRandomFloatDeviation(Float:fMean, Float:fDeviation) {
    return GetRandomFloat(fMean - fDeviation, fMean + fDeviation);
}