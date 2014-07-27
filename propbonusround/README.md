# Propify! and Co.
Originally forked off from Prop Bonus Round to implement some minor improvements and fixes, it's grown into something somewhat large.

### How to Install
First off, compile Propify! with your basic SourceMod compiler.  It doesn't require any third-party dependencies.  
Drop it into your plugins folder and load.  Same with all the other plugins.

## Propify!
Propify! is a highly expandable Team Fortress 2 SourceMod plugin.  Many features have been abstracted and exposed for other plugins to use.

### Commands
* `sm_prop <target> <propindex>` Turns a player(s) into a prop or unprops them.  Prop index is determined by which order the props are loaded.
* `sm_propify_reloadlist` Reloads the prop lists.  By default, you need to have root access.

### Variables
* `sm_propify_enabled` Whether or not the plugin is enabled.
* `sm_propify_forcespeed` Forces a specific speed on a prop.
* `sm_propify_killentifunhidable` If any unhidable entities should be removed on propped players by killing said entities.  Unhidables are mainly hats that could possibly have particle effects applied.  If enabled, wearables may be slightly buggy.  If disabled, particle effects may show on props.

### Configuring
Go into `/sourcemod/data/propify/` and take a look at the `base.txt` file.  The config is parsed by the SourceMod Config parser, which uses a format similar to Valve's KeyValues.
```
"config-name-this-doesnt-actually-matter" {
    "proplist" {
        // Contains the default key/value prop list.  Same as the old Prop Bonus Round.
        "Model name"    "models/path/to/prop/file.mdl"
    }
    "includes" {
        // Contains values referring to other prop lists to load.
        "Any name"      "base_name_of_prop_file_without_txt"

        // You can load prop lists from other maps, if you're feeling like a total bastard.
        "y u do dis?"   "koth_rainbow_b6"

        "nope"          "base"
    }
}
```
Multiple includes, yes?  Here's some more info:
*  base.txt is always loaded first.
*  A file corresponding to the map name is also always loaded next.
*  Any files listed in the "includes" subkey from the previous files are added to the list of files to load, provided they haven't been added already.  No recursion here.
*  Most other subkeys are ignored unless they are registered.

Once you're done editing, run `sm_propify_reloadlist` in console to clear the prop list and load your changes.

## Bonus Round
The Prop Bonus Round-specific plugin code has been made separate from Propify!  The original supporting plugin; it turns the losing team into props for the enemy team to find.

### Variables
* `sm_propbonus_enabled` Whether or not the bonus round involves turning players into props.
* `sm_propbonus_adminonly` Whether or not only players with a certain admin flag can be turned into props.  *Not confirmed to be working now.*
* `sm_propbonus_flag` The admin flag players must have to be propped during humiliation.  *Not confirmed to be working, either.*
* `sm_propbonus_announcement` Announce the Propifying to everyone in chat and to the propped players in the center of the screen.
* `sm_propbonus_damageglow` Whether or not damaged players glow, making the search easier for the winning team.
* `sm_propbonus_forcespawn` Whether or not dead players on the losing team are respawned and turned into props.

### Configuring
Prop Bonus Round supports an extra section in the map-specific config.
```
// Spawn position.  Dead props get respawned at one of the following locations if any exist.
"spawnpos" {
    // The key represents position coordinates, in space-delimited float values.
    // The value represents the pitch and yaw angles in that order, also in space-delimited floats.
    "-1019 1022 -20"  "0 -45"  // Example spawn location at koth_nucleus
}
```

## Ghost Fix
A simple patch plugin that disables a spooky glow effect that occurs when certain props are used.  This fix isn't included in Propify! as to keep the code clean from hardcoded values.  You might not even use any of the props affected, which would make it kinda pointless.

## Propify! Plus
An extension to Propify! intended for those admins that just enjoy turning players into props so much for some reason.

### Commands
* `sm_prop_persist <target> <0|1>` Makes the target keep their prop between lives.  Can also be called by `sm_propp`.  
* `sm_propbyname <target> <propname>` Props a player, using the first prop index containing the specified propname substring, so you don't have to memorize indices that may change when prop lists update.  Can also be called by `sm_propn`.

### Target Filters
* `@props` Targets all propped players.
* `@!props` Targets all not-propped players.

# Propify! API
Propify! can be extended to work with other plugins that want to turn players into props.

The documentation is pretty good (and all the other sub-plugins use it themselves), so refer to the [include file](https://github.com/nosoop/sm-plugins/blob/master/propbonusround/propify.inc) to see how you can work Propify! into your own plugins.
