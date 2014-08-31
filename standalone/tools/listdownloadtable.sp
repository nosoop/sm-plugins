/**
 * Sourcemod Plugin Template
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION          "0.0.1"     // Plugin version.

public Plugin:myinfo = {
    name = "List Download Table Files",
    author = "nosoop",
    description = "Lists files currently in the downloads table.",
    version = PLUGIN_VERSION,
    url = "localhost"
}

public OnPluginStart() {
    RegAdminCmd("sm_showdownloads", Command_ShowDownloads, ADMFLAG_ROOT, "Show downloaded files.");
}

public Action:Command_ShowDownloads(client, args) {
    new hTable = GetDownloadsTable();
    
    decl String:sFilename[PLATFORM_MAX_PATH];
    for (new i = 0; i < GetStringTableNumStrings(hTable); i++) {
        ReadStringTable(hTable, i, sFilename, sizeof(sFilename));
        PrintToConsole(client, sFilename);
    }
    
    return Plugin_Handled;
}

stock GetDownloadsTable() {
    static hTable = INVALID_STRING_TABLE;
    
    if (hTable == INVALID_STRING_TABLE) {
        hTable = FindStringTable("downloadables");
    }
    
    return hTable;
}

stock RemoveFileFromDownloadsTable(const String:szFileName[]) {
    static hTable = INVALID_STRING_TABLE;
    
    if (hTable == INVALID_STRING_TABLE) {
        hTable = FindStringTable("downloadables");
    }
    
    new iIndex = FindStringIndex2(hTable, szFileName);
    if (iIndex != INVALID_STRING_INDEX) {
        new bool:bOldState = LockStringTables(false);
        SetStringTableData(hTable, iIndex, "\0", 1);
        LockStringTables(bOldState);
    }
}

stock FindStringIndex2(iTable, const String:szFileName[], iStart=0) {
    new iMax = GetStringTableNumStrings(iTable);
    
    decl String:szBuffer[PLATFORM_MAX_PATH];
    for (new i = iStart; i < iMax; i++) {
        GetStringTableData(iTable, i, szBuffer, sizeof(szBuffer));
        if (strcmp(szFileName, szBuffer, false) == 0) {
            return i;
        }
    }
    
    return INVALID_STRING_INDEX;
}  
