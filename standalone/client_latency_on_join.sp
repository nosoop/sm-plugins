#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

public Plugin myinfo = {
	name = "High Latency Join Prevention",
	author = "nosoop",
	url = "https://forums.alliedmods.net/showthread.php?p=2385158#post2385158"
}

// 100ms
int nLatencyThreshold = 100;

public void OnClientPutInServer(int client) {
	if (!IsFakeClient(client)) {
		float flAvgLatency = GetClientAvgLatency(client, NetFlow_Outgoing);
		
		int nLatencyMsecs = RoundFloat(flAvgLatency * 1000);
		
		if (nLatencyMsecs > nLatencyThreshold) {
			LogMessage("Kicking client %N because of high ping (max %d, current %d)", client, nLatencyThreshold, nLatencyMsecs);
			KickClient(client, "reasons");
		} else {
			// LogMessage("Allowing client %N to join (max %d, current %d)", client, nLatencyThreshold, nLatencyMsecs);
		}
	}
}
