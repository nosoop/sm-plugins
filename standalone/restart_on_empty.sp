#include <sourcemod>

Handle g_RestartTimer;

// #define SECONDS_TO_RESTART 1.0 * 60 * 20
#define SECONDS_TO_RESTART 1.0 * 60 * 1

public void OnPluginStart() {
	HookEvent("player_connect", OnPlayerConnect);
	HookEvent("player_disconnect", OnPlayerDisconnect);
}

// If the last human player disconnects, then set a 20 minute timer until it restarts.
public void OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	bool bDisconnectingHuman = event.GetInt("bot") == 0;
	
	if (bDisconnectingHuman) {
		bool bAnyHumanConnected = false;
		bool bAnyBotsConnected = false;
		
		int disconnectingClient = GetClientOfUserId(event.GetInt("userid"));
		for (int i = MaxClients; i > 0; --i) {
			if (i == disconnectingClient) {
				continue;
			}
			
			bAnyHumanConnected |= (IsClientConnected(i) && !IsFakeClient(i));
			
			// Could always change the checks as necessary, depending on the bot.
			bAnyBotsConnected |= (IsClientConnected(i) && IsFakeClient(i)
					&& IsPlayingBot(i));
		}
		
		PrintToServer("Human %d disconnected, state %b / %b", disconnectingClient, bAnyHumanConnected, bAnyBotsConnected);
		
		if (!bAnyHumanConnected && RestartTimerEnabled()) {
			g_RestartTimer = CreateTimer(SECONDS_TO_RESTART, OnServerEmptyTooLong);
			LogMessage("Server is empty and bots are available.  Starting timer for %f seconds.", SECONDS_TO_RESTART);
		}
	}
}

// If a human player connects, kill an existing restart timer if possible.
public void OnPlayerConnect(Event event, const char[] name, bool dontBroadcast) {
	bool bConnectingHuman = event.GetInt("bot") == 0;
	int client = event.GetInt("index");
	
	// client 0, world
	if (!client) {
		return;
	}
	
	if (bConnectingHuman) {
		if (g_RestartTimer != null) {
			delete g_RestartTimer;
			LogMessage("Player joined server.  Timer killed.");
		}
	} else if (RestartTimerEnabled()) {
		// Make sure this is an actual playing bot.
		if (!IsPlayingBot(client)) {
			return;
		}
		
		bool bAnyHumanConnected = false;
		
		for (int i = MaxClients; i > 0; --i) {
			bAnyHumanConnected |= (IsClientConnected(i) && !IsFakeClient(i));
		}
		
		if (!bAnyHumanConnected && g_RestartTimer == null) {
			g_RestartTimer = CreateTimer(SECONDS_TO_RESTART, OnServerEmptyTooLong);
			LogMessage("Server is empty and a bot has connected.  Starting timer for %f seconds.", SECONDS_TO_RESTART);
		}
	}
}

bool RestartTimerEnabled() {
	// Add time-based checks here.
	return true;
}

bool IsPlayingBot(int client) {
	return !IsClientSourceTV(client) && !IsClientReplay(client);
}

// Server has not killed the timer that was set 20 minutes ago.	 Time to restart.
public Action OnServerEmptyTooLong(Handle timer, any data) {
	LogMessage("Server has been empty for %f seconds.  Restarting.", SECONDS_TO_RESTART);
	ServerCommand("quit"); // I assume you have your server configured to restart on shutdown.
}