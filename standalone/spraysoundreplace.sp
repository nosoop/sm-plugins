#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Global definitions
#define PLUGIN_VERSION "1.0.1"
#define MAX_FILE_LEN 80

// Path to custom 
#define REPLACEMENT_SPRAY_FILE "pikapoo/fart.wav"
#define DEFAULT_SPRAY_SOUND "player/sprayer.wav"

// Plugin information
public Plugin:myinfo =
{
    name = "[ALL] Custom spray sound",
    author = "nosoop",
    description = "Overrides the sound used when applying a spray.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/sm-plugins"
};

// Path to sound file.
new String:g_spraySoundReplacement[MAX_FILE_LEN] = REPLACEMENT_SPRAY_FILE;

// Plugin started
public OnPluginStart() {
    PrecacheAndDownloadSound(g_spraySoundReplacement);
    
    // Hook sound played event
    AddNormalSoundHook(SprayHook);
}

// Plugin started
public OnMapStart() {
    PrecacheSound(g_spraySoundReplacement, true);
}

PrecacheAndDownloadSound(String:var[]) {
    new String:buffer[MAX_FILE_LEN];
    PrecacheSound(var, true);
    Format(buffer, sizeof(buffer), "sound/%s", var);
    AddFileToDownloadsTable(buffer);
}


// Replace sound.
public Action:SprayHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags) {
    if(StrEqual(sample, DEFAULT_SPRAY_SOUND)) {
        sample = g_spraySoundReplacement;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}