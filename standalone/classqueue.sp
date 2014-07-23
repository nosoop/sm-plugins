#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

#define PL_VERSION "1.0.2"

public Plugin:myinfo = {
    name = "[TF2] Queue Class Change",
    author = "nosoop",
    description = "Allows a player to queue a class change, mainly for Arena mode.", // BECAUSE VALVE HATES GIVING ATTENTION TO ARENA MODE
    version = PL_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
}

// Puts classes in TF2-style order.
new TFClassType:g_iMenuToClass[9] = {
    TFClass_Scout,      TFClass_Soldier,    TFClass_Pyro,
    TFClass_DemoMan,    TFClass_Heavy,      TFClass_Engineer,
    TFClass_Medic,      TFClass_Sniper,     TFClass_Spy
};

// Class strings in TF2-style order.
new String:rg_sMenuToString[9][10] = {
    "Scout",            "Soldier",          "Pyro",
    "Demoman",          "Heavy",            "Engineer",
    "Medic",            "Sniper",           "Spy"
};

public OnPluginStart() {
    CreateConVar("sm_arenaclasschange_version", PL_VERSION, "Prints plugin version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    
    // Overrides +showroundinfo (default bind on F1) for convenience and usually because nobody uses it.
    AddCommandListener(Event_ChangeClass, "+showroundinfo");
    AddCommandListener(Event_ChangeClass2, "-showroundinfo");
    
    // TODO Figure out a proper way to hook into class selection or re-enable them for arena mode.
}

public PanelHandler1(Handle:menu, MenuAction:action, client, selection) {
    if (action == MenuAction_Select) {
        new iClassIndex = selection - 1;    // Menu selection is 1-index-based, so we subtract one.
        
        // Set the desired class if it's different from the existing one.
        if (g_iMenuToClass[iClassIndex] != TFClassType:GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass")) {
            // Change next class through netprops.  No need to store and handle it ourselves.
            SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", g_iMenuToClass[iClassIndex]);
            
            // Do have to send the respawn message, though.  TODO Localize?
            PrintToChat(client, "*You will respawn as %s", rg_sMenuToString[iClassIndex]);
        }
    }
}

ShowClassSelectionMenuPanel(client) {
    new Handle:hPanel = CreatePanel();
    SetPanelTitle(hPanel, "Class selection:");
    
    for (new i = 0; i < 9; i++) {
        DrawPanelItem(hPanel, rg_sMenuToString[i]);
    }

    SendPanelToClient(hPanel, client, PanelHandler1, 20);
    CloseHandle(hPanel);
}
 
public Action:Event_ChangeClass(client, const String:command[], argc) {
    ShowClassSelectionMenuPanel(client);
    return Plugin_Handled;
}

public Action:Event_ChangeClass2(client, const String:command[], argc) {
    // Do nothing; just prevent reporting -showroundinfo as an unknown command.
    return Plugin_Handled;
}