#if defined _zonemod_included
  #endinput
#endif
#define _zonemod_included

public SharedPlugin:__pl_zonemod = {
    name = "zonemod",
    file = "zonemod.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_zonemod_SetNTVOptional() {
    MarkNativeAsOptional("Zone_Create");
    MarkNativeAsOptional("Zone_Remove");
}

/**
 * Creates a zone if it doesn't exist.
 *
 * @param sZoneName         The identifying name for the zone to be added.
 * @param vCoords1          A coordinate vector for one vertex of the zone to be created.
 * @param vCoords2          A coordinate vector for the other vertex of the zone to be created.
 * @return                  Entity of the created zone, entity of a zone with the specified name,
 *                          or -1 if the zone could not be created.
 */
native Zone_Create(const String:sZoneName[], const Float:vStartVertex[3], const Float:vEndVertex[3]);

/**
 * Removes a zone if it exists.
 *
 * @param sZoneName         The identifying name for the zone to be removed.
 * @return                  True if a zone was removed, false otherwise.
 */
native Zone_Remove(const String:sZoneName[]);
