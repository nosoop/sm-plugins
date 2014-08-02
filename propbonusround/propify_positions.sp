/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <propify>

#define PLUGIN_VERSION          "0.1.0"     // Plugin version.

#define VEC3_ROTATION_INDEX     3           // Starting index in the prop positions array for the rotation vector.

public Plugin:myinfo = {
    name = "[TF2] Propify! Positions",
    author = "nosoop",
    description = "Adds configuration settings to add positional transforms to props.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop/sm-plugins"
}

new Handle:g_hPropPositions = INVALID_HANDLE, Handle:g_hPropPaths = INVALID_HANDLE;

public OnPluginStart() {
    g_hPropPositions = CreateArray(6);
    g_hPropPaths = CreateArray(PLATFORM_MAX_PATH);
}

public OnPluginEnd() { 
    Propify_UnregisterConfigHandlers();
}

public OnAllPluginsLoaded() {
    if (LibraryExists("nosoop-propify")) {
        // TODO Figure out how to get ConfigHandler_All working.
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
            PrintToServer("Found prop %s.", buffer);
            new Float:off[3], Float:rot[3];
            GetArrayVector(g_hPropPositions, propOffsetIndex, off);
            GetArrayVector(g_hPropPositions, propOffsetIndex, rot, VEC3_ROTATION_INDEX);
            
            SetVariantPosVector3D(off);
            AcceptEntityInput(client, "SetCustomModelOffset");
            
            // TODO Figure out how to rotate with the player.
            SetVariantVector3D(rot);
            AcceptEntityInput(client, "SetCustomModelRotation");
        } else {
            PrintToServer("Could not find prop %s.", buffer);
        }
        
        CloseHandle(propPaths);
    } else {
        AcceptEntityInput(client, "ClearCustomModelRotation");
    }
}

public ConfigHandler_PropOffsets(const String:key[], const String:value[]) {
    new index = FindPropPath(key);
    
    new Float:vOffset[3];
    StringToVector(value, vOffset);
    
    PushArrayCell(g_hPropPositions, 0.0);
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
    PrintToServer("Index %d : %s", index, propPath);
    return index;
}