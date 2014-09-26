/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION          "0.0.0"     // Plugin version.

public Plugin:myinfo = {
    name = "[ANY] Zone Mod",
    author = "nosoop",
    description = "Core plugin to help create trigger_multiple entities.",
    version = PLUGIN_VERSION,
    url = "localhost"
}

#define EZONE_SIZE              5
#define ZONE_NAME_MAXLENGTH     64
#define ZONE_MODEL              "models/error.mdl"


new Handle:g_hTreeZones = INVALID_HANDLE;   // Holds a zone name -> entity relation.

enum EZone {
    Zone_XC = 0,
    Zone_YC,
    Zone_ZC,
    Zone_W,
    Zone_H
};

public APLRes:AskPluginLoad2(Handle:hMySelf, bool:bLate, String:strError[], iMaxErrors) {
    RegPluginLibrary("zonemod");
    CreateNative("Zone_Create", Zone_Create);
    CreateNative("Zone_Remove", Zone_Remove);
    
    return APLRes_Success;
}

public OnPluginStart() {
    g_hTreeZones = CreateTrie();
}

public OnPluginEnd() {
    CloseHandle(g_hTreeZones);
}

public OnMapStart() {
    PrecacheModel(ZONE_MODEL, true);
}

public OnMapEnd() {
    ClearTrie(g_hTreeZones);
}

CreateZone(const String:sZoneName[], const Float:vStartVertex[3], const Float:vEndVertex[3]) {
    new iZone = -1;
    
    if (GetTrieValue(g_hTreeZones, sZoneName, iZone)) {
        return iZone;
    }
    
    iZone = CreateEntityByName("trigger_multiple");
    
    // A significant chunk of this code is sourced from "Map Zones" by Root_.
    // https://github.com/zadroot/DoD_Zones/blob/master/scripting/sm_zones.sp
    if (iZone > -1) {
        decl Float:vMin[3], Float:vMax[3], Float:vMidpoint[3];
        decl String:sZoneTargetName[ZONE_NAME_MAXLENGTH+16];
        Format(sZoneTargetName, sizeof(sZoneTargetName), "_sm_zonemod_%s", sZoneName);
        
        DispatchKeyValue(iZone, "targetname", sZoneTargetName);
        DispatchKeyValue(iZone, "spawnflags", "64");
        DispatchKeyValue(iZone, "wait", "0");
        
        DispatchSpawn(iZone);
        ActivateEntity(iZone);
        
        SetEntProp(iZone, Prop_Data, "m_spawnflags", 64);
        
        GetVectorMidpoint(vStartVertex, vEndVertex, vMidpoint);
        
        TeleportEntity(iZone, vMidpoint, NULL_VECTOR, NULL_VECTOR);
        SetEntityModel(iZone, ZONE_MODEL);
        
        // Sort vectors.
        for (new i = 0; i < 3; i++) {
            vMin[i] = vStartVertex[i] - vMidpoint[i];
            if (vMin[i] > 0.0) {
                vMin[i] *= -1.0;
            }
        }
        for (new i = 0; i < 3; i++) {
            vMax[i] = vEndVertex[i] - vMidpoint[i];
            if (vMax[i] < 0.0) {
                vMax[i] *= -1.0;
            }
        }
        
        SetEntPropVector(iZone, Prop_Send, "m_vecMins", vMin);
        SetEntPropVector(iZone, Prop_Send, "m_vecMaxs", vMax);
        
        // Enable touch functions and set it as non-solid for everything.
        SetEntProp(iZone, Prop_Send, "m_usSolidFlags", 152);
        SetEntProp(iZone, Prop_Send, "m_CollisionGroup", 11);
        
        // Make the zone visible by removing EF_NODRAW flag.
        new m_fEffects = GetEntProp(iZone, Prop_Send, "m_fEffects");
        m_fEffects |= 0x020;
        SetEntProp(iZone, Prop_Send, "m_fEffects", m_fEffects);
        
        SetEntityRenderMode(iZone, RENDER_NONE);
        
        SetTrieValue(g_hTreeZones, sZoneName, iZone);
    }
    return iZone;
}

public Zone_Create(Handle:hPLugin, nParams) {
    decl String:sZoneName[ZONE_NAME_MAXLENGTH], Float:vStartVertex[3], Float:vEndVertex[3];
    
    GetNativeString(1, sZoneName, sizeof(sZoneName));
    GetNativeArray(2, vStartVertex, sizeof(vStartVertex));
    GetNativeArray(3, vEndVertex, sizeof(vEndVertex));
    
    return CreateZone(sZoneName, vStartVertex, vEndVertex);
}

RemoveZone(const String:sZoneName[]) {
    new iZone = -1;
    if (GetTrieValue(g_hTreeZones, sZoneName, iZone)) {
        AcceptEntityInput(iZone, "kill");
        RemoveFromTrie(g_hTreeZones, sZoneName);
        return true;
    }
    return false;
}

public Zone_Remove(Handle:hPLugin, nParams) {
    decl String:sZoneName[ZONE_NAME_MAXLENGTH];
    GetNativeString(1, sZoneName, sizeof(sZoneName));
    
    return RemoveZone(sZoneName);
}

GetVectorMidpoint(const Float:vPoint1[3], const Float:vPoint2[3], Float:vMidpoint[3]) {
    decl Float:vMidpointDirectional[3];
    
    MakeVectorFromPoints(vPoint1, vPoint2, vMidpointDirectional);
    ScaleVector(vMidpointDirectional, 0.5);
    
    AddVectors(vPoint1, vMidpointDirectional, vMidpoint);
}