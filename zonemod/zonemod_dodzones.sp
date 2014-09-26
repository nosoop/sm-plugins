/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <zonemod>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

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
        switch (GetArrayCell(g_hArrayZoneSettings, iZoneSettings, ZONESTRUCT_PUNISHMENT)) {
            case PUNISHMENT_SLAY: {
                ForcePlayerSuicide(iEntity);
            }
            case PUNISHMENT_DEFAULT: {
                ForcePlayerSuicide(iEntity);
            }
            default: {
                ForcePlayerSuicide(iEntity);
            }
        }
    }
}
