#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

public Plugin myinfo = {
	name = "High Latency Join Prevention",
	author = "nosoop",
	url = "https://forums.alliedmods.net/showthread.php?p=2385158#post2385158"
}

ConVar g_LatencyThreshold;

public void OnPluginStart() {
	g_LatencyThreshold = CreateConVar("sm_latency_threshold", "100",
			"Maximum latency (in ms) before a player is kicked.", _,
			true, 0.0);
}

public void OnClientPutInServer(int client) {
	if (!IsFakeClient(client)) {
		int nLatencyMsecs = RoundFloat(GetClientAvgLatency(client, NetFlow_Outgoing) * 1000);
		
		if (nLatencyMsecs > g_LatencyThreshold.IntValue) {
			LogMessage("Kicking client %N because of high ping (max %d, current %d)",
					client, g_LatencyThreshold.IntValue, nLatencyMsecs);
			KickClient(client, "reasons");
		} else {
			// LogMessage("Allowing client %N to join (max %d, current %d)", client, g_LatencyThreshold.IntValue, nLatencyMsecs);
		}
	}
}

// TODO sample player latency during game, if they are consistently below threshold then log accountid
// also log IP address for whitelisting?
