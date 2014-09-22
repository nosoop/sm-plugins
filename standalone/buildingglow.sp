/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <tf2_stocks>

#define PLUGIN_VERSION          "0.0.1"     // Plugin version.

public Plugin:myinfo = {
    name = "[TF2] Building Glow",
    author = "nosoop",
    description = "Enables glow outlines for the Engineer that placed them.",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

#define ARRAY_GLOWENT           0
#define ARRAY_CLIENT            1
#define ARRAY_BUILDING          2

new Handle:g_rgBuildingClientProps = INVALID_HANDLE;

// new Handle:g_hCookieBuildingGlow = INVALID_HANDLE;
// new bool:g_bClientBuildingGlowEnable[MAXPLAYERS+1];

public OnPluginStart() {
    // g_hCookieBuildingGlow = RegClientCookie("OurTestCookie", "A Test Cookie for use in our Tutorial", CookieAccess_Private);
    // SetCookiePrefabMenu(g_hCookieBuildingGlow, CookieMenu_OnOff_Int, "TestCookie", CookieHandler_BuildingGlow);
    // for (new i = MaxClients; i > 0; --i) {
    //     if (!AreClientCookiesCached(i)) {
    //         continue;
    //     }
    //     
    //     OnClientCookiesCached(i);
    // }
    
    HookEvent("player_builtobject", Event_BuiltObject);
    g_rgBuildingClientProps = CreateArray(3);
}

public OnMapStart() {
    PrecacheModel("effects/strider_bulge_dudv_dx60.vmt");
}

public CookieHandler_BuildingGlow(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
    // switch (action) {
    //     case CookieMenuAction_DisplayOption: {
    //     }
    //     case CookieMenuAction_SelectOption: {
    //         OnClientCookiesCached(client);
    //     }
    // }
}

public Action:Event_BuiltObject(Handle:event, const String:name[], bool:dontBroadcast) {
    new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsPlayerAlive(iClient)) {
        return Plugin_Continue;
    }
    
    new iBuilding = GetEventInt(event, "index");
    
    // if (FindValueInArray(g_rgBuildingClientProps, iEntity)) == -1) {
    new iGlowSprite = CreateBuildingSprite(iBuilding);
    if (iGlowSprite != -1) {
        PushGlowSpriteToArray(iBuilding, iClient, iGlowSprite);
    }
    // }
    
    return Plugin_Continue;
}

public OnEntityDestroyed(iEntity) {
    new iSlot;
    if ( (iSlot = FindGlowSpriteSlotByValue(ARRAY_BUILDING, iEntity)) == -1 ) {
        new iGlowEntity = GetArrayCell(g_rgBuildingClientProps, iSlot);
        if (IsValidEdict(iGlowEntity)) {
            AcceptEntityInput(iGlowEntity, "kill");
        }
        
        RemoveFromArray(g_rgBuildingClientProps, iSlot);
    }
}

public OnClientCookiesCached(client) {
    // decl String:sValue[8];
    // GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
    
    // g_bClientBuildingGlowEnable[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

PushGlowSpriteToArray(iBuilding, iClient, iGlowSprite) {
    new iSlot = PushArrayCell(g_rgBuildingClientProps, iGlowSprite);
    SetArrayCell(g_rgBuildingClientProps, iSlot, iClient, ARRAY_CLIENT);
    SetArrayCell(g_rgBuildingClientProps, iSlot, iBuilding, ARRAY_BUILDING);
}

FindGlowSpriteSlotByValue(iSlot, iValue) {
    new nElements = GetArraySize(g_rgBuildingClientProps);
    for (new i = 0; i < nElements; i++) {
        if (GetArrayCell(g_rgBuildingClientProps, i, iSlot) == iValue) {
            return i;
        }
    }
    return -1;
}

CreateBuildingSprite(iBuilding) {
    new iGlowSprite = CreateEntityByName("env_sprite");
    
    if (iGlowSprite > 0 && IsValidEntity(iGlowSprite)) {
        DispatchKeyValue(iGlowSprite, "classname", "env_sprite");
        DispatchKeyValue(iGlowSprite, "spawnflags", "1");
        DispatchKeyValue(iGlowSprite, "rendermode", "0");
        DispatchKeyValue(iGlowSprite, "rendercolor", "0 0 0");
        
        DispatchKeyValue(iGlowSprite, "model", "effects/strider_bulge_dudv_dx60.vmt");
        SetVariantString("!activator");
        AcceptEntityInput(iGlowSprite, "SetParent", iBuilding, iGlowSprite, 0);
        SetVariantString("head");
        AcceptEntityInput(iGlowSprite, "SetParentAttachment", iGlowSprite, iGlowSprite, 0);
        
        DispatchSpawn(iGlowSprite);

        SDKHook(iGlowSprite, SDKHook_SetTransmit, OnBuildingGlowSetTransmit);
        TeleportEntity(iGlowSprite, Float:{0.0,0.0,-4.0}, NULL_VECTOR, NULL_VECTOR);
        
        return iGlowSprite;
    }
    return -1;
}

public Action:OnBuildingGlowSetTransmit(entity, client) {
    new iCell = FindValueInArray(g_rgBuildingClientProps, entity);
    
    if (iCell > -1 && GetArrayCell(g_rgBuildingClientProps, iCell, ARRAY_CLIENT) == client) {
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

stock bool:IsEnvSpriteEnt(entity) {
    if (entity != -1 && IsValidEdict(entity) && IsValidEntity(entity) && IsEntNetworkable(entity)) {
        decl String:sClassName[255];
        GetEdictClassname(entity, sClassName, 255);
        if (StrEqual(sClassName, "env_sprite")) {
            return true;
        }
    }
    return false;
}
