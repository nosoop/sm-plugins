#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <downloadprefs>

#define PLUGIN_VERSION          "1.2.0"

public Plugin:myinfo = {
    name = "[ALL] Custom Spray Sound (with Download Preferences)",
    author = "nosoop",
    description = "Overrides the sound used when applying a spray.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
};

#define REPLACEMENT_SPRAY_FILE  "pikapoo/fart.wav"
#define DEFAULT_SPRAY_SOUND     "player/sprayer.wav"
#define DOWNLOADPREFS_LIBRARY 	"downloadprefs"

#define SPRAY_DOWNLOADED_BY_DEFAULT false

new bool:g_bDPrefsLoaded = false,
	g_iDPref;
new bool:clientsDownloaded[MAXPLAYERS+1];

public OnPluginStart() {
    AddNormalSoundHook(SprayHook);
}

public OnMapStart() {
    new String:buffer[PLATFORM_MAX_PATH];

    PrecacheSound(REPLACEMENT_SPRAY_FILE, true);
    
    Format(buffer, sizeof(buffer), "sound/%s", REPLACEMENT_SPRAY_FILE);
    AddFileToDownloadsTable(buffer);
}

public OnClientPutInServer(iClient) {
	clientsDownloaded[iClient] = g_bDPrefsLoaded ? GetClientDownloadPreference(iClient, g_iDPref) : SPRAY_DOWNLOADED_BY_DEFAULT;
}

public Action:SprayHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags) {
    if (StrEqual(sample, DEFAULT_SPRAY_SOUND)) {
		new rgEnabled[64], nEnabled,
			rgDisabled[64], nDisabled;
		
		// Sort clients based on if they have the custom sound enabled or not.
		for (new i = 0; i < numClients; i++) {
			if (clientsDownloaded[clients[i]]) {
				rgEnabled[nEnabled++] = clients[i];
			} else {
				rgDisabled[nDisabled++] = clients[i];
			}
		}
		
		if (nEnabled > 0) {
			EmitSound(rgEnabled, nEnabled, REPLACEMENT_SPRAY_FILE, entity, channel, level, flags, volume, pitch);
		}
		if (nDisabled > 0) {
			EmitSound(rgDisabled, nDisabled, DEFAULT_SPRAY_SOUND, entity, channel, level, flags, volume, pitch);
		}
		return Plugin_Stop;
    }
    return Plugin_Continue;
}

public OnAllPluginsLoaded() {
	new bool:bLastState = g_bDPrefsLoaded;
	OnDPrefsStateCheck((g_bDPrefsLoaded = LibraryExists(DOWNLOADPREFS_LIBRARY)) != bLastState);
}

public OnLibraryRemoved(const String:name[]) {
	new bool:bLastState = g_bDPrefsLoaded;
	OnDPrefsStateCheck((g_bDPrefsLoaded &= !StrEqual(name, DOWNLOADPREFS_LIBRARY)) != bLastState);
}

public OnLibraryAdded(const String:name[]) {
	new bool:bLastState = g_bDPrefsLoaded;
	OnDPrefsStateCheck((g_bDPrefsLoaded |= StrEqual(name, DOWNLOADPREFS_LIBRARY)) != bLastState);
}

public OnDPrefsStateCheck(bHasChanged) {
	if (bHasChanged) {
		if (g_bDPrefsLoaded) {
			g_iDPref = RegClientDownloadCategory("Spray Sound Replacement", "Because fart noises are the epitome of maturity.", SPRAY_DOWNLOADED_BY_DEFAULT);
			
			new String:buffer[PLATFORM_MAX_PATH];
			Format(buffer, sizeof(buffer), "sound/%s", REPLACEMENT_SPRAY_FILE);
			RegClientDownloadFile(g_iDPref, buffer);
			
			for (new i = MaxClients; i > 0; --i) {
				if (IsClientInGame(i)) {
					OnClientPutInServer(i);
				}
			}
		}
	}
}
