/**
 * 2spooky.  sospooky
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

#define TIME_EYELANDER_MEAN     10.0        // Final: 60.0
#define TIME_EYELANDER_DEV      3.0         // Final: 10.0

#define TIME_UNDERWORLD_MEAN    5.0         // Final: ???
#define TIME_UNDERWORLD_DEV     2.0         // Final: ???

#define ENTITY_SOURCE_COUNT     100         // Maximum number of sources for sounds.

public Plugin:myinfo = {
    name = "[TF2] Dodgeball...?",
    author = "nosoop",
    description = "Description!",
    version = PLUGIN_VERSION,
    url = "localhost"
}

new g_entSoundSources[ENTITY_SOURCE_COUNT], g_iEntityIndex;
new String:g_sSoundEyelander[15][64], String:g_sSoundUnderworld[30][64];

public OnPluginStart() {
    PrecacheNoises();
}

public OnMapStart() {
    new shakeEntity = CreateEntityByName("env_shake");
    DispatchKeyValueFloat(shakeEntity, "amplitude", 15.0);
    DispatchKeyValueFloat(shakeEntity, "frequency", 220.0);
    DispatchKeyValueFloat(shakeEntity, "duration", 5.0);
    DispatchKeyValueFloat(shakeEntity, "radius", 10000.0);
    DispatchSpawn(shakeEntity);
    
    AcceptEntityInput(shakeEntity, "StartShake");
    CreateTimer(10.0, Timer_KillShake, shakeEntity);
    
    CreateTimer(GetRandomFloatDeviation(TIME_EYELANDER_MEAN, TIME_EYELANDER_DEV), Timer_PlayEyelanderNoise);
    CreateTimer(GetRandomFloatDeviation(TIME_UNDERWORLD_MEAN, TIME_UNDERWORLD_DEV), Timer_PlayUnderworldNoise);
    EmitSoundToAll("misc/halloween/gotohell.wav", _, _, _, _, 0.8);
}

public Action:Timer_KillShake(Handle:data, any:entity) {
    AcceptEntityInput(entity, "kill");
}

PrecacheNoises() {
    for (new i = 0; i < 15; i++) {
        decl String:soundName[64];
        Format(soundName, sizeof(soundName), "vo/sword_idle%02d.wav", i+1);
        g_sSoundEyelander[i] = soundName;
        
        PrecacheSound(soundName, true);
    }
    
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

public OnEntityCreated(entity, const String:classname[]) {
   SDKHook(entity, SDKHook_Spawn, OnEntitySpawned);
}

public OnEntitySpawned(entity) {
    if (g_iEntityIndex < ENTITY_SOURCE_COUNT) {
        g_entSoundSources[g_iEntityIndex++] = entity;
    } else {
        g_entSoundSources[GetRandomInt(0, ENTITY_SOURCE_COUNT - 1)] = entity;
    }
}

public Action:Timer_PlayEyelanderNoise(Handle:data) {
    new client, tries;
    while ( !IsValidClient((client = GetRandomInt(1, MaxClients))) && tries < 10 ) {
        tries++;
    }
    
    if (IsValidClient(client)) {
        decl String:soundName[64];
        strcopy(soundName, sizeof(soundName), g_sSoundEyelander[GetRandomInt(0, sizeof(g_sSoundEyelander) - 1)]);
        new iSource = SOUND_FROM_PLAYER; // g_entSoundSources[GetRandomInt(0, g_iEntityIndex - 1)];
        new Float:fVolume = GetRandomFloat(0.5, 0.8);
        
        // LogMessage("Playing %s to %N from entity %d.", soundName, client, iSource);
        EmitSoundToClient(client, soundName, iSource, _, _, _, fVolume);
    }
    
    CreateTimer(GetRandomFloatDeviation(TIME_EYELANDER_MEAN, TIME_EYELANDER_DEV), Timer_PlayEyelanderNoise);
}

public Action:Timer_PlayUnderworldNoise(Handle:data) {
    new client, tries;
    while ( !IsValidClient((client = GetRandomInt(1, MaxClients))) && tries < 10 ) {
        tries++;
    }
    
    if (IsValidClient(client)) {
        decl String:soundName[64];
        strcopy(soundName, sizeof(soundName), g_sSoundUnderworld[GetRandomInt(0, sizeof(g_sSoundUnderworld) - 1)]);
        new iSource = SOUND_FROM_PLAYER; // g_entSoundSources[GetRandomInt(0, g_iEntityIndex - 1)];
        new Float:fVolume = GetRandomFloat(0.1, 0.3);
        
        // LogMessage("Playing %s to %N from entity %d.", soundName, client, iSource);
        EmitSoundToClient(client, soundName, iSource, _, _, _, fVolume);
    }
    
    CreateTimer(GetRandomFloatDeviation(TIME_UNDERWORLD_MEAN, TIME_UNDERWORLD_DEV), Timer_PlayUnderworldNoise);
}

bool:IsValidClient(entity) {
    return entity > 0 && IsValidEntity(entity) && IsClientInGame(entity) && !IsFakeClient(entity);
}

public Float:GetRandomFloatDeviation(Float:fMean, Float:fDeviation) {
    return GetRandomFloat(fMean - fDeviation, fMean + fDeviation);
}