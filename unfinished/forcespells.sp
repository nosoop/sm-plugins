#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

// Global Definitions
#define PLUGIN_VERSION "1.0.0"

new Handle:holidayState = INVALID_HANDLE;

// Functions
public Plugin:myinfo =
{
    name = "[TF2] Force Spellbook UI",
    author = "nosoop",
    description = "Forces enabling of spellbooks on maps.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
};

public OnPluginStart()
{
    CreateConVar("sm_forcespellbook_version", PLUGIN_VERSION, "Force Spellbook UI Plugin Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    
    RegAdminCmd("sm_forcespell_create", Command_CreateSpell, ADMFLAG_GENERIC, "Spawns a spellbook.");
    
    holidayState = FindConVar("tf_forced_holiday");
}

public OnMapStart()
{
    SetConVarInt(holidayState, 2);

    new holidayLogic = FindEntityByClassname(-1, "tf_logic_holiday");
    
    new gameRules = FindEntityByClassname(-1, "tf_gamerules");
    
    if (IsValidEntity(gameRules))
    {
        SetEntProp(gameRules, Prop_Send, "m_bIsUsingSpells", 1);
        SetEntProp(gameRules, Prop_Send, "m_nMapHolidayType", 2);
    }
    
    // Spawn a new tf_logic_holiday entity if it doesn't exist.
    if (holidayLogic == -1)
    {
        LogMessage("Creating holiday logic entity.");
        holidayLogic = CreateEntityByName("tf_logic_holiday");
        DispatchSpawn(holidayLogic);
    }
    else
    {
        LogMessage("Holiday logic entity found.");
    }
    
    // Enable spell HUD element.
    if (IsValidEntity(holidayLogic))
    {
        DispatchKeyValue(holidayLogic, "Holiday", "Halloween");
    
        SetVariantInt(1);
        AcceptEntityInput(holidayLogic, "SetHalloweenUsingSpells");
        LogMessage("Holiday logic entity received input.");
    }
    else
    {
        LogError("Could not make valid tf_logic_holiday entity?");
    }
}

public Action:Command_CreateSpell(client, args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_forcespell_create <rare 0|1>");
        return Plugin_Handled;
    }
    
    new spellbook = CreateEntityByName("tf_spell_pickup");
    
    decl Float:pos[3], Float:vel[3], Float:ang[3];
    ang[0] = 0.0;
    ang[1] = 0.0;
    ang[2] = 0.0;
    GetClientAbsOrigin(client, pos);
    
    vel[0] = GetRandomFloat(-400.0, 400.0);
    vel[1] = GetRandomFloat(-400.0, 400.0);
    vel[2] = GetRandomFloat(300.0, 500.0);
    
    TeleportEntity(spellbook, pos, ang, vel);
    DispatchSpawn(spellbook);

    return Plugin_Handled;
}