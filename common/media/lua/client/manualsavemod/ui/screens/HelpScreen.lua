-- UI/Screens/HelpScreen.lua
-- Help overlay: left nav (scrollable, categories + pages), right scrollable content.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, undefined-field

ManualSave = ManualSave or {}

local _screen      = nil
local _section     = "start"
local _navScrollTo = nil

local W, H  = 680, 500
local NAV_W = 200

-- ── Page content ───────────────────────────────────────────────────────────────
-- Line format: { "text", "style" }
-- Styles: header | sub | body | dim | warn | good
--         callout | callout_w | callout_g   (left-bar info/warn/good)
--         check                             (checklist item, > bullet)
--         gloss_t | gloss_d                 (glossary term / definition)
--         ""                                (vertical gap)

-- GETTING STARTED ──────────────────────────────────────────────────────────────

local function start_lines()
    return {
        { "Manual Save Mod  v1.0.0",                                   "dim"       },
        { "",                                                                       },
        { "WHAT YOU GET",                                              "header"    },
        { "Multiple named save slots per world.",                      "body"      },
        { "Quick Save — instant in-game checkpoint.",                  "body"      },
        { "Full Save — exit to menu, flush all state, reload.",        "body"      },
        { "Rename, duplicate, delete, and import vanilla saves.",      "body"      },
        { "Auto thumbnail screenshot for every save.",                 "body"      },
        { "",                                                                       },
        { "REQUIREMENTS",                                              "header"    },
        { "Windows 10 or 11",                                          "sub"       },
        { "The Watcher uses cmd.exe, robocopy, PowerShell,",           "body"      },
        { "and user32.dll — all standard Windows components.",         "body"      },
        { "",                                                                       },
        { "Build 42 only",                                             "sub"       },
        { "The Lua API on B41 differs; the mod will not load",         "body"      },
        { "cleanly on that version.",                                  "body"      },
        { "",                                                                       },
        { "SETUP — STEP BY STEP",                                      "header"    },
        { "1. Subscribe on Steam and let it install",                  "sub"       },
        { "Mod folder: Steam/steamapps/workshop/content/",             "dim"       },
        { "108600/<workshop_id>/mods/ManualSaveMod/",                  "dim"       },
        { "",                                                                       },
        { "2. Enable the mod in your save",                            "sub"       },
        { "Main menu > Mods > Manual Save Mod [B42] > enable.",        "body"      },
        { "For an existing world: also enable from the world",         "body"      },
        { "mod list before loading.",                                  "body"      },
        { "",                                                                       },
        { "3. Locate ManualSave_Watcher.bat",                          "sub"       },
        { "ManualSave_Watcher.bat   — the background process.",        "body"      },
        { "ManualSave_Screenshot.ps1 — used by the watcher.",          "body"      },
        { "",                                                                       },
        { "4. Start the Watcher",                                      "sub"       },
        { "Double-click ManualSave_Watcher.bat.",                      "body"      },
        { "A console window flashes briefly then hides itself.",       "body"      },
        { "Leave it running in the background, then start PZ.",        "body"      },
        { "Pin a shortcut on your desktop for convenience.",           "dim"       },
        { "",                                                                       },
        { "5. Confirm it is talking to the game",                      "sub"       },
        { "In game: ESC > Save. All buttons should be enabled",        "body"      },
        { "and the dot at the top reads 'Watcher running'.",           "body"      },
        { "Red dot = .bat is not running. Double-click it again.",     "warn"      },
        { "",                                                                       },
        { "FROM HERE",                                                 "header"    },
        { "Save > Quick Save  — fast in-game checkpoint.",             "body"      },
        { "Save > Full Save   — reliable end-of-session save.",        "body"      },
        { "Load               — manage and restore saves.",            "body"      },
        { "Reference > Glossary — unfamiliar terms explained.",        "body"      },
        { "Troubleshooting    — if something does not work.",          "body"      },
    }
end

local function safety_lines()
    return {
        { "SHORT ANSWER",                                              "header"    },
        { "Yes. The mod ships an open .bat and a .ps1 script,",       "body"      },
        { "both plain text, both readable in Notepad.",               "body"      },
        { "Nothing in the mod has network access.",                   "callout"   },
        { "Nothing modifies the PZ executable.",                      "callout"   },
        { "Uninstall returns your saves to vanilla state.",           "callout"   },
        { "",                                                                       },
        { "WHAT THE WATCHER ACTUALLY DOES",                           "header"    },
        { "On a 500ms loop it does four things:",                     "body"      },
        { "1. Reads small .txt signal files from Zomboid/Lua/.",      "body"      },
        { "2. Copies, moves, or deletes folders in Zomboid/",         "body"      },
        { "   using robocopy.",                                        "body"      },
        { "3. Runs PowerShell to capture the game window.",           "body"      },
        { "4. Writes a Done file back so the game sees the result.",  "body"      },
        { "",                                                                       },
        { "No registry edits.",                                        "dim"       },
        { "No external network calls.",                                "dim"       },
        { "No background services or autostart.",                      "dim"       },
        { "",                                                                       },
        { "HOW TO VERIFY THIS YOURSELF",                              "header"    },
        { "Open ManualSave_Watcher.bat in Notepad.",                  "check"     },
        { "Open ManualSave_Screenshot.ps1 in Notepad.",               "check"     },
        { "Task Manager > Details: Watcher = cmd.exe with",           "check"     },
        { "  the .bat path in the command line.",                      "dim"       },
        { "Resource Monitor > Network: no sockets opened.",           "check"     },
        { "",                                                                       },
        { "WHY ANTIVIRUS MAY FLAG IT",                                "header"    },
        { "Some AVs flag any unsigned .bat that calls",               "body"      },
        { "robocopy + PowerShell — a heuristic, not a real",          "body"      },
        { "detection of malicious behaviour.",                        "body"      },
        { "",                                                                       },
        { "Read the file first, then decide.",                        "callout"   },
        { "If you don't trust it: don't run it.",                     "callout"   },
        { "Lua side stays disabled; PZ behaves as vanilla.",          "callout"   },
        { "",                                                                       },
        { "Both files are byte-identical across all Steam",           "callout_g" },
        { "Workshop installs of the same mod version.",               "callout_g" },
    }
end

-- WATCHER ──────────────────────────────────────────────────────────────────────

local function watcher_what_lines()
    return {
        { "WHY THE WATCHER EXISTS",                                   "header"    },
        { "PZ runs Lua through Kahlua, a stripped interpreter.",      "body"      },
        { "Kahlua hides almost the entire os.* library:",             "body"      },
        { "no os.execute, os.rename, os.remove, no mkdir.",           "dim"       },
        { "",                                                                       },
        { "A manual save is a folder copy. Lua inside PZ",           "callout"   },
        { "cannot do that. The Watcher is the smallest",             "callout"   },
        { "possible workaround: an external Windows process.",        "callout"   },
        { "",                                                                       },
        { "WHAT IT DOES",                                             "header"    },
        { "SAVE        Copy active world to a named slot.",           "body"      },
        { "LOAD        Copy a slot back to the active world.",        "body"      },
        { "DELETE      Recursively remove a slot folder.",            "body"      },
        { "RENAME      Rename a slot folder.",                        "body"      },
        { "CLONE       Copy a slot to a new name.",                   "body"      },
        { "RENAME_WORLD   Rename the world folder itself.",           "body"      },
        { "STRIP_MODS     Wipe mods.txt in a slot.",                  "body"      },
        { "SCAN_VANILLA   List existing vanilla saves.",              "body"      },
        { "IMPORT      Copy vanilla saves into ManualSave.",          "body"      },
        { "SCREENSHOT     Capture PZ window as thumbnail.",           "body"      },
        { "",                                                                       },
        { "HOW IT TALKS TO THE GAME",                                 "header"    },
        { "The Watcher polls %USERPROFILE%\\Zomboid\\Lua\\",          "body"      },
        { "for ManualSave_Signal.txt written by the Lua side.",       "body"      },
        { "Parses the op > runs it > writes Done.txt back.",         "body"      },
        { "A heartbeat counter increments every tick so the",        "dim"       },
        { "game can detect if the Watcher process dies.",             "dim"       },
        { "",                                                                       },
        { "No install, no service, no autostart.",                    "callout"   },
        { "If you don't start the .bat the mod is inert.",           "callout"   },
        { "This keeps the install trivially reversible.",             "callout"   },
    }
end

local function watcher_run_lines()
    return {
        { "STARTING IT MANUALLY",                                     "header"    },
        { "Double-click ManualSave_Watcher.bat.",                     "body"      },
        { "A console window flashes briefly, then hides itself.",     "body"      },
        { "The Watcher is now running in the background.",            "body"      },
        { "",                                                                       },
        { "WHERE THE FILE IS",                                        "header"    },
        { "Steam\\steamapps\\workshop\\content\\108600\\",            "body"      },
        { "<workshop_id>\\mods\\ManualSaveMod\\",                    "body"      },
        { "ManualSave_Watcher.bat",                                   "sub"       },
        { "ManualSave_Screenshot.ps1  (used by the Watcher)",        "dim"       },
        { "",                                                                       },
        { "You can also find it from the Mods screen in PZ:",        "dim"       },
        { "Mods > Manual Save Mod > Open Folder.",                   "dim"       },
        { "",                                                                       },
        { "DESKTOP SHORTCUT",                                         "header"    },
        { "Right-click ManualSave_Watcher.bat > Send to >",          "body"      },
        { "Desktop (create shortcut).",                               "body"      },
        { "",                                                                       },
        { "START IT WITH THE GAME (RECOMMENDED)",                     "header"    },
        { "Create a launcher.bat with these lines:",                  "body"      },
        { "  @echo off",                                               "dim"       },
        { "  start /min ManualSave_Watcher.bat",                      "dim"       },
        { "  start steam://run/108600",                               "dim"       },
        { "",                                                                       },
        { "Double-click that launcher instead of PZ directly.",       "body"      },
        { "The Watcher boots first, then the game does.",             "dim"       },
        { "",                                                                       },
        { "RUN ON LOGIN (OPTIONAL)",                                  "header"    },
        { "Win+R > type shell:startup > Enter.",                      "body"      },
        { "Drop a shortcut to ManualSave_Watcher.bat there.",        "body"      },
        { "The Watcher now starts every time you log in.",            "body"      },
        { "Only useful if you play PZ frequently.",                   "dim"       },
        { "",                                                                       },
        { "HOW TO STOP IT",                                           "header"    },
        { "Task Manager > Details > find cmd.exe with",              "body"      },
        { "ManualSave_Watcher in the command > End task.",            "body"      },
        { "",                                                                       },
        { "Watcher cleans up its lock file on clean close.",          "dim"       },
        { "If it crashes the lock may persist.",                      "dim"       },
        { "See Troubleshooting > Watcher won't start.",               "dim"       },
    }
end

-- SAVE ─────────────────────────────────────────────────────────────────────────

local function quicksave_lines()
    return {
        { "WHAT IT IS",                                               "header"    },
        { "An instant copy of the active save folder taken",         "body"      },
        { "without leaving the game. The world keeps running",       "body"      },
        { "while the copy happens in the background.",               "body"      },
        { "",                                                                       },
        { "Use Quick Save sparingly. Full Save is the right",        "callout_w" },
        { "choice in most situations — see Save > Full Save.",       "callout_w" },
        { "",                                                                       },
        { "WHAT THE MOD DOES — STEP BY STEP",                        "header"    },
        { "1. Screenshot request written for the Watcher.",          "body"      },
        { "   Watcher runs ManualSave_Screenshot.ps1:",              "dim"       },
        { "   calls PrintWindow(PW_RENDERFULLCONTENT).",             "dim"       },
        { "   DWM compositor renders GPU frame to a bitmap.",        "dim"       },
        { "   No focus change, no display mode switch.",             "dim"       },
        { "   If PrintWindow fails: falls back to CopyFromScreen.",  "dim"       },
        { "2. Lua waits for screenshot confirmation on each frame.", "body"      },
        { "   Timeout: 300 frames (~5 sec) if Watcher is slow.",    "dim"       },
        { "3. Metadata collected (world, date, play time...).",      "body"      },
        { "4. SAVE signal sent to the Watcher.",                     "body"      },
        { "   Watcher: robocopy world folder to slot folder.",       "dim"       },
        { "   Watcher: thumbnail saved to ManualSave_Thumbs/.",      "dim"       },
        { "   Watcher: calculates size, appends SIZE + DATE.",       "dim"       },
        { "5. Done signal received — UI shows confirmation.",        "body"      },
        { "   The game keeps running throughout.",                   "body"      },
        { "",                                                                       },
        { "WHAT IS NOT FULLY CAPTURED",                              "header"    },
        { "Quick Save copies what is on disk. PZ flushes",           "callout_w" },
        { "lazily — the copied state is 'recent past',",             "callout_w" },
        { "not 'this exact frame'.",                                  "callout_w" },
        { "",                                                                       },
        { "Zombie positions",                                         "sub"       },
        { "Not flushed mid-game. On reload zombies may be",          "body"      },
        { "in different positions, including next to you.",          "warn"      },
        { "",                                                                       },
        { "Distant chunks",                                           "sub"       },
        { "Chunks far from the player may be outdated.",             "body"      },
        { "",                                                                       },
        { "Weather and time of day",                                  "sub"       },
        { "Live in memory. Reloaded value is whatever was",          "body"      },
        { "last flushed, which may differ from on-screen.",          "body"      },
        { "",                                                                       },
        { "WHEN TO USE IT",                                           "header"    },
        { "Before a risky move you may want to undo.",               "body"      },
        { "Testing a mod or craft where zombie drift is OK.",        "body"      },
        { "",                                                                       },
        { "PREFER FULL SAVE WHEN",                                   "header"    },
        { "Logging off for the night.",                              "body"      },
        { "Before installing or removing mods.",                     "body"      },
        { "When zombie positions and weather must match.",           "body"      },
    }
end

local function fullsave_lines()
    return {
        { "WHAT IT IS",                                               "header"    },
        { "A save that exits to the main menu, lets PZ flush",       "body"      },
        { "all in-memory state to disk, then copies the",            "body"      },
        { "consistent folder to a backup slot.",                     "body"      },
        { "",                                                                       },
        { "The only save type guaranteed to capture",                 "callout"   },
        { "the full world state.",                                    "callout"   },
        { "",                                                                       },
        { "THE TWO OPTIONS",                                          "header"    },
        { "Save & Exit",                                              "sub"       },
        { "Saves, returns to the main menu, stays there.",           "body"      },
        { "Use when you actually want to stop playing.",             "body"      },
        { "",                                                                       },
        { "1. Screenshot captured via PrintWindow (DWM compositor).", "dim"      },
        { "   No display mode switch, no focus change.",             "dim"       },
        { "2. Metadata + Pending.txt written (REENTER=0).",          "dim"       },
        { "3. SAVE signal sent to Watcher; game quits.",             "dim"       },
        { "   Watcher waits 1 sec for PZ to flush state to disk.",   "dim"       },
        { "   robocopy world folder to slot folder.",                "dim"       },
        { "4. Main menu shown. Nothing else happens.",               "dim"       },
        { "",                                                                       },
        { "Save & Return",                                            "sub"       },
        { "Saves, returns to menu briefly, then immediately",        "body"      },
        { "reloads the world. Reliable as Full Save.",               "body"      },
        { "",                                                                       },
        { "1. Screenshot captured (same as Save & Exit).",           "dim"       },
        { "2. Metadata + Pending.txt written (REENTER=1).",          "dim"       },
        { "3. SAVE signal sent to Watcher; game quits.",             "dim"       },
        { "   Watcher: 1 sec wait, robocopy, Done signal.",          "dim"       },
        { "4. Main menu loads: Pending.txt read (REENTER=1).",       "dim"       },
        { "   World and game mode set from Pending.txt.",            "dim"       },
        { "   Game immediately loads the just-saved slot.",          "dim"       },
        { "   No button press needed.",                              "dim"       },
        { "",                                                                       },
        { "DISPLAY MODE CAVEAT",                                      "header"    },
        { "Save & Return calls quit() then re-enters the world.",    "body"      },
        { "In exclusive fullscreen the GPU display mode swaps",      "warn"      },
        { "twice — some drivers leave the screen blank/stuck.",      "warn"      },
        { "",                                                                       },
        { "Options > Display > Borderless Windowed.",                "callout_g" },
        { "The compositor handles the round-trip cleanly.",          "callout_g" },
        { "",                                                                       },
        { "WHAT IS CAPTURED",                                         "header"    },
        { "Everything: player, inventory, world, every chunk,",      "body"      },
        { "all zombies, weather, in-game clock.",                    "body"      },
        { "Thumbnail is captured before the quit.",                  "body"      },
        { "",                                                                       },
        { "WHEN TO USE IT",                                           "header"    },
        { "Default to Full Save — it is the only trustworthy",       "callout"   },
        { "backup. Cost: time to exit and re-enter the world.",      "callout"   },
        { "",                                                                       },
        { "End of session, the before-bed save.",                    "body"      },
        { "Before any mod change.",                                  "body"      },
        { "Before Strip Mods or Rename World operations.",           "body"      },
        { "Any time there is no specific reason for Quick Save.",    "body"      },
    }
end

local function thumbnail_lines()
    return {
        { "WHAT IT IS",                                               "header"    },
        { "A screenshot taken automatically on every Save,",         "body"      },
        { "displayed in the Load and More screens.",                 "body"      },
        { "",                                                                       },
        { "WHERE IT APPEARS",                                         "header"    },
        { "Load screen — detail panel on the right.",                "body"      },
        { "More screen — banner across the top.",                    "body"      },
        { "",                                                                       },
        { "WHERE THUMBNAILS ARE STORED",                              "header"    },
        { "Zomboid\\Saves\\ManualSave_Thumbs\\<slot>.png",           "body"      },
        { "The Watcher manages this folder automatically:",          "dim"       },
        { "creates on save, renames on rename, deletes on delete.",  "dim"       },
        { "",                                                                       },
        { "WHY THEY CANNOT LEAVE Zomboid\\Saves\\",                  "header"    },
        { "PZ's only runtime texture loader (getTextureFromSaveDir)","body"      },
        { "can read exclusively from inside Zomboid/Saves/.",        "body"      },
        { "Relative paths (../) are explicitly blocked by PZ.",      "dim"       },
        { "No filesystem path API exists in PZ's Lua runtime.",      "dim"       },
        { "ManualSave_Thumbs/ inside Saves/ is the only",           "callout"   },
        { "location PZ will let Lua load images from.",              "callout"   },
        { "",                                                                       },
        { "HOW IT IS CAPTURED",                                       "header"    },
        { "PZ runs OpenGL. Classic BitBlt returns a black",          "body"      },
        { "rectangle for OpenGL windows.",                           "dim"       },
        { "",                                                                       },
        { "The Watcher calls a PowerShell script that uses",         "body"      },
        { "PrintWindow(PW_RENDERFULLCONTENT). That asks the",        "body"      },
        { "Windows compositor (DWM) to composite GPU contents",      "body"      },
        { "into a normal bitmap. Works in windowed and",             "body"      },
        { "borderless modes without stealing focus.",                "body"      },
        { "",                                                                       },
        { "If capture fails a placeholder dark PNG is written",      "dim"       },
        { "by PowerShell with a 'Manual Save' label.",               "dim"       },
    }
end

-- LOAD ─────────────────────────────────────────────────────────────────────────

local function loadscreen_lines()
    return {
        { "OPENING IT",                                               "header"    },
        { "In game:        ESC > Load Save.",                        "body"      },
        { "From main menu: Load Manual Save.",                       "body"      },
        { "",                                                                       },
        { "THE SAVE LIST",                                            "header"    },
        { "Every manual save listed on the left, sortable",          "body"      },
        { "by Date, Name, or Size.",                                 "body"      },
        { "Click a save to select it and see its thumbnail",         "body"      },
        { "and metadata on the right.",                              "body"      },
        { "",                                                                       },
        { "Sorting",                                                  "sub"       },
        { "Click Date / Name / Size to switch sort field.",          "body"      },
        { "Click the active button again to flip direction.",        "body"      },
        { "",                                                                       },
        { "Search",                                                   "sub"       },
        { "Type to filter by slot name or world name.",              "body"      },
        { "",                                                                       },
        { "LOADING A SAVE",                                           "header"    },
        { "Three ways to load the selected save:",                   "body"      },
        { "- Click LOAD SAVE button (bottom right).",                "check"     },
        { "- Double-click the save in the list.",                    "check"     },
        { "- Press Enter.",                                          "check"     },
        { "",                                                                       },
        { "Requires Watcher to be running.",                         "callout_w" },
        { "All three methods are disabled when the Watcher",         "callout_w" },
        { "dot is red. Start the .bat file first.",                  "callout_w" },
        { "",                                                                       },
        { "KEYBOARD SHORTCUTS",                                       "header"    },
        { "Enter    Load the selected save (Watcher required).",     "body"      },
        { "F2       Rename the selected save.",                      "body"      },
        { "Del      Open the delete confirmation.",                  "body"      },
        { "Esc      Close the screen.",                              "body"      },
    }
end

local function more_lines()
    return {
        { "WHAT IT IS",                                               "header"    },
        { "An expanded view of a single save, opened with",          "body"      },
        { "the More button on the Load screen.",                     "body"      },
        { "",                                                                       },
        { "LEFT COLUMN — METADATA",                                   "header"    },
        { "Save File",                                                "sub"       },
        { "Game mode, save type (Quick/Full/Native),",               "body"      },
        { "last saved date, playtime, size on disk.",                "body"      },
        { "",                                                                       },
        { "World State",                                              "sub"       },
        { "World folder name, current in-game day, seed.",           "body"      },
        { "",                                                                       },
        { "Map and Mods",                                             "sub"       },
        { "Compact lists with an expand icon.",                      "body"      },
        { "Click to open a scrollable floating panel,",             "body"      },
        { "useful when a save has 60+ mods.",                        "body"      },
        { "",                                                                       },
        { "RIGHT COLUMN — ACTIONS",                                   "header"    },
        { "Save Actions",                                             "sub"       },
        { "Rename Save, Duplicate.",                                 "body"      },
        { "",                                                                       },
        { "World Actions",                                            "sub"       },
        { "Rename World, Strip Mods.",                               "body"      },
        { "These touch the folder shared by all slots.",             "dim"       },
        { "See World ops pages for caveats.",                        "dim"       },
        { "",                                                                       },
        { "Recovery Flags",                                           "sub"       },
        { "One-time modifiers applied on the next load.",            "body"      },
        { "See Recovery > Flags for full explanation.",              "dim"       },
    }
end

local function duplicate_lines()
    return {
        { "WHAT IT DOES",                                             "header"    },
        { "Creates an independent full-folder copy of the",          "body"      },
        { "selected save. The original is untouched.",               "body"      },
        { "",                                                                       },
        { "DEFAULT NAMING",                                           "header"    },
        { "First copy:  MySlot_copy",                                "body"      },
        { "If taken:    MySlot_copy_(2)",                            "body"      },
        { "Then:        MySlot_copy_(3) and so on.",                 "body"      },
        { "The dialog pre-fills the next free name.",                "dim"       },
        { "Type any name you prefer before confirming.",             "dim"       },
        { "",                                                                       },
        { "DISK COST",                                                "header"    },
        { "A duplicate is a full folder copy.",                      "callout_w" },
        { "200 MB save = +200 MB on disk. Use deliberately.",        "callout_w" },
        { "",                                                                       },
        { "USEFUL COMBOS",                                            "header"    },
        { "Duplicate before risky moves (NPC raids, events).",       "body"      },
        { "Duplicate then Strip Mods: a no-mods snapshot",           "body"      },
        { "you can boot if a future PZ patch breaks a mod.",        "body"      },
    }
end

local function rename_lines()
    return {
        { "WHAT IT DOES",                                             "header"    },
        { "Renames the slot folder on disk.",                        "body"      },
        { "The new name is what the Load screen displays.",          "body"      },
        { "",                                                                       },
        { "NAME RULES",                                               "header"    },
        { "Names are sanitized automatically.",                      "body"      },
        { "Spaces become underscores.",                              "dim"       },
        { "Characters invalid in Windows paths are replaced",        "dim"       },
        { "with _  (< > : \" / \\ | ? *)",                          "dim"       },
        { "Unicode allowed; avoid emoji for compatibility.",         "dim"       },
        { "",                                                                       },
        { "SHORTCUTS",                                                "header"    },
        { "F2     Open rename dialog for selected save.",            "body"      },
        { "Esc    Cancel without renaming.",                         "body"      },
        { "Enter  Confirm.",                                         "body"      },
        { "",                                                                       },
        { "RENAME vs RENAME WORLD",                                   "header"    },
        { "Rename changes only the slot folder.",                    "body"      },
        { "The world folder and its name in PZ stay the same.",      "body"      },
        { "To rename the world: World ops > Rename World.",          "dim"       },
    }
end

local function delete_lines()
    return {
        { "WHAT IT DOES",                                             "header"    },
        { "Permanently removes the slot folder and thumbnail.",      "body"      },
        { "",                                                                       },
        { "There is no recycle bin.",                                 "callout_w" },
        { "Once confirmed, the data is gone.",                       "callout_w" },
        { "",                                                                       },
        { "CONFIRMATION",                                             "header"    },
        { "A dialog asks before deleting.",                          "body"      },
        { "You must explicitly confirm to proceed.",                 "body"      },
        { "",                                                                       },
        { "SCOPE",                                                    "header"    },
        { "Only the selected slot is removed.",                      "body"      },
        { "Other slots in the same world stay intact.",              "body"      },
        { "Vanilla saves in Zomboid/Saves/ are never touched.",      "body"      },
    }
end

local function import_lines()
    return {
        { "WHAT IT DOES",                                             "header"    },
        { "Brings existing vanilla saves (Zomboid/Saves/) into",     "body"      },
        { "the ManualSave system so they appear alongside",          "body"      },
        { "manual saves and can be renamed, duplicated, etc.",       "body"      },
        { "",                                                                       },
        { "The originals are not moved or deleted.",                  "callout"   },
        { "Import is a copy.",                                        "callout"   },
        { "",                                                                       },
        { "WHEN IT IS AVAILABLE",                                     "header"    },
        { "Main menu only.",                                          "callout_w" },
        { "Import is disabled in-game because scanning",             "callout_w" },
        { "Zomboid/Saves/ requires no world to be locked.",          "callout_w" },
        { "",                                                                       },
        { "THE FLOW",                                                 "header"    },
        { "1. Click Import. Watcher scans Zomboid/Saves/.",          "body"      },
        { "2. Import screen shows every vanilla world found,",       "body"      },
        { "   grouped by game mode. Already-imported: marked.",      "body"      },
        { "3. Tick the worlds you want and confirm.",                "body"      },
        { "4. Watcher copies each one. Entries appear in list.",     "body"      },
        { "",                                                                       },
        { "WHAT YOU GET",                                             "header"    },
        { "Each imported world becomes one slot whose name",         "body"      },
        { "matches the world name.",                                 "body"      },
        { "Mod list is parsed from the world's mods.txt.",           "body"      },
        { "Map list and thumbnail fill lazily on first load.",       "dim"       },
    }
end

-- WORLD OPS ────────────────────────────────────────────────────────────────────

local function renameworld_lines()
    return {
        { "WHAT IT DOES",                                             "header"    },
        { "Renames the world folder under",                          "body"      },
        { "ManualSaves/<gmode>/<world>/.",                           "body"      },
        { "Every slot inside that world is now grouped under",       "body"      },
        { "the new world name.",                                     "body"      },
        { "",                                                                       },
        { "Different from Rename, which changes only one slot.",     "dim"       },
        { "",                                                                       },
        { "WHEN TO USE IT",                                           "header"    },
        { "You imported a world named something generic",            "body"      },
        { "(Sandbox_2026-04-22) and want a meaningful name.",        "body"      },
        { "You spawned with a typo in the world name and want",      "body"      },
        { "to fix it once, not per slot.",                           "body"      },
        { "",                                                                       },
        { "CAVEATS",                                                  "header"    },
        { "Cannot rename while that world is loaded.",               "callout_w" },
        { "The folder must be free of locks.",                       "callout_w" },
        { "Go to main menu before renaming.",                        "callout_w" },
        { "",                                                                       },
        { "All slots reload metadata after the rename.",             "dim"       },
        { "Thumbnails persist.",                                     "dim"       },
    }
end

local function stripmods_lines()
    return {
        { "WHAT IT DOES",                                             "header"    },
        { "Empties the mods.txt of a slot so the next load",         "body"      },
        { "does not require any of the original mods.",              "body"      },
        { "",                                                                       },
        { "WHY YOU MIGHT WANT THIS",                                  "header"    },
        { "A mod the world needs was broken by a PZ patch.",         "body"      },
        { "A mod was removed from Workshop and is gone.",            "body"      },
        { "Recovering character state without the full mod list.",   "body"      },
        { "",                                                                       },
        { "WHAT IT DOES NOT DO",                                      "header"    },
        { "Not a clean migration.",                                   "callout_w" },
        { "Mods that added custom items, recipes, traits, or",       "callout_w" },
        { "vehicles will appear broken on load.",                    "callout_w" },
        { "The save loads; mod-added content may not behave.",       "callout_w" },
        { "",                                                                       },
        { "SAFER PATTERN: DUPLICATE + STRIP",                         "header"    },
        { "1. Select the slot.",                                     "body"      },
        { "2. Duplicate it — original is untouched.",                "body"      },
        { "3. Strip Mods on the duplicate.",                         "body"      },
        { "4. Load the clone to inspect.",                           "body"      },
        { "Your original slot stays mod-bound.",                     "dim"       },
    }
end

-- RECOVERY ─────────────────────────────────────────────────────────────────────

local function recovery_lines()
    return {
        { "WHAT THEY ARE",                                            "header"    },
        { "One-shot modifiers attached to a specific slot.",         "body"      },
        { "Take effect once on the next Load with Flags,",           "body"      },
        { "then cleared.",                                           "body"      },
        { "",                                                                       },
        { "Once applied, cannot be undone except by reloading",      "callout_w" },
        { "an earlier backup. Duplicate first.",                     "callout_w" },
        { "",                                                                       },
        { "AVAILABLE FLAGS",                                          "header"    },
        { "Wipe zombies",                                             "sub"       },
        { "Strips zombie data from chunk files before load.",        "body"      },
        { "Useful if zombies are corrupted or blocking spawn.",      "dim"       },
        { "Status: experimental. Test on a clone first.",            "warn"      },
        { "",                                                                       },
        { "Reset player position",                                    "sub"       },
        { "Teleports character to the world spawn point.",           "body"      },
        { "Useful if stuck in an unreachable area.",                 "dim"       },
        { "",                                                                       },
        { "Heal player",                                              "sub"       },
        { "Restores health, clears injuries and infections.",        "body"      },
        { "Mood debuffs persist.",                                   "dim"       },
        { "",                                                                       },
        { "Reset weather",                                            "sub"       },
        { "Clears weather state to clear sky.",                      "body"      },
        { "",                                                                       },
        { "Reset time of day",                                        "sub"       },
        { "Sets clock to a preset (Dawn / Midday / Dusk).",          "body"      },
        { "Day count and calendar are not affected.",                "dim"       },
        { "",                                                                       },
        { "HOW TO APPLY",                                             "header"    },
        { "Select a save > More > tick flags > Load with Flags.",    "body"      },
        { "Normal Load button does NOT apply flags.",                "warn"      },
    }
end

-- TROUBLESHOOTING ──────────────────────────────────────────────────────────────

local function trouble_lines()
    return {
        { "'WATCHER OFFLINE' RED BAR",                                "header"    },
        { "The Watcher is not running or has crashed.",              "body"      },
        { "Double-click ManualSave_Watcher.bat.",                    "check"     },
        { "Wait 2 seconds. The bar should disappear.",               "check"     },
        { "If it stays red: see Watcher won't start below.",         "check"     },
        { "",                                                                       },
        { "WATCHER WON'T START",                                      "header"    },
        { "Most common cause: stale .lock file from a crash.",       "body"      },
        { "Open %USERPROFILE%\\Zomboid\\Lua\\",                      "check"     },
        { "Delete ManualSave_Watcher.lock.",                         "check"     },
        { "Double-click the .bat again.",                            "check"     },
        { "",                                                                       },
        { "Other causes:",                                            "dim"       },
        { "PowerShell execution policy blocked the script.",         "dim"       },
        { "Antivirus quarantined the .bat or .ps1 file.",            "dim"       },
        { "Windows in S Mode (cannot run unsigned .bat).",           "dim"       },
        { "",                                                                       },
        { "THUMBNAIL IS BLACK OR PLACEHOLDER",                        "header"    },
        { "Running PZ in exclusive fullscreen?",                     "check"     },
        { "  Switch to Borderless Windowed: Options > Display.",      "dim"       },
        { "Windows version < 8.1?",                                  "check"     },
        { "  PrintWindow(PW_RENDERFULLCONTENT) needs Win 8.1+.",      "dim"       },
        { "PZ window minimized when saving?",                        "check"     },
        { "  Keep it visible; compositor needs an active surface.",  "dim"       },
        { "",                                                                       },
        { "A SAVE IS MISSING FROM THE LIST",                          "header"    },
        { "Is the Watcher running?",                                 "check"     },
        { "Check Zomboid\\Lua\\ManualSave_Index.txt.",               "check"     },
        { "Slot in Index but not in UI: close/reopen Load screen.",  "dim"       },
        { "Slot not in Index: folder moved outside mod. Use Import.", "dim"       },
        { "",                                                                       },
        { "SAVE & RETURN BREAKS THE DISPLAY",                         "header"    },
        { "Exclusive fullscreen + display mode swap on reload.",     "body"      },
        { "Fix: Options > Display > Borderless Windowed.",           "body"      },
        { "",                                                                       },
        { "PZ FREEZES DURING A SAVE",                                 "header"    },
        { "robocopy on a large save can take several seconds.",      "body"      },
        { "Wait 10 seconds before assuming a freeze.",               "body"      },
        { "If truly frozen: Task Manager > kill the Watcher",       "body"      },
        { "cmd.exe, then resume PZ and restart the Watcher.",        "body"      },
    }
end

-- REFERENCE ────────────────────────────────────────────────────────────────────

local function limits_lines()
    return {
        { "PLATFORM",                                                 "header"    },
        { "Windows only. cmd.exe, robocopy, PowerShell, and",        "body"      },
        { "user32.dll have no working substitutes on Linux/macOS",   "body"      },
        { "without rewriting the Watcher entirely.",                 "body"      },
        { "",                                                                       },
        { "WHAT QUICK SAVE MISSES",                                   "header"    },
        { "PZ flushes to disk lazily, so:",                          "body"      },
        { "Zombie positions are typically stale or partial.",        "body"      },
        { "Distant chunks may be in an outdated state.",             "body"      },
        { "Weather and time of day may not match on-screen.",        "body"      },
        { "For fully consistent state: use Full Save.",              "dim"       },
        { "",                                                                       },
        { "THE WATCHER IS A SEPARATE PROCESS",                        "header"    },
        { "Forgetting to start the .bat disables all operations.",   "body"      },
        { "The Lua side will not auto-launch the Watcher —",         "dim"       },
        { "that would break the trivially-uninstall guarantee.",     "dim"       },
        { "",                                                                       },
        { "FILESYSTEM ENCODING",                                      "header"    },
        { "Slot names go through Windows path rules.",               "body"      },
        { "Emoji, RTL chars, and some CJK sequences may be",         "dim"       },
        { "sanitized to _.",                                         "dim"       },
        { "",                                                                       },
        { "RECOVERY FLAGS STATUS",                                    "header"    },
        { "Wipe zombies: experimental.",                             "warn"      },
        { "Reset time of day: stable.",                              "good"      },
        { "Reset player pos / Heal / Reset weather:",               "body"      },
        { "  implemented but lightly tested.",                        "dim"       },
        { "",                                                                       },
        { "SAVE SIZE",                                                "header"    },
        { "Each backup is a full folder copy.",                      "body"      },
        { "Late-game worlds: 200–500 MB per slot.",                  "body"      },
        { "Delete pruned slots periodically.",                       "dim"       },
    }
end

local function locations_lines()
    return {
        { "WHERE THE MOD LIVES",                                      "header"    },
        { "Steam/steamapps/workshop/content/108600/",                "body"      },
        { "<workshop_id>/mods/ManualSaveMod/",                       "body"      },
        { "Top of that folder: Watcher.bat, Screenshot.ps1,",        "dim"       },
        { "mod.info.",                                                "dim"       },
        { "",                                                                       },
        { "WHERE BACKUPS LIVE",                                        "header"    },
        { "%USERPROFILE%\\Zomboid\\ManualSaves\\",                    "body"      },
        { "    <gmode>\\<world>\\<slot>\\",                           "body"      },
        { "Each slot folder: world snapshot + thumb.png.",           "dim"       },
        { "",                                                                       },
        { "WHERE VANILLA SAVES LIVE",                                  "header"    },
        { "%USERPROFILE%\\Zomboid\\Saves\\<gmode>\\<world>\\",        "body"      },
        { "Untouched by ManualSave except Import (read only).",      "dim"       },
        { "",                                                                       },
        { "WHERE THE BUS FILES LIVE",                                  "header"    },
        { "%USERPROFILE%\\Zomboid\\Lua\\   (all start ManualSave_)",  "body"      },
        { "",                                                                       },
        { "Signal.txt      Lua > Watcher: command to run.",          "body"      },
        { "Done.txt        Watcher > Lua: result.",                  "body"      },
        { "Heartbeat.txt   Watcher liveness counter.",               "body"      },
        { "Watcher.lock    Single-instance lock.",                   "body"      },
        { "Index.txt       Cached list of all slots.",               "body"      },
        { "VanillaScan.txt  Vanilla save list for Import.",          "body"      },
        { "ImportQueue.txt  Worlds queued for import.",              "body"      },
        { "Pending.txt     Save & Return re-entry info.",            "body"      },
        { "Meta_*.txt      Per-slot metadata.",                      "body"      },
        { "Flags_*.txt     Per-slot recovery flags.",                "body"      },
        { "",                                                                       },
        { "THUMBNAILS",                                               "header"    },
        { "%USERPROFILE%\\Zomboid\\Saves\\ManualSave_Thumbs\\",      "body"      },
        { "<slot>.png  (one file per save slot)",                    "body"      },
        { "Managed by Watcher. Cannot be relocated: PZ's",          "dim"       },
        { "texture API only reads from inside Zomboid/Saves/.",      "dim"       },
    }
end

local function glossary_lines()
    return {
        { "Slot",                                                      "gloss_t"   },
        { "Named manual backup. Folder at",                           "gloss_d"   },
        { "ManualSaves/<gmode>/<world>/<slot>/.",                     "gloss_d"   },
        { "Multiple slots can belong to the same world.",             "gloss_d"   },
        { "",                                                                       },
        { "World",                                                     "gloss_t"   },
        { "A PZ world folder (Sandbox/Riverside, etc.).",             "gloss_d"   },
        { "Contains chunks, zombie data, weather, seed.",             "gloss_d"   },
        { "",                                                                       },
        { "Game mode (gmode)",                                         "gloss_t"   },
        { "PZ game mode group: Sandbox, Apocalypse,",                "gloss_d"   },
        { "Survivor, Builder, Custom.",                               "gloss_d"   },
        { "",                                                                       },
        { "Watcher",                                                   "gloss_t"   },
        { "The external Windows process (Watcher.bat) that",          "gloss_d"   },
        { "performs file operations Lua cannot.",                     "gloss_d"   },
        { "",                                                                       },
        { "Signal / Done",                                             "gloss_t"   },
        { "Small .txt files in Zomboid/Lua/ used to pass",           "gloss_d"   },
        { "commands and results between Lua and Watcher.",            "gloss_d"   },
        { "",                                                                       },
        { "Heartbeat",                                                 "gloss_t"   },
        { "A counter the Watcher increments every tick.",             "gloss_d"   },
        { "If it stops changing, the game knows Watcher died.",       "gloss_d"   },
        { "",                                                                       },
        { "Quick Save",                                                "gloss_t"   },
        { "Instant in-game backup. Fast but state held only",         "gloss_d"   },
        { "in memory (zombies, weather) may not match.",              "gloss_d"   },
        { "",                                                                       },
        { "Full Save",                                                 "gloss_t"   },
        { "Backup that exits to main menu so PZ flushes",             "gloss_d"   },
        { "everything before the copy. Slower, fully consistent.",    "gloss_d"   },
        { "",                                                                       },
        { "Save & Return",                                             "gloss_t"   },
        { "Full Save that auto-reloads the slot it just saved.",      "gloss_d"   },
        { "Works best in Borderless Windowed display mode.",          "gloss_d"   },
        { "",                                                                       },
        { "Strip Mods",                                                "gloss_t"   },
        { "Empties a slot's mods.txt so it loads without",            "gloss_d"   },
        { "the original mods. Mod-added content may break.",          "gloss_d"   },
        { "",                                                                       },
        { "Recovery Flag",                                             "gloss_t"   },
        { "One-shot modifier for a slot. Applied once on",            "gloss_d"   },
        { "Load with Flags, then cleared automatically.",             "gloss_d"   },
        { "",                                                                       },
        { "Index",                                                     "gloss_t"   },
        { "Flat list of all slots, rebuilt by the Watcher",           "gloss_d"   },
        { "whenever slots change. Drives the Load screen.",           "gloss_d"   },
        { "",                                                                       },
        { "Thumbnail",                                                 "gloss_t"   },
        { "PNG screenshot (thumb.png) inside each slot.",             "gloss_d"   },
        { "Captured via PrintWindow(PW_RENDERFULLCONTENT).",          "gloss_d"   },
    }
end

-- LINKS ────────────────────────────────────────────────────────────────────────

local function links_lines()
    return {
        { "STEAM WORKSHOP",                                           "header"    },
        { "Search Manual Save Mod [B42] on the Steam Workshop",      "body"      },
        { "for updates, changelogs, and to leave a rating.",         "body"      },
        { "",                                                                       },
        { "BUG REPORTS",                                              "header"    },
        { "If you hit a bug, please include:",                       "body"      },
        { "What you were doing (screen, button).",                   "body"      },
        { "The console log — press F11 in-game to copy it.",         "body"      },
        { "Whether the Watcher was running.",                        "body"      },
        { "Your Windows version and PZ display mode.",               "body"      },
        { "",                                                                       },
        { "WHERE TO POST",                                            "header"    },
        { "Workshop comments — fastest, public, indexed.",           "body"      },
        { "GitHub issues — for reproducible bugs with logs.",        "body"      },
        { "Link to GitHub is in the Workshop description.",          "dim"       },
    }
end

-- ── Navigation structure ───────────────────────────────────────────────────────

local CATEGORIES = {
    { id="start",   label="Getting Started", pages={
        { id="start",       label="First time setup", lines=start_lines       },
        { id="safety",      label="Is this safe?",    lines=safety_lines      },
    }},
    { id="watcher", label="Watcher", pages={
        { id="watcher",     label="What it is",       lines=watcher_what_lines },
        { id="watcher_run", label="Convenience",      lines=watcher_run_lines  },
    }},
    { id="save",    label="Save", pages={
        { id="quicksave",   label="Quick Save",       lines=quicksave_lines   },
        { id="fullsave",    label="Full Save",        lines=fullsave_lines    },
        { id="thumbnail",   label="Thumbnail",        lines=thumbnail_lines   },
    }},
    { id="load",    label="Load", pages={
        { id="loadscreen",  label="Load screen",      lines=loadscreen_lines  },
        { id="more",        label="More screen",      lines=more_lines        },
        { id="duplicate",   label="Duplicate",        lines=duplicate_lines   },
        { id="rename",      label="Rename",           lines=rename_lines      },
        { id="delete",      label="Delete",           lines=delete_lines      },
        { id="import",      label="Import vanilla",   lines=import_lines      },
    }},
    { id="worldops",label="World ops", pages={
        { id="renameworld", label="Rename World",     lines=renameworld_lines },
        { id="stripmods",   label="Strip Mods",       lines=stripmods_lines   },
    }},
    { id="recovery",label="Recovery", pages={
        { id="recovery",    label="Flags",            lines=recovery_lines    },
    }},
    { id="trouble", label="Troubleshooting", pages={
        { id="trouble",     label="Common issues",    lines=trouble_lines     },
    }},
    { id="ref",     label="Reference", pages={
        { id="limits",      label="Known limits",     lines=limits_lines      },
        { id="locations",   label="File locations",   lines=locations_lines   },
        { id="glossary",    label="Glossary",         lines=glossary_lines    },
    }},
    { id="links",   label="Links", pages={
        { id="links",       label="Mod page",         lines=links_lines       },
    }},
}

-- ── Helpers ────────────────────────────────────────────────────────────────────

local function activeLines()
    for _, cat in ipairs(CATEGORIES) do
        for _, page in ipairs(cat.pages) do
            if page.id == _section then return page.lines() end
        end
    end
    return {}
end


local function currentPageLabel()
    for _, cat in ipairs(CATEGORIES) do
        for _, page in ipairs(cat.pages) do
            if page.id == _section then return page.label end
        end
    end
    return ""
end

local function currentCatLabel()
    for _, cat in ipairs(CATEGORIES) do
        for _, page in ipairs(cat.pages) do
            if page.id == _section then return cat.label end
        end
    end
    return ""
end

local function navSubtitle()
    return "> " .. currentCatLabel() .. " > " .. currentPageLabel()
end

-- ── UI builder ─────────────────────────────────────────────────────────────────

function ManualSave.openHelpScreen(section)
    if section then _section = section end
    if _screen then
        if section then
            _screen.setSubtitle(navSubtitle())
            if _navScrollTo then _navScrollTo(_section) end
        end
        _screen.panel:bringToTop()
        return
    end

    local d  = ManualSave.makeFloatingPanel({
        w=W, h=H, title="Help",
        subtitle = navSubtitle(),
        noBorder = true,
        onClose  = function() ManualSave.closeHelpScreen() end,
        render   = function(self2)
            local TH2 = ManualSave.Theme
            local bw  = 2
            self2:drawRect(0, 0, self2.width, bw, 1, TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            self2:drawRect(0, self2.height-bw, self2.width, bw, 1, TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            self2:drawRect(0, 0, bw, self2.height, 1, TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            self2:drawRect(self2.width-bw, 0, bw, self2.height, 1, TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
        end,
    })
    _screen  = d
    local cy = d.titleH
    local ch = H - cy

    ManualSave.makeWatcherStatusDot(d._titleBar, { titleH=d.titleH, panelW=W })

    local contentPanel
    local nav = ManualSave.makeHelpNav(d.panel, {
        y=cy, w=NAV_W, h=ch,
        categories = CATEGORIES,
        getSection = function() return _section end,
        onNavigate = function(id)
            _section = id
            if contentPanel then contentPanel.resetScroll() end
            d.setSubtitle(navSubtitle())
        end,
    })
    _navScrollTo = nav.scrollTo

    local contX = NAV_W + 1
    local contW = W - NAV_W - 1
    contentPanel = ManualSave.makeScrollText(d.panel, {
        x=contX, y=cy, w=contW, h=ch,
        getLines = activeLines,
    })

    d.open()
end

function ManualSave.closeHelpScreen()
    if not _screen then return end
    local d    = _screen
    _screen      = nil
    _navScrollTo = nil
    d.close()
end

print("[ManualSaveMod] UI/Screens/HelpScreen.lua loaded.")
