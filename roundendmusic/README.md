# Round End Music
A custom plugin to play music after a round of TF2 gameplay with support for multiple music sources.

## Round End Music (Core Plugin) -- roundendsongs.sp
The core plugin, handling playing the song at endround and requesting songs from supporting plugins.

### Configurable in two cvars:
* `sm_rem_enabled` determines whether the plugin will play songs.
* `sm_rem_maxsongs` determines how many songs will be queued up, added to the download table and song list, and played during the map.

### Commands available to clients:
* `sm_songlist` opens a menu showing the current songs active.  Selecting a song plays it on the client.
* `sm_songvolume` sets the volume to play songs at, or mutes them entirely.

### Notes.
Requires clientprefs.  Hopefully someday it won't be necessary, but for now it is.

## Round End Music (SQLite) -- roundendsongs-sqlite.sp
Provides songs from an SQLite database in a specific format.  (Originally developed for my own server.)

TODO Details.

## Round End Music (Flat File) -- roundendsongs-flatfile.sp
Provides songs from a flat file.  No configuration needed through SourceMod.

### Installation
Install the compiled plugin.  Create a text file at `addons/sourcemod/data/roundendsongs.txt` with the following:
```
"roundendsongs" {
  "path/to/sound/file.mp3" {
    "title" "Song Title"
    "artist" "Song Artist"
  }
}
```
