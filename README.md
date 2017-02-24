sm-plugins
==========

A collection of custom SourceMod plugins.  Some heavily modified from elsewhere, some stripped down, some for testing, others not.

~~Released under the MIT license, unless noted in the source otherwise.  
Licensing issues, if any arise, may be raised in the issue tracker.~~

(Apparently, SourceMod-derivative projects must be GPL.  Whoops!  I write plugins; I don't speak legalese.  I'll fix that all soon enough, but consider everything GPL'd.)

If you feel that my contibutions or new creations are valuable, feel free to donate:  
`bitcoin://18XJamtPHg3LHb5HA4vd9dFX9cqH2VVS3k`

## Migrated projects
I've stopped using this repository to hold all of my SourceMod projects, opting to create individual plugin repositories instead.  If a new plugin has been put up that fulfills the purpose of one in this repository, the latter will be deleted and the replacements will be linked to below:

* **Bot Map Overrides**:  Replaced by my [Bot Map Runner](https://github.com/nosoop/SM-TFBotMapRunner) plugin.
* **Extended Map Configs** (fork):  Replaced by my [Yet Another Map Config Plugin](https://github.com/nosoop/SM-YetAnotherMapConfigPlugin)
* **AllChat** (SCP-compatible fork):  Practically obsoleted by my custom implementation of [Simple Chat Processor](https://git.csrd.science/nosoop/CSRD-SimpleChatProcessor), as well as the addition of `tf_gravetalk`.  It was a total kludge anyways; not worth using.
* **Building Glow**:  Proof-of-concept was fully realized with my [Building Radar](https://github.com/nosoop/SM-TFBuildingRadar) plugin.
* **Hitsounds for Buildings** (fork):  Obsoleted by a TF2 update that made it a built-in feature.
* **Get Download Filter** library:  Replaced with a [function stock](https://github.com/nosoop/stocksoup/blob/master/download_filter_query.inc) that can be integrated standalone into a plugin.
* **Round End Music**:  [I made a full revision of this system](http://git.csrd.science/nosoop/CSRD-RoundEndMusic), which has effectively been scrapped before release with a private streaming version.
