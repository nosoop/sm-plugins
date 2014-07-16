#if defined _autorecorder_mod_included
  #endinput
#endif
#define _autorecorder_mod_included

public SharedPlugin:__pl_autorecorder_mod = {
    name = "autorecorder-mod",
    file = "autorecorder-mod.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_autorecorder_mod_SetNTVOptional() {
    MarkNativeAsOptional("GetApproximateDemoTick");
}

/**
 * Gets the predicted current time of the demo in server ticks.  May be off.
 * 
 * @return                  The expected tick value at the time the method was called in the current demo.
 *                          -1 if no demo is being recorded.
 */
native GetApproximateDemoTick();