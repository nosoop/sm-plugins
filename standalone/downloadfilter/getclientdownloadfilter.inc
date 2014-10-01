#if defined _getclientdownloadfilter_included
  #endinput
#endif
#define _getclientdownloadfilter_included

#define DOWNLOADFILTER_NONE     (0 << 0)    // No downloads allowed.
#define DOWNLOADFILTER_MAPS     (1 << 0)    // Maps.
#define DOWNLOADFILTER_SOUNDS   (1 << 1)    // Sounds.
#define DOWNLOADFILTER_MISC     (1 << 2)    // Other content not defined.
#define DOWNLOADFILTER_ALL      0xFF        // All downloads allowed.

/**
 * Global forward fired when the download filter for the client is updated.
 * This is fired initially at some point after OnClientPostAdminCheck() is
 * called on the client.
 */
forward OnClientDownloadFilterFlagsSet(iClient, flags);

/**
 * Gets a client's download preference.
 * 
 * @return                  A 8-bit bitmask specifying which types of files
 *                          this client is able to download.
 */
native GetClientDownloadFilterFlags(iClient);

/**
 * Shared plugin data
 */
public __pl_getclientdownloadfilter_SetNTVOptional() {
    MarkNativeAsOptional("GetClientDownloadFilterFlags");
}

public SharedPlugin:__pl_getclientdownloadfilter = {
    name = "clientdownloadfilters",
    file = "getclientdownloadfilter.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
