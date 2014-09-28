/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <zonemod>

#define PLUGIN_VERSION          "0.1.2"     // Plugin version.

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
    ClearArray(g_hArrayZoneSettings);

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
                SetArrayCell(g_hArrayZoneSettings, iArrayPosition, iZoneTeamRestriction, ZONESTRUCT_TEAM);
                SetArrayCell(g_hArrayZoneSettings, iArrayPosition, iZonePunishment, ZONESTRUCT_PUNISHMENT);
            }
        } while (KvGotoNextKey(kv));
     
        CloseHandle(kv);
    }
}

public OnPluginEnd() {
    decl String:sZoneName[255];
    
    // Remove all zones associated with the plugin.
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
        
        // Apply on player if part of the team specified in the restrict_team keyvalue.
        if (iZoneSettings != -1) {
            new iZoneTeam = GetArrayCell(g_hArrayZoneSettings, iZoneSettings, ZONESTRUCT_TEAM);
            
            PrintToServer("Client %d started touching zone.", iEntity);
            
            if (iZoneTeam == 0 || iZoneTeam == _:GetClientTeam(iEntity)) {
                new iZonePunishment = GetArrayCell(g_hArrayZoneSettings, iZoneSettings, ZONESTRUCT_PUNISHMENT);
                PrintToServer("Punishment is %d.", iZonePunishment);
                
                switch (iZonePunishment) {
                    case PUNISHMENT_ANNOUNCE: {
                        PrintToChatAll("%N has entered a zone.", iEntity);
                    }
                    case PUNISHMENT_BOUNCE: {
                        decl Float:vVelocity[3], Float:fZVelBuffer;
                        GetEntPropVector(iEntity, Prop_Data, "m_vecVelocity", vVelocity);
                        
                        fZVelBuffer = vVelocity[2];
                        vVelocity[2] = 0.0;
                        
                        // Push back at a rate of 300 HU/s in the specified direction at minimum.
                        if (GetVectorLength(vVelocity, true) < 90000.0) {
                            NormalizeVector(vVelocity, vVelocity);
                            ScaleVector(vVelocity, 300.0);
                        }
                        
                        vVelocity[2] = fZVelBuffer;
                        
                        // Bounce the player back down if necessary.
                        if (FloatCompare(vVelocity[2], 0.0) > 0) {
                            vVelocity[2] *= -0.1;
                        }
                        
                        TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, vVelocity);
                        
                        // Bounces back everything.  Or tries to, anyways.
                        SetEntProp(iZone, Prop_Send, "m_CollisionGroup", 17);
                    }
                    case PUNISHMENT_SLAY: {
                        ForcePlayerSuicide(iEntity);
                    }
                    case PUNISHMENT_NOSHOOT: {
                        // TODO Implement no shoot?
                    }
                    case PUNISHMENT_MELEE: {
                        // TODO Implement melee?
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
}
