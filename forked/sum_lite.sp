/***
 * This program has been released under the terms of the GPL v3 (http://www.gnu.org/licenses/gpl-3.0.txt)
 *
 * Version 1.5.0 released 2008-02-25
 */

#include <sourcemod>

#pragma semicolon 1

#define ADM_PERM_NONE 0
#define ADM_PERM_LIGHT 4079 // no unban, cheats, rcon, root
#define ADM_PERM_DEFAULT 12287 // no rcon, root
#define ADM_PERM_FULL 16383 // no root
#define ADM_PERM_ROOT 32767


#define STEAMID_LENGTH 30
enum DatabaseIdent {
	DBIdent_Unknown,
	DBIdent_MySQL,
	DBIdent_SQLite,
};

public Plugin:myinfo = {
	name = "SUM (Lite)",
	author = "nosoop, original by sfPlayer",
	description = "A fork of SUM.  Handles persistent bans exclusively with SQLite.",
	version = "1.0.1",
	url = "http://github.com/nosoop"
}

new Handle:hDatabase = INVALID_HANDLE;
new DatabaseIdent:databaseIdent = DBIdent_Unknown;
 
public OnPluginStart() {
	SQL_TConnect(gotDatabase, "sumdb");
	RegAdminCmd("sum_setup", sum_setup, ADMFLAG_ROOT, "Create and configure the SUM Database");
	RegAdminCmd("sum_stats", sum_stats, ADMFLAG_RCON, "Shows SUM statistics");
	RegAdminCmd("sum_setadmin", sum_setadmin, ADMFLAG_ROOT, "Sets global admin permissions for SUM");
	RegConsoleCmd("sum_admins", sum_admins, "List SUM admins");
	RegConsoleCmd("sum_banlog", sum_banlog, "List previous bans");
}

public OnMapStart() {
	if (hDatabase == INVALID_HANDLE) {
		SQL_TConnect(gotDatabase, "sumdb");
	}
}
 
public gotDatabase(Handle:owner, Handle:hndl, const String:error[], any:data) {
	if (hndl == INVALID_HANDLE) {
		LogError("SUM: Database failure: %s", error);
	} else {
		hDatabase = hndl;

		decl String:dbIdent[20];
		new Handle:DBDrv = SQL_ReadDriver(hDatabase, dbIdent, sizeof(dbIdent));
		CloseHandle(DBDrv);
		if (StrEqual(dbIdent, "sqlite")) {
			databaseIdent = DBIdent_SQLite;
		} else {
			databaseIdent = DBIdent_Unknown;
		}
	}
}

public OnClientDisconnect(client) {
	decl String:auth[STEAMID_LENGTH];
	GetClientAuthString(client, auth, sizeof(auth));
}

public OnClientAuthorized(client, const String:auth[]) {
	if (hDatabase != INVALID_HANDLE) {
		checkSteamID(GetClientUserId(client), auth);
	}
}


public Action:sum_setup(client, args) {
	if (args != 1 && args != 5 && args != 6) {
		ReplyToCommand(client, "SUM: Usage: sum_setup mysql <host> <database> <user> <password> [<port>] or sum_setup sqlite (local only)");
		return Plugin_Handled;
	}

	decl String:dbIdent[7];
	GetCmdArg(1, dbIdent, sizeof(dbIdent));

	new Handle:kvHandle = CreateKeyValues("Databases");
	decl String:kvFileName[255];
	BuildPath(Path_SM, kvFileName, sizeof(kvFileName), "configs/databases.cfg");
	FileToKeyValues(kvHandle, kvFileName);

	if (StrEqual(dbIdent, "sqlite")) {
		decl String:err[128];

		new Handle:dbDrvHandle = SQL_GetDriver("sqlite");
		if (dbDrvHandle == INVALID_HANDLE) {
			ReplyToCommand(client, "SUM: Error: The SQLite driver (SM extension) is not available");
			CloseHandle(kvHandle);
			return Plugin_Handled;
		}

		KvJumpToKey(kvHandle, "sumdb", true);
		KvSetString(kvHandle, "driver", "sqlite");
		KvSetString(kvHandle, "database", "sumdb");
		
		new Handle:dbConnection = SQL_ConnectCustom(kvHandle, err, sizeof(err), false);
		if (dbConnection == INVALID_HANDLE) {
			ReplyToCommand(client, "SUM: Error: The SQLite configuration is invalid (%s)", err);
			CloseHandle(dbDrvHandle);
			CloseHandle(kvHandle);
			return Plugin_Handled;
		} else {
			if (!SQL_FastQuery(dbConnection, "CREATE TABLE banlog (target varchar(30) NOT NULL,creator varchar(30) NOT NULL,time unsigned int(10) NOT NULL,duration unsigned int(10) NOT NULL,reason varchar(64) NOT NULL,KEY target);") || !SQL_FastQuery(dbConnection, "CREATE TABLE client (steamid varchar(30) NOT NULL,admin unsigned int(10) NOT NULL default '0',banneduntil unsigned int(10) NOT NULL default '0',bancount unsigned int(10) NOT NULL default '0',connectcount unsigned int(10) NOT NULL default '0',lastconnect unsigned int(10) NOT NULL default '0',PRIMARY KEY (steamid));") || !SQL_FastQuery(dbConnection, "CREATE TABLE clientname (steamid varchar(30) NOT NULL,name varchar(64) NOT NULL,count unsigned int(10) NOT NULL default '0',PRIMARY KEY (steamid,name));")) {
				if (SQL_GetError(dbConnection, err, sizeof(err))) {
					ReplyToCommand(client, "SUM: Error: Can't create database (%s)", err);
				}
				CloseHandle(dbConnection);
				CloseHandle(dbDrvHandle);
				CloseHandle(kvHandle);
				return Plugin_Handled;
			}
			CloseHandle(dbConnection);
			CloseHandle(dbDrvHandle);
		}

	} else {
		ReplyToCommand(client, "SUM: Usage: sum_setup mysql <host> <database> <user> <password> [<port>] or sum_setup sqlite (local only)");
		CloseHandle(kvHandle);
		return Plugin_Handled;
	}

	KvRewind(kvHandle);
	if (KeyValuesToFile(kvHandle, kvFileName)) {
		ReplyToCommand(client, "SUM: Database setup successful, change the map to activate it");
	} else {
		ReplyToCommand(client, "SUM: Error: Can't write database config, configure it manually");
	}

	CloseHandle(kvHandle);
	return Plugin_Handled;
}

public Action:sum_stats(client, args) {
	if (hDatabase == INVALID_HANDLE) {
		ReplyToCommand(client, "SUM: Database offline");
	} else {
		SQL_LockDatabase(hDatabase);

		new Handle:query = SQL_Query(hDatabase, "SELECT COUNT(*) FROM client UNION ALL SELECT COUNT(*) FROM client WHERE admin > 0 UNION ALL SELECT COUNT(*) FROM clientname;");
		if (query != INVALID_HANDLE && SQL_FetchRow(query)) {
			new users = SQL_FetchInt(query, 0);
			SQL_FetchRow(query);
			new admins = SQL_FetchInt(query, 0);
			SQL_FetchRow(query);
			new names = SQL_FetchInt(query, 0);
			CloseHandle(query);

			ReplyToCommand(client, "SUM: Database online\n\n%d users (%d admins)\n%d names", users, admins, names);
		} else {
			decl String:err[128];
			SQL_GetError(hDatabase, err, sizeof(err));
			ReplyToCommand(client, "SUM: Database error: %s", err);
		}

		SQL_UnlockDatabase(hDatabase);
	}

	return Plugin_Handled;
}

public Action:sum_admins(client, args) {
	if (hDatabase != INVALID_HANDLE) {
		decl String:queryStr[300];

		if (databaseIdent == DBIdent_SQLite) {
			// limitation: doesn't show mostly used name
			strcopy(queryStr, sizeof(queryStr), "SELECT cl.steamid, name, admin FROM client cl LEFT JOIN clientname cn ON (cl.steamid = cn.steamid) WHERE admin>0 GROUP BY cl.steamid ORDER BY cl.steamid ASC LIMIT 100;");
		}

		if (client > 0) {
			SQL_TQuery(hDatabase, T_queryAdmins, queryStr, GetClientUserId(client));
		} else {
			SQL_LockDatabase(hDatabase);
			new Handle:query = SQL_Query(hDatabase, queryStr);

			displayAdminList(query, 0);

			CloseHandle(query);
			SQL_UnlockDatabase(hDatabase);
		}
	} else {
		ReplyToCommand(client, "SUM: Database offline");
	}

	return Plugin_Handled;
}

public Action:sum_banlog(client, args) {
	ReplyToCommand(client, "SUM: Usage: sum_banlog [<name|#userid|steamid|unknown>] [<target|creator>=target]");

	if (hDatabase != INVALID_HANDLE) {
		new String:queryStr[150] = "SELECT target, creator, time, duration, reason FROM banlog %sORDER BY time DESC LIMIT 100;";
		decl String:auth[STEAMID_LENGTH];

		if (args == 0) {
			Format(queryStr, sizeof(queryStr), queryStr, "");
		} else {
			if (args == 1 || args == 2) {
				decl String:arg1[MAX_NAME_LENGTH+1];
				GetCmdArg(1, arg1, sizeof(arg1));

				if (StrEqual(arg1, "unknown", false)) {
					auth = "UNKNOWN";
				} else {
					new target = FindTarget(client, arg1, true, false);
					if (target == -1) return Plugin_Handled;
				
					GetClientAuthString(target, auth, sizeof(auth));
				}
			} else if (args == 5 || args == 6) {
				decl String:argArr[5][11];
				GetCmdArg(1, argArr[0], 11);
				GetCmdArg(2, argArr[1], 11);
				GetCmdArg(3, argArr[2], 11);
				GetCmdArg(4, argArr[3], 11);
				GetCmdArg(5, argArr[4], 11);

				if (StrEqual(argArr[0], "STEAM_0") && StrEqual(argArr[1], ":") && isNumeric(argArr[2]) && StrEqual(argArr[3], ":") && isNumeric(argArr[4])) {
					ImplodeStrings(argArr, 5, "", auth, sizeof(auth));
				} else {
					return Plugin_Handled;
				}
			} else {
				return Plugin_Handled;
			}

			if (args == 2 || args == 6) {
				decl String:arg_target[8];
				GetCmdArg(args, arg_target, sizeof(arg_target));

				if (StrEqual(arg_target, "creator", false)) {
					Format(queryStr, sizeof(queryStr), queryStr, "WHERE creator = '%s' ");
				} else {
					Format(queryStr, sizeof(queryStr), queryStr, "WHERE target = '%s' ");
				}
				Format(queryStr, sizeof(queryStr), queryStr, auth);
			} else {
				Format(queryStr, sizeof(queryStr), queryStr, "WHERE target = '%s' ");
				Format(queryStr, sizeof(queryStr), queryStr, auth);
			}
		}

		if (client > 0) {
			SQL_TQuery(hDatabase, T_queryBanLog, queryStr, GetClientUserId(client));
		} else {
			SQL_LockDatabase(hDatabase);
			new Handle:query = SQL_Query(hDatabase, queryStr);

			displayBanLog(query, 0);

			CloseHandle(query);
			SQL_UnlockDatabase(hDatabase);
		}
	} else {
		ReplyToCommand(client, "SUM: Database offline");
	}

	return Plugin_Handled;
}

public Action:sum_setadmin(client, args) {
	decl String:arg_string[256];
	GetCmdArgString(arg_string, sizeof(arg_string));

	decl String:arg_pieces[3][STEAMID_LENGTH];

	if (ExplodeString(arg_string, " ", arg_pieces, 3, STEAMID_LENGTH) != 2) {
		ReplyToCommand(client, "SUM: Usage: sum_setadmin <steamid> <permissions|none|light|default|full|root>");
		return Plugin_Handled;
	}

	decl String:auth[STEAMID_LENGTH];
	strcopy(auth, sizeof(auth), arg_pieces[0]);

	if (strncmp(auth, "STEAM_0:", 8) != 0) {
		ReplyToCommand(client, "SUM: Usage: sum_setadmin <steamid> <permissions|none|light|default|full|root>");
		return Plugin_Handled;
	}

	decl String:permissions[11];
	strcopy(permissions, sizeof(permissions), arg_pieces[1]);

	decl admin;

	if (StrEqual(permissions, "none", false)) {
		admin = ADM_PERM_NONE;
	} else if (StrEqual(permissions, "light", false)) {
		admin = ADM_PERM_LIGHT;
	} else if (StrEqual(permissions, "default", false)) {
		admin = ADM_PERM_DEFAULT;
	} else if (StrEqual(permissions, "full", false)) {
		admin = ADM_PERM_FULL;
	} else if (StrEqual(permissions, "root", false)) {
		admin = ADM_PERM_ROOT;
	} else {
		if (StringToIntEx(permissions, admin) != strlen(permissions)) {
			ReplyToCommand(client, "SUM: Usage: sum_setadmin <steamid> <permissions|none|light|default|full|root>");
			return Plugin_Handled;
		}
	}

	if (hDatabase == INVALID_HANDLE) {
		ReplyToCommand(client, "SUM: Error: No database connection, can't add admin.");
		return Plugin_Handled;
	}

	decl String:buffer[sizeof(auth)*2+1];
	SQL_QuoteString(hDatabase, auth, buffer, sizeof(buffer));

	decl String:newquery[150];

	if (databaseIdent == DBIdent_SQLite) {
		Format(newquery, sizeof(newquery), "INSERT OR IGNORE INTO client (admin, steamid) VALUES ('%d', '%s');", admin, buffer, DBPrio_High);
		SQL_TQuery(hDatabase, T_ignore, newquery);
		Format(newquery, sizeof(newquery), "UPDATE client SET admin = '%d' WHERE steamid = '%s';", admin, buffer);
		SQL_TQuery(hDatabase, T_ignore, newquery);
	}
	
	return Plugin_Handled;
}

public Action:OnBanClient(client, time, flags, const String:reason[], const String:kick_message[], const String:command[], any:source) {
	if (time > 10 || time == 0) {
		decl String:authtarget[STEAMID_LENGTH];
		GetClientAuthString(client, authtarget, sizeof(authtarget));

		executeGlobalBan(source, authtarget, time, reason);
		return Plugin_Handled;
	} else {
		return Plugin_Continue;
	}
}

public Action:OnBanIdentity(const String:identity[], time, flags, const String:reason[], const String:command[], any:source) {
	if ((time > 10 || time == 0) && (flags & BANFLAG_AUTHID)) {
		executeGlobalBan(source, identity, time, reason);

		return Plugin_Handled;
	} else {
		return Plugin_Continue;
	}
}

public Action:OnRemoveBan(const String:identity[], flags, const String:command[], any:source) {
	if ((flags & BANFLAG_AUTHID) && hDatabase != INVALID_HANDLE) {
		decl String:newquery[255];
		Format(newquery, sizeof(newquery), "UPDATE client SET banneduntil = '0' WHERE steamid = '%s';", identity);
		SQL_TQuery(hDatabase, T_ignore, newquery);

		ReplyToCommand(source, "SUM: Global ban removed.");
	}

	return Plugin_Continue;
}

executeGlobalBan(const client, const String:authtarget[], const time, const String:reason[]) {
	if (hDatabase != INVALID_HANDLE) {
		decl String:authcreator[STEAMID_LENGTH];
		if (client == 0 || !GetClientAuthString(client, authcreator, sizeof(authcreator))) {
			strcopy(authcreator, sizeof(authcreator), "UNKNOWN");
		}

		decl expiretime;
		if (time == 0) {
			expiretime = 2147483647; // signed int32 max
		} else {
			expiretime = GetTime() + time*60;
		}

		if (databaseIdent == DBIdent_SQLite) {
			decl String:newquery[200];
			Format(newquery, sizeof(newquery), "INSERT OR IGNORE INTO client (banneduntil, bancount, steamid) VALUES ('%d', '0', '%s');", expiretime, authtarget, DBPrio_High);
			SQL_TQuery(hDatabase, T_ignore, newquery);
			Format(newquery, sizeof(newquery), "UPDATE client SET banneduntil = '%d', bancount = bancount+1 WHERE steamid = '%s';", expiretime, authtarget);
			SQL_TQuery(hDatabase, T_ignore, newquery);
		}

		decl String:buffer[150];
		SQL_QuoteString(hDatabase, reason, buffer, sizeof(buffer));

		decl String:newquery[350];
		Format(newquery, sizeof(newquery), "INSERT INTO banlog (target, creator, time, duration, reason) VALUES ('%s', '%s', '%d', '%d', '%s');", authtarget, authcreator, GetTime(), time, buffer);
		SQL_TQuery(hDatabase, T_ignore, newquery);

		BanIdentity(authtarget, 10, BANFLAG_AUTHID, reason);

		ReplyToCommand(client, "SUM: Global ban executed.");
	}
}

checkSteamID(const userid, const String:auth[]) {
	decl String:newquery[255];
	Format(newquery, sizeof(newquery), "SELECT admin, banneduntil, connectcount FROM client WHERE steamid = '%s';", auth);
	SQL_TQuery(hDatabase, T_querySteamID, newquery, userid);
}
 
public T_querySteamID(Handle:db, Handle:query, const String:error[], any:data) {
	decl client;

	if ((client = GetClientOfUserId(data)) == 0) return;

	decl String:auth[STEAMID_LENGTH];
	GetClientAuthString(client, auth, sizeof(auth));
 
	if (query == INVALID_HANDLE) {
		LogError("SUM: Query failed! %s", error);
	} else if (SQL_GetRowCount(query)) {
		// user already in db

		if (SQL_FetchRow(query)) {
			new admin = SQL_FetchInt(query, 0);
			new banneduntil = SQL_FetchInt(query, 1);

			if (banneduntil > GetTime()) {
				KickClient(client, "SUM: You are banned from this server.");
			} else {
				insertClientName(client, auth);
			}
			
			if (admin) {
				SetUserFlagBits(client, GetUserFlagBits(client) | admin);
				PrintToConsole(client, "SUM: You have been given admin access.");
			}
		}
	} else {
		// user not in db

		decl String:newquery[255];
		Format(newquery, sizeof(newquery), "INSERT INTO client (steamid, connectcount, lastconnect) VALUES ('%s', '1', '%d');", auth, GetTime());
		SQL_TQuery(hDatabase, T_ignore, newquery);

		insertClientName(client, auth);
	}
}

insertClientName(const client, const String:auth[]) {
	decl String:name[MAX_NAME_LENGTH+1];

	if (GetClientName(client, name, sizeof(name))) {
		decl String:buffer[sizeof(name)*2+1];

		SQL_QuoteString(hDatabase, name, buffer, sizeof(buffer));
		
		if (databaseIdent == DBIdent_SQLite) {
			decl String:newquery[200];
			Format(newquery, sizeof(newquery), "INSERT OR IGNORE INTO clientname (steamid, name) VALUES ('%s', '%s');", auth, buffer);
			SQL_TQuery(hDatabase, T_ignore, newquery);
		}
	}
}

public T_queryAdmins(Handle:db, Handle:query, const String:error[], any:data) {
	decl client;

	if ((client = GetClientOfUserId(data)) == 0) return;

	displayAdminList(query, client);
}

public T_queryBanLog(Handle:db, Handle:query, const String:error[], any:data) {
	decl client;

	if ((client = GetClientOfUserId(data)) == 0) return;

	displayBanLog(query, client);
}

public T_ignore(Handle:owner, Handle:hndl, const String:error[], any:data) {
	if (hndl == INVALID_HANDLE) {
		LogError("SUM: Query failed! %s", error);
	}

	// nothing..
}

displayAdminList(Handle:query, client) {
	if (query == INVALID_HANDLE) {
		LogError("SUM: Query failed!");
	} else if (SQL_GetRowCount(query)) {
		if (GetCmdReplySource() == SM_REPLY_TO_CHAT) {
			ReplyToCommand(client, "SUM: See console for output.");
		}

		new ReplySource:oldReplySource = SetCmdReplySource(SM_REPLY_TO_CONSOLE);

		ReplyToCommand(client, "--- SUM adminlist:");

		while (SQL_FetchRow(query)) {
			decl String:auth[STEAMID_LENGTH];
			SQL_FetchString(query, 0, auth, sizeof(auth));
			decl String:name[MAX_NAME_LENGTH+1];
			SQL_FetchString(query, 1, name, sizeof(name));
			if (strlen(name) == 0) strcopy(name, sizeof(name), "?");
			decl String:adminStr[11];
			SQL_FetchString(query, 2, adminStr, sizeof(adminStr));
			new admin = StringToInt(adminStr);

			decl adminchr;

			switch (admin) {
				case ADM_PERM_LIGHT: {
					adminchr = 'L';
				}
				case ADM_PERM_DEFAULT: {
					adminchr = 'D';
				}
				case ADM_PERM_FULL: {
					adminchr = 'F';
				}
				case ADM_PERM_ROOT: {
					adminchr = 'R';
				}
				default: {
					adminchr = 'C';
				}
			}

			if (steamidInGame(auth)) {
				ReplyToCommand(client, "* %s - %c - %s", auth, adminchr, name);
			} else {
				ReplyToCommand(client, "  %s - %c - %s", auth, adminchr, name);
			}
		}

		ReplyToCommand(client, "--- %d Admins (limited to 100) - * = ingame", SQL_GetRowCount(query));

		SetCmdReplySource(oldReplySource);
	} else {
		ReplyToCommand(client, "SUM: No admins found");
	}
}

displayBanLog(Handle:query, client) {
	if (query == INVALID_HANDLE) {
		LogError("SUM: Query failed!");
	} else if (SQL_GetRowCount(query)) {
		if (GetCmdReplySource() == SM_REPLY_TO_CHAT) {
			ReplyToCommand(client, "SUM: See console for output.");
		}

		new ReplySource:oldReplySource = SetCmdReplySource(SM_REPLY_TO_CONSOLE);

		ReplyToCommand(client, "--- SUM banlog:");
		ReplyToCommand(client, "target | creator | date | duration | reason");

		while (SQL_FetchRow(query)) {
			decl String:target[STEAMID_LENGTH];
			SQL_FetchString(query, 0, target, sizeof(target));
			decl String:creator[STEAMID_LENGTH];
			SQL_FetchString(query, 1, creator, sizeof(creator));
			new time = SQL_FetchInt(query, 2);
			new duration = SQL_FetchInt(query, 3);
			decl String:reason[65];
			SQL_FetchString(query, 4, reason, sizeof(reason));

			decl String:date[11];
			FormatTime(date, sizeof(date), "%Y-%m-%d", time);

			ReplyToCommand(client, "%s | %s | %s | %d | %s", target, creator, date, duration, reason);
		}

		ReplyToCommand(client, "--- %d entries (limited to 100)", SQL_GetRowCount(query));

		SetCmdReplySource(oldReplySource);
	} else {
		ReplyToCommand(client, "SUM: No bans found");
	}
}

stock bool:steamidInGame(const String:auth[]) {
	new maxclients = GetMaxClients();
	decl String:authcmp[STEAMID_LENGTH];

	for (new client=1; client <= maxclients; client++) {
		if (IsClientInGame(client)) {
			GetClientAuthString(client, authcmp, sizeof(authcmp));

			if (StrEqual(auth, authcmp)) {
				return true;
			}
		}
	}

	return false;
}

stock isNumeric(const String:str[]) {
	new strLength = strlen(str);
	for (new i=0; i<strLength; i++) {
		if (!IsCharNumeric(str[i])) {
			return false;
		}
	}

	return true;
}
