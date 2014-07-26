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
    MarkNativeAsOptional("Propify_PropPlayer");
    MarkNativeAsOptional("Propify_UnropPlayer");
    MarkNativeAsOptional("Propify_IsClientProp");
    MarkNativeAsOptional("Propify_SetThirdPersonOnProp");
    MarkNativeAsOptional("Propify_AddModelData");
    MarkNativeAsOptional("Propify_RemoveModelData");
    MarkNativeAsOptional("Propify_GetModelNamesArray");
    MarkNativeAsOptional("Propify_GetModelPathsArray");
    MarkNativeAsOptional("Propify_GetRandomPropIndex");
    MarkNativeAsOptional("Propify_RegisterConfigHandler");
    MarkNativeAsOptional("Propify_UnregisterConfigHandler");
    MarkNativeAsOptional("Propify_UnregisterConfigHandlers");
}

/**
 * Function to read the key / value pairs off a config in a registered section.
 * This way, you can put all your configuration data along with the rest of the prop lists.
 * Do note that if the method is registered late, the ConfigHandler will not be used until the next proplist reload.
 * 
 * @param key               A parsed key string.
 * @param value             A parsed value string.
 */
functag ConfigHandler public(const String:key[], const String:value[]);

/**
 * Called when a client is turned into a (possibly different) prop, or when they are unpropped.
 *
 * @param client            Client index.
 * @param propIndex         The prop the client was turned into, or -1 if not propped.
 * @noreturn
 */
forward Propify_OnPropified(client, propIndex);

/**
 * Called when the prop list has been cleared.
 * This is a signal for other plugins that are reading from the prop list to clear their stuff.
 */
forward Propify_OnPropListCleared();

/**
 * Called when the prop list has been cleared and populated.
 * Other plugins can start adding new props or readding.
 *
 * @noreturn
 */
forward Propify_OnPropListLoaded();

/**
 * Called when an external plugin has added a model to the list.
 * This is not called when Propify! adds its own models to the list.
 *
 * @param sModelName        The name of the model added.
 * @param sModelPath        The path of the model added.
 * @noreturn
 */
forward Propify_OnModelAdded(const String:sModelName[], const String:sModelPath[]);

/**
 * Called when an external plugin has removed a model from the list.
 * This is not called when Propify! clears and refreshes the model list.
 *
 * @param sModelName        The name of the model removed.
 * @param sModelPath        The path of the model removed.
 * @noreturn
 */
forward Propify_OnModelRemoved(const String:sModelName[], const String:sModelPath[]);


/**
 * Attempts to set a prop on a player.
 *
 * @param client            Client index.
 * @param propIndex         The prop to use.
 * @param forceThirdPerson  Whether or not to force third person mode.
 *                          (False if they are being propped at end-round.)
 * @return                  Index value of the prop the player is propped as, or -1 if not propped.
 */
native Propify_PropPlayer(client, propIndex = -1, bool:forceThirdPerson = true);

/**
 * Attempts to unprop a player.
 * 
 * @param client            Client index.
 * @param respawn           Whether or not removing the prop on the player should do an in-place respawn.
 *                          An in-place respawn returns the client's weapons.
 * @return                  Boolean noting that the client is now not a prop.
 */
native bool:Propify_UnpropPlayer(client, bool:respawn = false);

/**
 * Checks whether or not the specified client is currently a prop.
 *
 * @param client            Client index.
 * @return                  Boolean noting whether or not the client is a prop.
 */
native bool:Propify_IsClientProp(client);

/**
 * Adds a model to the prop list.
 * 
 * @param modelName         The visible name of the model.
 * @param modelPath         The path to the model file, starting with the models subdirectory.
 */
native Propify_AddModelData(const String:modelName[], const String:modelPath[]);

/**
 * Removes a model from the prop list.
 *
 * @param nModelIndex       The index of the prop to remove.
 */
 native Propify_RemoveModelData(nModelIndex);

/**
 * Gets the handle for the model name array for raw access.
 * Remember to sync additions and removals between the arrays.
 *
 * @return                  A Handle pointing to an adt_array containing model names.
 */
native Handle:Propify_GetModelNamesArray();

/**
 * Gets the handle for the model path array for raw access.
 * Remember to sync changes between the arrays.
 *
 * @return                  A Handle pointing to an adt_array containing model paths.
 */
native Handle:Propify_GetModelPathsArray();

/**
 * Calls GetRandomInt to return a random, valid prop index.
 *
 * @return                  A random integer representing a valid prop index.
 */
native Propify_GetRandomPropIndex();

/**
 * Attempts to register a ConfigHandler method to be fired when in a specified section of the prop config.
 * Fails to register if there is already a handler associated with the section name.
 * Remember to unregister them when unloading the plugin.
 *
 * @param sSection          The section name to handle.
 * @param sectionHandler    A ConfigHandler method to be called for the key/value pairs in the section.
 */
native Propify_RegisterConfigHandler(const String:sSection[], ConfigHandler:sectionHandler);

/**
 * Attempts to unregister a ConfigHandler method associated with the specified section name.
 * Fails if the plugin did not register the section.
 *
 * @param sSection          The section name to unregister.
 */
native Propify_UnregisterConfigHandler(const String:sSection[]);

/**
 * Unregisters all ConfigHandler methods associated with the calling plugin.
 */
native Propify_UnregisterConfigHandlers();