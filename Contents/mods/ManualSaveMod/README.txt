Manual Save & Slot Manager
==========================

A manual save mod for Project Zomboid B42.
Save and restore named slots without overwriting your current game.

LINKS
  Steam  : https://steamcommunity.com/sharedfiles/filedetails/?id=3721602150
  GitHub : https://github.com/pingotumbo/ManualSaveMod
  Reddit : https://www.reddit.com/r/projectzomboid/comments/1t6ntyq/b42_i_finally_finished_the_manual_save_mod_i/

SETUP
  Open the subfolder for your operating system inside the mod folder and
  start the Watcher launcher. Keep the Watcher window open while you play.

    Windows           : Windows/ManualSave_Watcher.cmd     (double-click)
    macOS             : MacOS/ManualSave_Watcher.command   (double-click)
    Linux/Steam Deck  : Linux/ManualSave_Watcher.command   (see below)

  macOS:
    Just double-click ManualSave_Watcher.command. Terminal.app opens and
    runs the script.

  Linux / Steam Deck (Desktop Mode), first time only:
    Open a terminal in the Linux/ folder and run:
        chmod +x ManualSave_Watcher.command
    (Or right-click > Properties > Permissions > "Allow executing as program".)
    From then on the file can be started by double-click.

  Steam Deck (Gaming Mode):
    Gaming Mode cannot double-click files. To use the mod there:
      1. In Desktop Mode, open Steam.
      2. Games > Add a Non-Steam Game to my Library.
      3. Browse and pick MacOS/ManualSave_Watcher.command (on Deck use
         Linux/ManualSave_Watcher.command after the chmod above).
      4. Return to Gaming Mode.
      5. In Gaming Mode launch the Watcher from your Steam library BEFORE
         launching Project Zomboid. Both must be running together.

CUSTOM ZOMBOID FOLDER
  The default Zomboid folder is:
    Windows : C:\Users\<you>\Zomboid  (%USERPROFILE%\Zomboid)
    Linux   : ~/Zomboid               (e.g. /home/<you>/Zomboid)
    macOS   : ~/Zomboid

  If yours is on a different drive or path, the Watcher will ask you to enter
  the correct path the first time it starts. Type the path and press Enter,
  it will be saved for future sessions.

  To change the path later, edit ManualSave_UserDir.txt inside the same
  operating-system subfolder and restart the Watcher.

NOTES FOR LINUX / STEAM DECK / macOS
  - The Watcher needs Python 3, which is preinstalled on Ubuntu, SteamOS,
    Fedora and macOS.
  - Save thumbnails are not captured on these systems in this release. Saves
    still work normally; slots show the default "no thumbnail" tile instead.
  - Steam Deck: works out of the box in Desktop Mode. To use it from Gaming
    Mode, add the watcher .sh to Steam as a Non-Steam game (one-time setup).
