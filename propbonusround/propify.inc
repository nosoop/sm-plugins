#if defined _propify_included
  #endinput
#endif
#define _propify_included

public SharedPlugin:__pl_propify = {
    name = "nosoop-propify",
    file = "propify.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#define PROP_NO_CUSTOM_SPEED    0           // Special value of sm_propbonus_forcespeed that disables the speed override.
                                            // (Keep unchanged as 0 isn't a valid speed anyways.)

#define PROP_RANDOM             -1          // Value for an unspecified prop to force a player into.
#define PROP_RANDOM_TOGGLE      -2          // Value to turn a player into a random prop or to turn them out of a prop.

public __pl_propify_SetNTVOptional() {
    MarkNativeAsOptional("PropPlayer");
    MarkNativeAsOptional("UnropPlayer");
    MarkNativeAsOptional("IsClientProp");
    MarkNativeAsOptional("SetThirdPersonOnProp");
}

/**
 * Attempts to set a prop on a player.
 *
 * @param client            Client index.
 * @param propIndex         The prop to use.
 * @param forceThirdPerson  Whether or not to force third person mode.
 *                          (False if they are being propped at end-round.)
 * @return                  Index value of the prop the player is propped as, or -1 if not propped.
 */
native PropPlayer(client, propIndex = -1, bool:forceThirdPerson = true);

/**
 * Attempts to unprop a player.
 * 
 * @param client        Client index.
 * @param respawn       Whether or not removing the prop on the player should do an in-place respawn.
 *                      An in-place respawn returns the client's weapons.
 * @return              Boolean noting that the client is now not a prop.
 */
native bool:UnpropPlayer(client, bool:respawn = false);

/**
 * Checks whether or not the specified client is currently a prop.
 *
 * @param client        Client index.
 * @return              Boolean noting whether or not the client is a prop.
 */
native bool:IsClientProp(client);