/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <propify>
#include <sdkhooks>

#define PLUGIN_VERSION          "1.0.3"     // Plugin version.

#define VEC3_ROTATION_INDEX     3           // Starting index in the prop positions array for the rotation vector.

public Plugin:myinfo = {
    name = "[TF2] Propify! Positions",
    author = "nosoop",
    description = "Adds configuration settings to add positional transforms to props.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new Handle:g_hPropPositions = INVALID_HANDLE, Handle:g_hPropPaths = INVALID_HANDLE;
new bool:g_bIsPropifyLoaded;

new Float:g_rgPropOffsetAngles[MAXPLAYERS+1][3];

public OnPluginStart() {
    g_hPropPositions = CreateArray(6);
    g_hPropPaths = CreateArray(PLATFORM_MAX_PATH);
}

public OnPluginEnd() { 
    Propify_UnregisterConfigHandlers();
    
    // TODO Fire "clear custom model rotation" input on all affected clients
}

public Propify_OnPropListCleared() {
    ClearArray(g_hPropPositions);
    ClearArray(g_hPropPaths);
}

public OnAllPluginsLoaded() {
    g_bIsPropifyLoaded = LibraryExists("nosoop-propify");
    
    if (g_bIsPropifyLoaded) {
        // TODO Figure out how to get ConfigHandler_All working.
        Propify_RegisterConfigHandler("prop_offsets", ConfigHandler_PropOffsets, ConfigHandler_All);
        Propify_RegisterConfigHandler("prop_rotations", ConfigHandler_PropRotations, ConfigHandler_All);
    }
}

public OnLibraryRemoved(const String:name[]) {
    g_bIsPropifyLoaded &= !StrEqual(name, "nosoop-propify");
}

public OnLibraryAdded(const String:name[]) {
    g_bIsPropifyLoaded |= StrEqual(name, "nosoop-propify");
    
    if (g_bIsPropifyLoaded) {
        Propify_RegisterConfigHandler("prop_offsets", ConfigHandler_PropOffsets, ConfigHandler_All);
        Propify_RegisterConfigHandler("prop_rotations", ConfigHandler_PropRotations, ConfigHandler_All);
    }
}

public Propify_OnPropified(client, propIndex) {
    if (propIndex > -1) {
        new Handle:propPaths = Propify_GetModelPathsArray();
        
        new String:buffer[PLATFORM_MAX_PATH];
        GetArrayString(propPaths, propIndex, buffer, sizeof(buffer));
        
        new propOffsetIndex;
        if ( (propOffsetIndex = FindStringInArray(g_hPropPaths, buffer)) > -1 ) {
            new Float:off[3];
            GetArrayVector(g_hPropPositions, propOffsetIndex, off);
            
            // TODO Figure out if this is all we need for offsets.
            SetVariantVector3D(off);
            AcceptEntityInput(client, "SetCustomModelOffset");
            
            // Store the offset angles for the client instead of looking it up in the dynamic array.
            GetArrayVector(g_hPropPositions, propOffsetIndex, g_rgPropOffsetAngles[client], VEC3_ROTATION_INDEX);
            
            // Hook into prethink for client to update model rotation if it's a non-zero vector.
            if (GetVectorLength(g_rgPropOffsetAngles[client], true) > 0.0) {
                SDKHook(client, SDKHook_PreThink, SDKHook_OnPreThink);
            }
        }
        
        CloseHandle(propPaths);
    } else {
        SetVariantVector3D(NULL_VECTOR);
        AcceptEntityInput(client, "SetCustomModelOffset");
    
        AcceptEntityInput(client, "ClearCustomModelRotation");
        SDKUnhook(client, SDKHook_PreThink, SDKHook_OnPreThink);
    }
}

public SDKHook_OnPreThink(client) {
    new Float:angle[3];
    GetClientAbsAngles(client, angle);
    
    angle[1] += g_rgPropOffsetAngles[client][1];
    
    SetVariantVector3D(angle);
    AcceptEntityInput(client, "SetCustomModelRotation");
}

public ConfigHandler_PropOffsets(const String:key[], const String:value[]) {
    new index = FindPropPath(key);
    
    new Float:vOffset[3];
    StringToVector(value, vOffset);
    
    SetArrayVector(g_hPropPositions, index, vOffset);
}

public ConfigHandler_PropRotations(const String:key[], const String:value[]) {
    new index = FindPropPath(key);
    
    new Float:vRotation[3];
    StringToVector(value, vRotation);
    
    SetArrayVector(g_hPropPositions, index, vRotation, VEC3_ROTATION_INDEX);
}

StringToVector(const String:value[], Float:vector[3]) {
    new String:sVector[3][12];
    ExplodeString(value, " ", sVector, sizeof(sVector), sizeof(sVector[]));
    
    for (new i = 0; i < sizeof(sVector); i++) {
        vector[i] = StringToFloat(sVector[i]);
    }
}

GetArrayVector(Handle:array, index, Float:vector[3], startBlock = 0) {
    for (new i = 0; i < 3; i++) {
        vector[i] = GetArrayCell(array, index, i + startBlock);
    }
}

SetArrayVector(Handle:array, index, Float:vector[3], startBlock = 0) {
    for (new i = 0; i < 3; i++) {
        SetArrayCell(array, index, vector[i], i + startBlock);
    }
}

FindPropPath(const String:propPath[]) {
    new index = FindStringInArray(g_hPropPaths, propPath);
    
    if (index == -1) {
        PushArrayCell(g_hPropPositions, 0.0);
    }
    
    index = index > -1 ? index : PushArrayString(g_hPropPaths, propPath);
    return index;
}