#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION          "1.0.2"

public Plugin:myinfo = {
    name = "[ALL] Custom Spray Sound",
    author = "nosoop",
    description = "Overrides the sound used when applying a spray.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
};

#define MAX_FILE_LEN            80

#define REPLACEMENT_SPRAY_FILE  "pikapoo/fart.wav"
#define DEFAULT_SPRAY_SOUND     "player/sprayer.wav"

public OnPluginStart() {
    AddNormalSoundHook(SprayHook);
}

public OnMapStart() {
    new String:buffer[MAX_FILE_LEN];

    PrecacheSound(REPLACEMENT_SPRAY_FILE, true);
    
    Format(buffer, sizeof(buffer), "sound/%s", REPLACEMENT_SPRAY_FILE);
    AddFileToDownloadsTable(buffer);
}

public Action:SprayHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags) {
    if (StrEqual(sample, DEFAULT_SPRAY_SOUND)) {
        sample = REPLACEMENT_SPRAY_FILE;
        return Plugin_Changed;
    }
    return Plugin_Continue;
}