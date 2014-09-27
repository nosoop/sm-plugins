/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <zonemod>

#define PLUGIN_VERSION          "0.1.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[ANY] Zone Mod (DoD_Zones Config Loader)",
    author = "nosoop",
    description = "Loads the zones created by the Map Zones plugin.",
    version = PLUGIN_VERSION,
    url = "localhost"
}

#define PUNISHMENT_DEFAULT      0
#define PUNISHMENT_ANNOUNCE     1
#define PUNISHMENT_BOUNCE       2
#define PUNISHMENT_SLAY         3
#define PUNISHMENT_NOSHOOT      4
#define PUNISHMENT_MELEE        5
#define PUNISHMENT_CUSTOM       6

#define ZONESTRUCT_ENTITY       0
#define ZONESTRUCT_TEAM         1
#define ZONESTRUCT_PUNISHMENT   2

new Handle:g_hArrayZones = INVALID_HANDLE,
    Handle:g_hArrayZoneSettings = INVALID_HANDLE;

public OnPluginStart() {
    g_hArrayZones = CreateArray(255),
    g_hArrayZoneSettings = CreateArray(3);
}

public OnMapStart() {
    ClearArray(g_hArrayZones);

    decl String:sZoneConfig[PLATFORM_MAX_PATH], String:sMapName[64];
    GetCurrentMap(sMapName, sizeof(sMapName));
    BuildPath(Path_SM, sZoneConfig, sizeof(sZoneConfig), "data/zones/%s.cfg", sMapName);

    if (FileExists(sZoneConfig)) {
        new Handle:kv = CreateKeyValues("Zones");
        FileToKeyValues(kv, sZoneConfig);
        
        if (!KvGotoFirstSubKey(kv)) {
            return;
        }
     
        decl iZone, String:sZoneName[255], iZonePunishment, iZoneTeamRestriction,
                Float:vStartVertex[3], Float:vEndVertex[3];
        do {
            KvGetString(kv, "zone_ident", sZoneName, sizeof(sZoneName));
            KvGetVector(kv, "coordinates 1", vStartVertex);
            KvGetVector(kv, "coordinates 2", vEndVertex);
            
            iZonePunishment = KvGetNum(kv, "punishment", PUNISHMENT_DEFAULT);
            iZoneTeamRestriction = KvGetNum(kv, "restrict_team", 0);
            
            iZone = Zone_Create(sZoneName, vStartVertex, vEndVertex);
            
            if (iZone > -1) {
                SDKHook(iZone, SDKHook_StartTouch, Hook_OnDoDZoneStartTouch);
                PushArrayString(g_hArrayZones, sZoneName);
                
                new iArrayPosition = PushArrayCell(g_hArrayZoneSettings, iZone);
                SetArrayCell(g_hArrayZoneSettings, iArrayPosition, ZONESTRUCT_TEAM, iZoneTeamRestriction);
                SetArrayCell(g_hArrayZoneSettings, iArrayPosition, ZONESTRUCT_PUNISHMENT, iZonePunishment);
            }
        } while (KvGotoNextKey(kv));
     
        CloseHandle(kv);
    }
}

public OnPluginEnd() {
    decl String:sZoneName[255];
    while (GetArraySize(g_hArrayZones) > 0) {
        GetArrayString(g_hArrayZones, 0, sZoneName, sizeof(sZoneName));
        Zone_Remove(sZoneName);
        RemoveFromArray(g_hArrayZones, 0);
        RemoveFromArray(g_hArrayZoneSettings, 0);
    }
}

public Hook_OnDoDZoneStartTouch(iZone, iEntity) {
    if (iEntity < MaxClients && iEntity > 0 && IsClientConnected(iEntity) && IsPlayerAlive(iEntity)) {
        new iZoneSettings = FindValueInArray(g_hArrayZoneSettings, iZone);
        if (GetArrayCell(g_hArrayZoneSettings, iZoneSettings, ZONESTRUCT_TEAM) == _:GetClientTeam(iEntity)) {
            switch (GetArrayCell(g_hArrayZoneSettings, iZoneSettings, ZONESTRUCT_PUNISHMENT)) {
                case PUNISHMENT_ANNOUNCE: {
                    PrintToChatAll("%N has entered a zone.", iEntity);
                }
                case PUNISHMENT_BOUNCE: {
                    decl Float:vVelocity[3];
                    GetEntPropVector(iEntity, Prop_Send, "m_vecVelocity", vVelocity);
                    
                    // Push back at a rate of 200 HU/s.
                    for (new i = 0; i < 2; i++) {
                        if (FloatAbs(vVelocity[i]) < 200.0) {
                            vVelocity[i] = FloatCompare(vVelocity[i], 0.0) > 0 ? 200.0 : -200.0;
                        }
                    }
                    
                    // Bounce the player back down if necessary.
                    if (FloatCompare(vVelocity[2], 0.0) > 0) {
                        vVelocity[2] *= -0.1;
                    }
                }
                case PUNISHMENT_SLAY: {
                    ForcePlayerSuicide(iEntity);
                }
                case PUNISHMENT_NOSHOOT: {
                    // TODO Implement no shoot.
                }
                case PUNISHMENT_MELEE: {
                    // TODO Implement melee.
                }
                case PUNISHMENT_CUSTOM: {
                    // TODO Implement custom?
                }
                default: {
                    ForcePlayerSuicide(iEntity);
                }
            }
        }
    }
}
