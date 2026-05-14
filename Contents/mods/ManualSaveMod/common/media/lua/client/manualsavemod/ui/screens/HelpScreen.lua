-- UI/Screens/HelpScreen.lua
-- Help overlay: left nav (scrollable, categories + pages), right scrollable content.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, undefined-field

ManualSave = ManualSave or {}

local PLATFORM = "Windows 10 / 11"

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

local function modTitle()
    if ManualSave.MOD_VERSION == "?" then
        pcall(function()
            local r = getModFileReader("ManualSaveMod", "mod.info", false)
            if not r then return end
            while true do
                local line = r:readLine()
                if not line then break end
                local v = line:match("^modversion=(.-)%s*$")
                if v and v ~= "" then ManualSave.MOD_VERSION = v; break end
            end
            r:close()
        end)
    end
    return ManualSave.MOD_NAME .. "  v" .. ManualSave.MOD_VERSION
end

local function start_lines()
    return {
        { modTitle(),  "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Start_02"),  "header"    },
        { getText("UI_MSM_Help_Start_03"),  "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_04"),  "header"    },
        { PLATFORM,                         "sub"       },
        { getText("UI_MSM_Help_Start_06"),  "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_07"),  "sub"       },
        { getText("UI_MSM_Help_Start_08"),  "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_09"),  "header"    },
        { getText("UI_MSM_Help_Start_10"),  "sub"       },
        { getText("UI_MSM_Help_Start_11"),  "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Start_12"),  "sub"       },
        { getText("UI_MSM_Help_Start_13"),  "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_14"),  "sub"       },
        { getText("UI_MSM_Help_Start_15"),  "body"      },
        { getText("UI_MSM_Help_Start_16"),  "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Start_17"),  "sub"       },
        { getText("UI_MSM_Help_Start_18"),  "body"      },
        { getText("UI_MSM_Help_Start_19"),  "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Start_20"),  "sub"       },
        { getText("UI_MSM_Help_Start_21"),  "body"      },
        { getText("UI_MSM_Help_Start_22"),  "warn"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_23"),  "header"    },
        { getText("UI_MSM_Help_Start_24"),  "body"      },
    }
end

local function safety_lines()
    return {
        { getText("UI_MSM_Help_Safety_01"), "header"    },
        { getText("UI_MSM_Help_Safety_02"), "body"      },
        { getText("UI_MSM_Help_Safety_03"), "callout"   },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_04"), "header"    },
        { getText("UI_MSM_Help_Safety_05"), "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_06"), "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_07"), "header"    },
        { getText("UI_MSM_Help_Safety_08"), "check"     },
        { getText("UI_MSM_Help_Safety_09"), "dim"       },
        { getText("UI_MSM_Help_Safety_10"), "check"     },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_11"), "header"    },
        { getText("UI_MSM_Help_Safety_12"), "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_13"), "callout"   },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_14"), "callout_g" },
    }
end

-- WATCHER ──────────────────────────────────────────────────────────────────────

local function watcher_what_lines()
    return {
        { getText("UI_MSM_Help_Watcher_01"), "header"   },
        { getText("UI_MSM_Help_Watcher_02"), "body"     },
        { getText("UI_MSM_Help_Watcher_03"), "dim"      },
        { "",                                           },
        { getText("UI_MSM_Help_Watcher_04"), "callout"  },
        { "",                                           },
        { getText("UI_MSM_Help_Watcher_05"), "header"   },
        { getText("UI_MSM_Help_Watcher_06"), "body"     },
        { "",                                           },
        { getText("UI_MSM_Help_Watcher_07"), "header"   },
        { getText("UI_MSM_Help_Watcher_08"), "body"     },
        { getText("UI_MSM_Help_Watcher_09"), "dim"      },
        { "",                                           },
        { getText("UI_MSM_Help_Watcher_10"), "callout"  },
    }
end

local function watcher_run_lines()
    return {
        { getText("UI_MSM_Help_WatcherRun_01"), "header" },
        { getText("UI_MSM_Help_WatcherRun_02"), "body"   },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_03"), "header" },
        { getText("UI_MSM_Help_WatcherRun_04"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_05"), "sub"    },
        { getText("UI_MSM_Help_WatcherRun_06"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_07"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_08"), "header" },
        { getText("UI_MSM_Help_WatcherRun_09"), "body"   },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_10"), "header" },
        { getText("UI_MSM_Help_WatcherRun_11"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_12"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_13"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_14"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_15"), "header" },
        { getText("UI_MSM_Help_WatcherRun_16"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_17"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_18"), "header" },
        { getText("UI_MSM_Help_WatcherRun_19"), "body"   },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_20"), "dim"    },
    }
end

-- SAVE ─────────────────────────────────────────────────────────────────────────

local function quicksave_lines()
    return {
        { getText("UI_MSM_Help_Quicksave_01"), "header"   },
        { getText("UI_MSM_Help_Quicksave_02"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_03"), "callout_w"},
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_04"), "header"   },
        { getText("UI_MSM_Help_Quicksave_05"), "body"     },
        { getText("UI_MSM_Help_Quicksave_06"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_07"), "body"     },
        { getText("UI_MSM_Help_Quicksave_08"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_09"), "body"     },
        { getText("UI_MSM_Help_Quicksave_10"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_11"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_12"), "header"   },
        { getText("UI_MSM_Help_Quicksave_13"), "callout_w"},
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_14"), "sub"      },
        { getText("UI_MSM_Help_Quicksave_15"), "body"     },
        { getText("UI_MSM_Help_Quicksave_16"), "warn"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_17"), "sub"      },
        { getText("UI_MSM_Help_Quicksave_18"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_19"), "sub"      },
        { getText("UI_MSM_Help_Quicksave_20"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_21"), "header"   },
        { getText("UI_MSM_Help_Quicksave_22"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_23"), "header"   },
        { getText("UI_MSM_Help_Quicksave_24"), "body"     },
    }
end

local function fullsave_lines()
    return {
        { getText("UI_MSM_Help_Fullsave_01"), "header"    },
        { getText("UI_MSM_Help_Fullsave_02"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_03"), "callout"   },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_04"), "header"    },
        { getText("UI_MSM_Help_Fullsave_05"), "sub"       },
        { getText("UI_MSM_Help_Fullsave_06"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_07"), "dim"       },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_08"), "sub"       },
        { getText("UI_MSM_Help_Fullsave_09"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_10"), "dim"       },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_11"), "header"    },
        { getText("UI_MSM_Help_Fullsave_12"), "body"      },
        { getText("UI_MSM_Help_Fullsave_13"), "warn"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_14"), "callout_g" },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_15"), "header"    },
        { getText("UI_MSM_Help_Fullsave_16"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_17"), "header"    },
        { getText("UI_MSM_Help_Fullsave_18"), "callout"   },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_19"), "body"      },
    }
end

local function thumbnail_lines()
    return {
        { getText("UI_MSM_Help_Thumbnail_01"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_02"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_03"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_04"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_05"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_06"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_07"), "dim"      },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_08"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_09"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_10"), "dim"      },
        { getText("UI_MSM_Help_Thumbnail_11"), "callout"  },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_12"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_13"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_14"), "dim"      },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_15"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_16"), "dim"      },
    }
end

-- LOAD ─────────────────────────────────────────────────────────────────────────

local function loadscreen_lines()
    return {
        { getText("UI_MSM_Help_Loadscreen_01"), "header"   },
        { getText("UI_MSM_Help_Loadscreen_02"), "body"     },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_03"), "header"   },
        { getText("UI_MSM_Help_Loadscreen_04"), "body"     },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_05"), "sub"      },
        { getText("UI_MSM_Help_Loadscreen_06"), "body"     },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_07"), "sub"      },
        { getText("UI_MSM_Help_Loadscreen_08"), "body"     },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_09"), "header"   },
        { getText("UI_MSM_Help_Loadscreen_10"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_11"), "check"    },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_12"), "callout_w"},
    }
end

local function more_lines()
    return {
        { getText("UI_MSM_Help_More_01"), "header"         },
        { getText("UI_MSM_Help_More_02"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_03"), "header"         },
        { getText("UI_MSM_Help_More_04"), "sub"            },
        { getText("UI_MSM_Help_More_05"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_06"), "sub"            },
        { getText("UI_MSM_Help_More_07"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_08"), "sub"            },
        { getText("UI_MSM_Help_More_09"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_10"), "header"         },
        { getText("UI_MSM_Help_More_11"), "sub"            },
        { getText("UI_MSM_Help_More_12"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_13"), "sub"            },
        { getText("UI_MSM_Help_More_14"), "body"           },
        { getText("UI_MSM_Help_More_15"), "dim"            },
        { "",                                              },
        { getText("UI_MSM_Help_More_16"), "sub"            },
        { getText("UI_MSM_Help_More_17"), "body"           },
        { getText("UI_MSM_Help_More_18"), "dim"            },
    }
end

local function duplicate_lines()
    return {
        { getText("UI_MSM_Help_Duplicate_01"), "header"    },
        { getText("UI_MSM_Help_Duplicate_02"), "body"      },
        { "",                                              },
        { getText("UI_MSM_Help_Duplicate_03"), "header"    },
        { getText("UI_MSM_Help_Duplicate_04"), "body"      },
        { getText("UI_MSM_Help_Duplicate_05"), "dim"       },
        { "",                                              },
        { getText("UI_MSM_Help_Duplicate_06"), "header"    },
        { getText("UI_MSM_Help_Duplicate_07"), "callout_w" },
        { "",                                              },
        { getText("UI_MSM_Help_Duplicate_08"), "header"    },
        { getText("UI_MSM_Help_Duplicate_09"), "body"      },
    }
end

local function rename_lines()
    return {
        { getText("UI_MSM_Help_Rename_01"), "header"       },
        { getText("UI_MSM_Help_Rename_02"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Rename_03"), "header"       },
        { getText("UI_MSM_Help_Rename_04"), "body"         },
        { getText("UI_MSM_Help_Rename_05"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Rename_08"), "header"       },
        { getText("UI_MSM_Help_Rename_09"), "body"         },
        { getText("UI_MSM_Help_Rename_10"), "dim"          },
    }
end

local function delete_lines()
    return {
        { getText("UI_MSM_Help_Delete_01"), "header"       },
        { getText("UI_MSM_Help_Delete_02"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Delete_03"), "callout_w"    },
        { "",                                              },
        { getText("UI_MSM_Help_Delete_04"), "header"       },
        { getText("UI_MSM_Help_Delete_05"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Delete_06"), "header"       },
        { getText("UI_MSM_Help_Delete_07"), "body"         },
    }
end

local function import_lines()
    return {
        { getText("UI_MSM_Help_Import_01"), "header"       },
        { getText("UI_MSM_Help_Import_02"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Import_03"), "callout"      },
        { "",                                              },
        { getText("UI_MSM_Help_Import_04"), "header"       },
        { getText("UI_MSM_Help_Import_05"), "callout_w"    },
        { "",                                              },
        { getText("UI_MSM_Help_Import_06"), "header"       },
        { getText("UI_MSM_Help_Import_07"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Import_08"), "header"       },
        { getText("UI_MSM_Help_Import_09"), "body"         },
        { getText("UI_MSM_Help_Import_10"), "dim"          },
    }
end

-- WORLD OPS ────────────────────────────────────────────────────────────────────

local function renameworld_lines()
    return {
        { getText("UI_MSM_Help_Renameworld_01"), "header"  },
        { getText("UI_MSM_Help_Renameworld_02"), "body"    },
        { "",                                              },
        { getText("UI_MSM_Help_Renameworld_03"), "dim"     },
        { "",                                              },
        { getText("UI_MSM_Help_Renameworld_04"), "header"  },
        { getText("UI_MSM_Help_Renameworld_05"), "body"    },
        { "",                                              },
        { getText("UI_MSM_Help_Renameworld_06"), "header"  },
        { getText("UI_MSM_Help_Renameworld_07"), "callout_w"},
        { "",                                              },
        { getText("UI_MSM_Help_Renameworld_08"), "dim"     },
    }
end

local function editmods_lines()
    return {
        { getText("UI_MSM_Help_EditMods_01"), "header"    },
        { getText("UI_MSM_Help_EditMods_02"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_EditMods_03"), "callout"   },
        { "",                                             },
        { getText("UI_MSM_Help_EditMods_11"), "header"    },
        { getText("UI_MSM_Help_EditMods_12"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_EditMods_13"), "header"    },
        { getText("UI_MSM_Help_EditMods_14"), "check"     },
        { getText("UI_MSM_Help_EditMods_15"), "check"     },
        { getText("UI_MSM_Help_EditMods_16"), "check"     },
        { "",                                             },
        { getText("UI_MSM_Help_EditMods_17"), "header"    },
        { getText("UI_MSM_Help_EditMods_18"), "body"      },
        { getText("UI_MSM_Help_EditMods_19"), "dim"       },
        { "",                                             },
        { getText("UI_MSM_Help_EditMods_20"), "callout_w" },
    }
end

-- RECOVERY ─────────────────────────────────────────────────────────────────────

local function recovery_lines()
    return {
        { getText("UI_MSM_Help_Recovery_01"), "header"     },
        { getText("UI_MSM_Help_Recovery_02"), "body"       },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_03"), "callout_w"  },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_04"), "header"     },
        { getText("UI_MSM_Help_Recovery_05"), "sub"        },
        { getText("UI_MSM_Help_Recovery_06"), "body"       },
        { getText("UI_MSM_Help_Recovery_07"), "dim"        },
        { getText("UI_MSM_Help_Recovery_08"), "warn"       },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_12"), "sub"        },
        { getText("UI_MSM_Help_Recovery_13"), "body"       },
        { getText("UI_MSM_Help_Recovery_14"), "dim"        },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_15"), "sub"        },
        { getText("UI_MSM_Help_Recovery_16"), "body"       },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_17"), "sub"        },
        { getText("UI_MSM_Help_Recovery_18"), "body"       },
        { getText("UI_MSM_Help_Recovery_19"), "dim"        },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_20"), "header"     },
        { getText("UI_MSM_Help_Recovery_21"), "body"       },
        { getText("UI_MSM_Help_Recovery_22"), "warn"       },
    }
end

-- TROUBLESHOOTING ──────────────────────────────────────────────────────────────

local function trouble_lines()
    return {
        { getText("UI_MSM_Help_Trouble_01"), "header"      },
        { getText("UI_MSM_Help_Trouble_02"), "body"        },
        { getText("UI_MSM_Help_Trouble_03"), "check"       },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_04"), "header"      },
        { getText("UI_MSM_Help_Trouble_05"), "body"        },
        { getText("UI_MSM_Help_Trouble_06"), "check"       },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_07"), "dim"         },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_08"), "header"      },
        { getText("UI_MSM_Help_Trouble_09"), "check"       },
        { getText("UI_MSM_Help_Trouble_10"), "dim"         },
        { getText("UI_MSM_Help_Trouble_11"), "check"       },
        { getText("UI_MSM_Help_Trouble_12"), "dim"         },
        { getText("UI_MSM_Help_Trouble_13"), "check"       },
        { getText("UI_MSM_Help_Trouble_14"), "dim"         },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_15"), "header"      },
        { getText("UI_MSM_Help_Trouble_16"), "check"       },
        { getText("UI_MSM_Help_Trouble_17"), "dim"         },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_18"), "header"      },
        { getText("UI_MSM_Help_Trouble_19"), "body"        },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_20"), "header"      },
        { getText("UI_MSM_Help_Trouble_21"), "body"        },
    }
end

-- REFERENCE ────────────────────────────────────────────────────────────────────

local function limits_lines()
    return {
        { getText("UI_MSM_Help_Limits_01"), "header"       },
        { PLATFORM,                         "sub"          },
        { getText("UI_MSM_Help_Limits_02"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_03"), "header"       },
        { getText("UI_MSM_Help_Limits_04"), "body"         },
        { getText("UI_MSM_Help_Limits_05"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_06"), "header"       },
        { getText("UI_MSM_Help_Limits_07"), "body"         },
        { getText("UI_MSM_Help_Limits_08"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_09"), "header"       },
        { getText("UI_MSM_Help_Limits_10"), "body"         },
        { getText("UI_MSM_Help_Limits_11"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_12"), "header"       },
        { getText("UI_MSM_Help_Limits_13"), "warn"         },
        { getText("UI_MSM_Help_Limits_14"), "good"         },
        { getText("UI_MSM_Help_Limits_15"), "body"         },
        { getText("UI_MSM_Help_Limits_16"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_17"), "header"       },
        { getText("UI_MSM_Help_Limits_18"), "body"         },
        { getText("UI_MSM_Help_Limits_19"), "dim"          },
    }
end

local function locations_lines()
    return {
        { getText("UI_MSM_Help_Locations_01"), "header"    },
        { getText("UI_MSM_Help_Locations_02"), "body"      },
        { getText("UI_MSM_Help_Locations_03"), "dim"       },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_04"), "header"    },
        { getText("UI_MSM_Help_Locations_05"), "body"      },
        { getText("UI_MSM_Help_Locations_06"), "dim"       },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_07"), "header"    },
        { getText("UI_MSM_Help_Locations_08"), "body"      },
        { getText("UI_MSM_Help_Locations_09"), "dim"       },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_10"), "header"    },
        { getText("UI_MSM_Help_Locations_11"), "body"      },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_12"), "body"      },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_13"), "header"    },
        { getText("UI_MSM_Help_Locations_14"), "body"      },
        { getText("UI_MSM_Help_Locations_15"), "dim"       },
    }
end

local function glossary_lines()
    return {
        { getText("UI_MSM_Help_Glossary_01"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_02"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_03"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_04"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_05"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_06"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_07"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_08"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_09"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_10"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_11"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_12"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_13"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_14"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_15"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_16"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_17"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_18"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_19"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_20"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_21"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_22"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_23"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_24"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_25"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_26"), "gloss_d"    },
    }
end

-- LINKS ────────────────────────────────────────────────────────────────────────

local function links_lines()
    return {
        { getText("UI_MSM_Help_Links_01"), "header"        },
        { getText("UI_MSM_Help_Links_02"), "body"          },
        { "",                                              },
        { getText("UI_MSM_Help_Links_03"), "header"        },
        { getText("UI_MSM_Help_Links_04"), "body"          },
        { "",                                              },
        { getText("UI_MSM_Help_Links_05"), "header"        },
        { getText("UI_MSM_Help_Links_06"), "body"          },
        { getText("UI_MSM_Help_Links_07"), "dim"           },
    }
end

-- ── Navigation structure ───────────────────────────────────────────────────────

local CATEGORIES = {
    { id="start",    label=getText("UI_MSM_Help_CatStart"),    pages={
        { id="start",       label=getText("UI_MSM_Help_PageStart"),      lines=start_lines       },
        { id="safety",      label=getText("UI_MSM_Help_PageSafety"),     lines=safety_lines      },
    }},
    { id="watcher",  label=getText("UI_MSM_Help_CatWatcher"),  pages={
        { id="watcher",     label=getText("UI_MSM_Help_PageWatcher"),    lines=watcher_what_lines },
        { id="watcher_run", label=getText("UI_MSM_Help_PageWatcherRun"), lines=watcher_run_lines  },
    }},
    { id="save",     label=getText("UI_MSM_Help_CatSave"),     pages={
        { id="quicksave",   label=getText("UI_MSM_Help_PageQuicksave"),  lines=quicksave_lines   },
        { id="fullsave",    label=getText("UI_MSM_Help_PageFullsave"),   lines=fullsave_lines    },
        { id="thumbnail",   label=getText("UI_MSM_Help_PageThumbnail"),  lines=thumbnail_lines   },
    }},
    { id="load",     label=getText("UI_MSM_Help_CatLoad"),     pages={
        { id="loadscreen",  label=getText("UI_MSM_Help_PageLoadscreen"), lines=loadscreen_lines  },
        { id="more",        label=getText("UI_MSM_Help_PageMore"),       lines=more_lines        },
        { id="duplicate",   label=getText("UI_MSM_Help_PageDuplicate"),  lines=duplicate_lines   },
        { id="rename",      label=getText("UI_MSM_Help_PageRename"),     lines=rename_lines      },
        { id="delete",      label=getText("UI_MSM_Help_PageDelete"),     lines=delete_lines      },
        { id="import",      label=getText("UI_MSM_Help_PageImport"),     lines=import_lines      },
    }},
    { id="worldops", label=getText("UI_MSM_Help_CatWorldops"), pages={
        { id="renameworld", label=getText("UI_MSM_Help_PageRenameworld"),lines=renameworld_lines },
        { id="editmods",    label=getText("UI_MSM_Help_PageEditMods"),   lines=editmods_lines    },
    }},
    { id="recovery", label=getText("UI_MSM_Help_CatRecovery"), pages={
        { id="recovery",    label=getText("UI_MSM_Help_PageRecovery"),   lines=recovery_lines    },
    }},
    { id="trouble",  label=getText("UI_MSM_Help_CatTrouble"),  pages={
        { id="trouble",     label=getText("UI_MSM_Help_PageTrouble"),    lines=trouble_lines     },
    }},
    { id="ref",      label=getText("UI_MSM_Help_CatRef"),      pages={
        { id="limits",      label=getText("UI_MSM_Help_PageLimits"),     lines=limits_lines      },
        { id="locations",   label=getText("UI_MSM_Help_PageLocations"),  lines=locations_lines   },
        { id="glossary",    label=getText("UI_MSM_Help_PageGlossary"),   lines=glossary_lines    },
    }},
    { id="links",    label=getText("UI_MSM_Help_CatLinks"),    pages={
        { id="links",       label=getText("UI_MSM_Help_PageLinks"),      lines=links_lines       },
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
        w=W, h=H, title=getText("UI_MSM_Help_Title"),
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
