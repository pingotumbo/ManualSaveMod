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
        { getText("UI_MSM_Help_Start_01"),  "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Start_02"),  "header"    },
        { getText("UI_MSM_Help_Start_03"),  "body"      },
        { getText("UI_MSM_Help_Start_04"),  "body"      },
        { getText("UI_MSM_Help_Start_05"),  "body"      },
        { getText("UI_MSM_Help_Start_06"),  "body"      },
        { getText("UI_MSM_Help_Start_07"),  "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_08"),  "header"    },
        { getText("UI_MSM_Help_Start_09"),  "sub"       },
        { getText("UI_MSM_Help_Start_10"),  "body"      },
        { getText("UI_MSM_Help_Start_11"),  "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_12"),  "sub"       },
        { getText("UI_MSM_Help_Start_13"),  "body"      },
        { getText("UI_MSM_Help_Start_14"),  "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_15"),  "header"    },
        { getText("UI_MSM_Help_Start_16"),  "sub"       },
        { getText("UI_MSM_Help_Start_17"),  "dim"       },
        { getText("UI_MSM_Help_Start_18"),  "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Start_19"),  "sub"       },
        { getText("UI_MSM_Help_Start_20"),  "body"      },
        { getText("UI_MSM_Help_Start_21"),  "body"      },
        { getText("UI_MSM_Help_Start_22"),  "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_23"),  "sub"       },
        { getText("UI_MSM_Help_Start_24"),  "body"      },
        { getText("UI_MSM_Help_Start_25"),  "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Start_26"),  "sub"       },
        { getText("UI_MSM_Help_Start_27"),  "body"      },
        { getText("UI_MSM_Help_Start_28"),  "body"      },
        { getText("UI_MSM_Help_Start_29"),  "body"      },
        { getText("UI_MSM_Help_Start_30"),  "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Start_31"),  "sub"       },
        { getText("UI_MSM_Help_Start_32"),  "body"      },
        { getText("UI_MSM_Help_Start_33"),  "body"      },
        { getText("UI_MSM_Help_Start_34"),  "warn"      },
        { "",                                           },
        { getText("UI_MSM_Help_Start_35"),  "header"    },
        { getText("UI_MSM_Help_Start_36"),  "body"      },
        { getText("UI_MSM_Help_Start_37"),  "body"      },
        { getText("UI_MSM_Help_Start_38"),  "body"      },
        { getText("UI_MSM_Help_Start_39"),  "body"      },
        { getText("UI_MSM_Help_Start_40"),  "body"      },
    }
end

local function safety_lines()
    return {
        { getText("UI_MSM_Help_Safety_01"), "header"    },
        { getText("UI_MSM_Help_Safety_02"), "body"      },
        { getText("UI_MSM_Help_Safety_03"), "body"      },
        { getText("UI_MSM_Help_Safety_04"), "callout"   },
        { getText("UI_MSM_Help_Safety_05"), "callout"   },
        { getText("UI_MSM_Help_Safety_06"), "callout"   },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_07"), "header"    },
        { getText("UI_MSM_Help_Safety_08"), "body"      },
        { getText("UI_MSM_Help_Safety_09"), "body"      },
        { getText("UI_MSM_Help_Safety_10"), "body"      },
        { getText("UI_MSM_Help_Safety_11"), "body"      },
        { getText("UI_MSM_Help_Safety_12"), "body"      },
        { getText("UI_MSM_Help_Safety_13"), "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_14"), "dim"       },
        { getText("UI_MSM_Help_Safety_15"), "dim"       },
        { getText("UI_MSM_Help_Safety_16"), "dim"       },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_17"), "header"    },
        { getText("UI_MSM_Help_Safety_18"), "check"     },
        { getText("UI_MSM_Help_Safety_19"), "check"     },
        { getText("UI_MSM_Help_Safety_20"), "dim"       },
        { getText("UI_MSM_Help_Safety_21"), "check"     },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_22"), "header"    },
        { getText("UI_MSM_Help_Safety_23"), "body"      },
        { getText("UI_MSM_Help_Safety_24"), "body"      },
        { getText("UI_MSM_Help_Safety_25"), "body"      },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_26"), "callout"   },
        { getText("UI_MSM_Help_Safety_27"), "callout"   },
        { getText("UI_MSM_Help_Safety_28"), "callout"   },
        { "",                                           },
        { getText("UI_MSM_Help_Safety_29"), "callout_g" },
        { getText("UI_MSM_Help_Safety_30"), "callout_g" },
    }
end

-- WATCHER ──────────────────────────────────────────────────────────────────────

local function watcher_what_lines()
    return {
        { getText("UI_MSM_Help_Watcher_01"), "header"   },
        { getText("UI_MSM_Help_Watcher_02"), "body"     },
        { getText("UI_MSM_Help_Watcher_03"), "body"     },
        { getText("UI_MSM_Help_Watcher_04"), "dim"      },
        { "",                                           },
        { getText("UI_MSM_Help_Watcher_05"), "callout"  },
        { getText("UI_MSM_Help_Watcher_06"), "callout"  },
        { getText("UI_MSM_Help_Watcher_07"), "callout"  },
        { "",                                           },
        { getText("UI_MSM_Help_Watcher_08"), "header"   },
        { getText("UI_MSM_Help_Watcher_09"), "body"     },
        { getText("UI_MSM_Help_Watcher_10"), "body"     },
        { getText("UI_MSM_Help_Watcher_11"), "body"     },
        { getText("UI_MSM_Help_Watcher_12"), "body"     },
        { getText("UI_MSM_Help_Watcher_13"), "body"     },
        { getText("UI_MSM_Help_Watcher_14"), "body"     },
        { getText("UI_MSM_Help_Watcher_15"), "body"     },
        { getText("UI_MSM_Help_Watcher_16"), "body"     },
        { getText("UI_MSM_Help_Watcher_17"), "body"     },
        { getText("UI_MSM_Help_Watcher_18"), "body"     },
        { "",                                           },
        { getText("UI_MSM_Help_Watcher_19"), "header"   },
        { getText("UI_MSM_Help_Watcher_20"), "body"     },
        { getText("UI_MSM_Help_Watcher_21"), "body"     },
        { getText("UI_MSM_Help_Watcher_22"), "body"     },
        { getText("UI_MSM_Help_Watcher_23"), "dim"      },
        { getText("UI_MSM_Help_Watcher_24"), "dim"      },
        { "",                                           },
        { getText("UI_MSM_Help_Watcher_25"), "callout"  },
        { getText("UI_MSM_Help_Watcher_26"), "callout"  },
        { getText("UI_MSM_Help_Watcher_27"), "callout"  },
    }
end

local function watcher_run_lines()
    return {
        { getText("UI_MSM_Help_WatcherRun_01"), "header" },
        { getText("UI_MSM_Help_WatcherRun_02"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_03"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_04"), "body"   },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_05"), "header" },
        { getText("UI_MSM_Help_WatcherRun_06"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_07"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_08"), "sub"    },
        { getText("UI_MSM_Help_WatcherRun_09"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_10"), "dim"    },
        { getText("UI_MSM_Help_WatcherRun_11"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_12"), "header" },
        { getText("UI_MSM_Help_WatcherRun_13"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_14"), "body"   },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_15"), "header" },
        { getText("UI_MSM_Help_WatcherRun_16"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_17"), "dim"    },
        { getText("UI_MSM_Help_WatcherRun_18"), "dim"    },
        { getText("UI_MSM_Help_WatcherRun_19"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_20"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_21"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_22"), "header" },
        { getText("UI_MSM_Help_WatcherRun_23"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_24"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_25"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_26"), "dim"    },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_27"), "header" },
        { getText("UI_MSM_Help_WatcherRun_28"), "body"   },
        { getText("UI_MSM_Help_WatcherRun_29"), "body"   },
        { "",                                            },
        { getText("UI_MSM_Help_WatcherRun_30"), "dim"    },
        { getText("UI_MSM_Help_WatcherRun_31"), "dim"    },
        { getText("UI_MSM_Help_WatcherRun_32"), "dim"    },
    }
end

-- SAVE ─────────────────────────────────────────────────────────────────────────

local function quicksave_lines()
    return {
        { getText("UI_MSM_Help_Quicksave_01"), "header"   },
        { getText("UI_MSM_Help_Quicksave_02"), "body"     },
        { getText("UI_MSM_Help_Quicksave_03"), "body"     },
        { getText("UI_MSM_Help_Quicksave_04"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_05"), "callout_w"},
        { getText("UI_MSM_Help_Quicksave_06"), "callout_w"},
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_07"), "header"   },
        { getText("UI_MSM_Help_Quicksave_08"), "body"     },
        { getText("UI_MSM_Help_Quicksave_09"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_10"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_11"), "body"     },
        { getText("UI_MSM_Help_Quicksave_12"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_13"), "body"     },
        { getText("UI_MSM_Help_Quicksave_14"), "body"     },
        { getText("UI_MSM_Help_Quicksave_15"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_16"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_17"), "dim"      },
        { getText("UI_MSM_Help_Quicksave_18"), "body"     },
        { getText("UI_MSM_Help_Quicksave_19"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_20"), "header"   },
        { getText("UI_MSM_Help_Quicksave_21"), "callout_w"},
        { getText("UI_MSM_Help_Quicksave_22"), "callout_w"},
        { getText("UI_MSM_Help_Quicksave_23"), "callout_w"},
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_24"), "sub"      },
        { getText("UI_MSM_Help_Quicksave_25"), "body"     },
        { getText("UI_MSM_Help_Quicksave_26"), "warn"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_27"), "sub"      },
        { getText("UI_MSM_Help_Quicksave_28"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_29"), "sub"      },
        { getText("UI_MSM_Help_Quicksave_30"), "body"     },
        { getText("UI_MSM_Help_Quicksave_31"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_32"), "header"   },
        { getText("UI_MSM_Help_Quicksave_33"), "body"     },
        { getText("UI_MSM_Help_Quicksave_34"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Quicksave_35"), "header"   },
        { getText("UI_MSM_Help_Quicksave_36"), "body"     },
        { getText("UI_MSM_Help_Quicksave_37"), "body"     },
        { getText("UI_MSM_Help_Quicksave_38"), "body"     },
    }
end

local function fullsave_lines()
    return {
        { getText("UI_MSM_Help_Fullsave_01"), "header"    },
        { getText("UI_MSM_Help_Fullsave_02"), "body"      },
        { getText("UI_MSM_Help_Fullsave_03"), "body"      },
        { getText("UI_MSM_Help_Fullsave_04"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_05"), "callout"   },
        { getText("UI_MSM_Help_Fullsave_06"), "callout"   },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_07"), "header"    },
        { getText("UI_MSM_Help_Fullsave_08"), "sub"       },
        { getText("UI_MSM_Help_Fullsave_09"), "body"      },
        { getText("UI_MSM_Help_Fullsave_10"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_11"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_12"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_13"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_14"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_15"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_16"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_17"), "dim"       },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_18"), "sub"       },
        { getText("UI_MSM_Help_Fullsave_19"), "body"      },
        { getText("UI_MSM_Help_Fullsave_20"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_21"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_22"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_23"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_24"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_25"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_26"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_27"), "dim"       },
        { getText("UI_MSM_Help_Fullsave_28"), "dim"       },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_29"), "header"    },
        { getText("UI_MSM_Help_Fullsave_30"), "body"      },
        { getText("UI_MSM_Help_Fullsave_31"), "warn"      },
        { getText("UI_MSM_Help_Fullsave_32"), "warn"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_33"), "callout_g" },
        { getText("UI_MSM_Help_Fullsave_34"), "callout_g" },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_35"), "header"    },
        { getText("UI_MSM_Help_Fullsave_36"), "body"      },
        { getText("UI_MSM_Help_Fullsave_37"), "body"      },
        { getText("UI_MSM_Help_Fullsave_38"), "body"      },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_39"), "header"    },
        { getText("UI_MSM_Help_Fullsave_40"), "callout"   },
        { getText("UI_MSM_Help_Fullsave_41"), "callout"   },
        { "",                                             },
        { getText("UI_MSM_Help_Fullsave_42"), "body"      },
        { getText("UI_MSM_Help_Fullsave_43"), "body"      },
        { getText("UI_MSM_Help_Fullsave_44"), "body"      },
        { getText("UI_MSM_Help_Fullsave_45"), "body"      },
    }
end

local function thumbnail_lines()
    return {
        { getText("UI_MSM_Help_Thumbnail_01"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_02"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_03"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_04"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_05"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_06"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_07"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_08"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_09"), "dim"      },
        { getText("UI_MSM_Help_Thumbnail_10"), "dim"      },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_11"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_12"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_13"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_14"), "dim"      },
        { getText("UI_MSM_Help_Thumbnail_15"), "dim"      },
        { getText("UI_MSM_Help_Thumbnail_16"), "callout"  },
        { getText("UI_MSM_Help_Thumbnail_17"), "callout"  },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_18"), "header"   },
        { getText("UI_MSM_Help_Thumbnail_19"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_20"), "dim"      },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_21"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_22"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_23"), "body"     },
        { getText("UI_MSM_Help_Thumbnail_24"), "body"     },
        { "",                                             },
        { getText("UI_MSM_Help_Thumbnail_25"), "dim"      },
        { getText("UI_MSM_Help_Thumbnail_26"), "dim"      },
    }
end

-- LOAD ─────────────────────────────────────────────────────────────────────────

local function loadscreen_lines()
    return {
        { getText("UI_MSM_Help_Loadscreen_01"), "header"   },
        { getText("UI_MSM_Help_Loadscreen_02"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_03"), "body"     },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_04"), "header"   },
        { getText("UI_MSM_Help_Loadscreen_05"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_06"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_07"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_08"), "body"     },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_09"), "sub"      },
        { getText("UI_MSM_Help_Loadscreen_10"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_11"), "body"     },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_12"), "sub"      },
        { getText("UI_MSM_Help_Loadscreen_13"), "body"     },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_14"), "header"   },
        { getText("UI_MSM_Help_Loadscreen_15"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_16"), "check"    },
        { getText("UI_MSM_Help_Loadscreen_17"), "check"    },
        { getText("UI_MSM_Help_Loadscreen_18"), "check"    },
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_19"), "callout_w"},
        { getText("UI_MSM_Help_Loadscreen_20"), "callout_w"},
        { getText("UI_MSM_Help_Loadscreen_21"), "callout_w"},
        { "",                                              },
        { getText("UI_MSM_Help_Loadscreen_22"), "header"   },
        { getText("UI_MSM_Help_Loadscreen_23"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_24"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_25"), "body"     },
        { getText("UI_MSM_Help_Loadscreen_26"), "body"     },
    }
end

local function more_lines()
    return {
        { getText("UI_MSM_Help_More_01"), "header"         },
        { getText("UI_MSM_Help_More_02"), "body"           },
        { getText("UI_MSM_Help_More_03"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_04"), "header"         },
        { getText("UI_MSM_Help_More_05"), "sub"            },
        { getText("UI_MSM_Help_More_06"), "body"           },
        { getText("UI_MSM_Help_More_07"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_08"), "sub"            },
        { getText("UI_MSM_Help_More_09"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_10"), "sub"            },
        { getText("UI_MSM_Help_More_11"), "body"           },
        { getText("UI_MSM_Help_More_12"), "body"           },
        { getText("UI_MSM_Help_More_13"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_14"), "header"         },
        { getText("UI_MSM_Help_More_15"), "sub"            },
        { getText("UI_MSM_Help_More_16"), "body"           },
        { "",                                              },
        { getText("UI_MSM_Help_More_17"), "sub"            },
        { getText("UI_MSM_Help_More_18"), "body"           },
        { getText("UI_MSM_Help_More_19"), "dim"            },
        { getText("UI_MSM_Help_More_20"), "dim"            },
        { "",                                              },
        { getText("UI_MSM_Help_More_21"), "sub"            },
        { getText("UI_MSM_Help_More_22"), "body"           },
        { getText("UI_MSM_Help_More_23"), "dim"            },
    }
end

local function duplicate_lines()
    return {
        { getText("UI_MSM_Help_Duplicate_01"), "header"    },
        { getText("UI_MSM_Help_Duplicate_02"), "body"      },
        { getText("UI_MSM_Help_Duplicate_03"), "body"      },
        { "",                                              },
        { getText("UI_MSM_Help_Duplicate_04"), "header"    },
        { getText("UI_MSM_Help_Duplicate_05"), "body"      },
        { getText("UI_MSM_Help_Duplicate_06"), "body"      },
        { getText("UI_MSM_Help_Duplicate_07"), "body"      },
        { getText("UI_MSM_Help_Duplicate_08"), "dim"       },
        { getText("UI_MSM_Help_Duplicate_09"), "dim"       },
        { "",                                              },
        { getText("UI_MSM_Help_Duplicate_10"), "header"    },
        { getText("UI_MSM_Help_Duplicate_11"), "callout_w" },
        { getText("UI_MSM_Help_Duplicate_12"), "callout_w" },
        { "",                                              },
        { getText("UI_MSM_Help_Duplicate_13"), "header"    },
        { getText("UI_MSM_Help_Duplicate_14"), "body"      },
        { getText("UI_MSM_Help_Duplicate_15"), "body"      },
        { getText("UI_MSM_Help_Duplicate_16"), "body"      },
    }
end

local function rename_lines()
    return {
        { getText("UI_MSM_Help_Rename_01"), "header"       },
        { getText("UI_MSM_Help_Rename_02"), "body"         },
        { getText("UI_MSM_Help_Rename_03"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Rename_04"), "header"       },
        { getText("UI_MSM_Help_Rename_05"), "body"         },
        { getText("UI_MSM_Help_Rename_06"), "dim"          },
        { getText("UI_MSM_Help_Rename_07"), "dim"          },
        { getText("UI_MSM_Help_Rename_08"), "dim"          },
        { getText("UI_MSM_Help_Rename_09"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Rename_10"), "header"       },
        { getText("UI_MSM_Help_Rename_11"), "body"         },
        { getText("UI_MSM_Help_Rename_12"), "body"         },
        { getText("UI_MSM_Help_Rename_13"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Rename_14"), "header"       },
        { getText("UI_MSM_Help_Rename_15"), "body"         },
        { getText("UI_MSM_Help_Rename_16"), "body"         },
        { getText("UI_MSM_Help_Rename_17"), "dim"          },
    }
end

local function delete_lines()
    return {
        { getText("UI_MSM_Help_Delete_01"), "header"       },
        { getText("UI_MSM_Help_Delete_02"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Delete_03"), "callout_w"    },
        { getText("UI_MSM_Help_Delete_04"), "callout_w"    },
        { "",                                              },
        { getText("UI_MSM_Help_Delete_05"), "header"       },
        { getText("UI_MSM_Help_Delete_06"), "body"         },
        { getText("UI_MSM_Help_Delete_07"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Delete_08"), "header"       },
        { getText("UI_MSM_Help_Delete_09"), "body"         },
        { getText("UI_MSM_Help_Delete_10"), "body"         },
        { getText("UI_MSM_Help_Delete_11"), "body"         },
    }
end

local function import_lines()
    return {
        { getText("UI_MSM_Help_Import_01"), "header"       },
        { getText("UI_MSM_Help_Import_02"), "body"         },
        { getText("UI_MSM_Help_Import_03"), "body"         },
        { getText("UI_MSM_Help_Import_04"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Import_05"), "callout"      },
        { getText("UI_MSM_Help_Import_06"), "callout"      },
        { "",                                              },
        { getText("UI_MSM_Help_Import_07"), "header"       },
        { getText("UI_MSM_Help_Import_08"), "callout_w"    },
        { getText("UI_MSM_Help_Import_09"), "callout_w"    },
        { getText("UI_MSM_Help_Import_10"), "callout_w"    },
        { "",                                              },
        { getText("UI_MSM_Help_Import_11"), "header"       },
        { getText("UI_MSM_Help_Import_12"), "body"         },
        { getText("UI_MSM_Help_Import_13"), "body"         },
        { getText("UI_MSM_Help_Import_14"), "body"         },
        { getText("UI_MSM_Help_Import_15"), "body"         },
        { getText("UI_MSM_Help_Import_16"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Import_17"), "header"       },
        { getText("UI_MSM_Help_Import_18"), "body"         },
        { getText("UI_MSM_Help_Import_19"), "body"         },
        { getText("UI_MSM_Help_Import_20"), "body"         },
        { getText("UI_MSM_Help_Import_21"), "dim"          },
    }
end

-- WORLD OPS ────────────────────────────────────────────────────────────────────

local function renameworld_lines()
    return {
        { getText("UI_MSM_Help_Renameworld_01"), "header"  },
        { getText("UI_MSM_Help_Renameworld_02"), "body"    },
        { getText("UI_MSM_Help_Renameworld_03"), "body"    },
        { getText("UI_MSM_Help_Renameworld_04"), "body"    },
        { getText("UI_MSM_Help_Renameworld_05"), "body"    },
        { "",                                              },
        { getText("UI_MSM_Help_Renameworld_06"), "dim"     },
        { "",                                              },
        { getText("UI_MSM_Help_Renameworld_07"), "header"  },
        { getText("UI_MSM_Help_Renameworld_08"), "body"    },
        { getText("UI_MSM_Help_Renameworld_09"), "body"    },
        { getText("UI_MSM_Help_Renameworld_10"), "body"    },
        { getText("UI_MSM_Help_Renameworld_11"), "body"    },
        { "",                                              },
        { getText("UI_MSM_Help_Renameworld_12"), "header"  },
        { getText("UI_MSM_Help_Renameworld_13"), "callout_w"},
        { getText("UI_MSM_Help_Renameworld_14"), "callout_w"},
        { getText("UI_MSM_Help_Renameworld_15"), "callout_w"},
        { "",                                              },
        { getText("UI_MSM_Help_Renameworld_16"), "dim"     },
        { getText("UI_MSM_Help_Renameworld_17"), "dim"     },
    }
end

local function stripmods_lines()
    return {
        { getText("UI_MSM_Help_Stripmods_01"), "header"    },
        { getText("UI_MSM_Help_Stripmods_02"), "body"      },
        { getText("UI_MSM_Help_Stripmods_03"), "body"      },
        { "",                                              },
        { getText("UI_MSM_Help_Stripmods_04"), "header"    },
        { getText("UI_MSM_Help_Stripmods_05"), "body"      },
        { getText("UI_MSM_Help_Stripmods_06"), "body"      },
        { getText("UI_MSM_Help_Stripmods_07"), "body"      },
        { "",                                              },
        { getText("UI_MSM_Help_Stripmods_08"), "header"    },
        { getText("UI_MSM_Help_Stripmods_09"), "callout_w" },
        { getText("UI_MSM_Help_Stripmods_10"), "callout_w" },
        { getText("UI_MSM_Help_Stripmods_11"), "callout_w" },
        { getText("UI_MSM_Help_Stripmods_12"), "callout_w" },
        { "",                                              },
        { getText("UI_MSM_Help_Stripmods_13"), "header"    },
        { getText("UI_MSM_Help_Stripmods_14"), "body"      },
        { getText("UI_MSM_Help_Stripmods_15"), "body"      },
        { getText("UI_MSM_Help_Stripmods_16"), "body"      },
        { getText("UI_MSM_Help_Stripmods_17"), "body"      },
        { getText("UI_MSM_Help_Stripmods_18"), "dim"       },
    }
end

-- RECOVERY ─────────────────────────────────────────────────────────────────────

local function recovery_lines()
    return {
        { getText("UI_MSM_Help_Recovery_01"), "header"     },
        { getText("UI_MSM_Help_Recovery_02"), "body"       },
        { getText("UI_MSM_Help_Recovery_03"), "body"       },
        { getText("UI_MSM_Help_Recovery_04"), "body"       },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_05"), "callout_w"  },
        { getText("UI_MSM_Help_Recovery_06"), "callout_w"  },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_07"), "header"     },
        { getText("UI_MSM_Help_Recovery_08"), "sub"        },
        { getText("UI_MSM_Help_Recovery_09"), "body"       },
        { getText("UI_MSM_Help_Recovery_10"), "dim"        },
        { getText("UI_MSM_Help_Recovery_11"), "warn"       },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_12"), "sub"        },
        { getText("UI_MSM_Help_Recovery_13"), "body"       },
        { getText("UI_MSM_Help_Recovery_14"), "dim"        },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_15"), "sub"        },
        { getText("UI_MSM_Help_Recovery_16"), "body"       },
        { getText("UI_MSM_Help_Recovery_17"), "dim"        },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_18"), "sub"        },
        { getText("UI_MSM_Help_Recovery_19"), "body"       },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_20"), "sub"        },
        { getText("UI_MSM_Help_Recovery_21"), "body"       },
        { getText("UI_MSM_Help_Recovery_22"), "dim"        },
        { "",                                              },
        { getText("UI_MSM_Help_Recovery_23"), "header"     },
        { getText("UI_MSM_Help_Recovery_24"), "body"       },
        { getText("UI_MSM_Help_Recovery_25"), "warn"       },
    }
end

-- TROUBLESHOOTING ──────────────────────────────────────────────────────────────

local function trouble_lines()
    return {
        { getText("UI_MSM_Help_Trouble_01"), "header"      },
        { getText("UI_MSM_Help_Trouble_02"), "body"        },
        { getText("UI_MSM_Help_Trouble_03"), "check"       },
        { getText("UI_MSM_Help_Trouble_04"), "check"       },
        { getText("UI_MSM_Help_Trouble_05"), "check"       },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_06"), "header"      },
        { getText("UI_MSM_Help_Trouble_07"), "body"        },
        { getText("UI_MSM_Help_Trouble_08"), "check"       },
        { getText("UI_MSM_Help_Trouble_09"), "check"       },
        { getText("UI_MSM_Help_Trouble_10"), "check"       },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_11"), "dim"         },
        { getText("UI_MSM_Help_Trouble_12"), "dim"         },
        { getText("UI_MSM_Help_Trouble_13"), "dim"         },
        { getText("UI_MSM_Help_Trouble_14"), "dim"         },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_15"), "header"      },
        { getText("UI_MSM_Help_Trouble_16"), "check"       },
        { getText("UI_MSM_Help_Trouble_17"), "dim"         },
        { getText("UI_MSM_Help_Trouble_18"), "check"       },
        { getText("UI_MSM_Help_Trouble_19"), "dim"         },
        { getText("UI_MSM_Help_Trouble_20"), "check"       },
        { getText("UI_MSM_Help_Trouble_21"), "dim"         },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_22"), "header"      },
        { getText("UI_MSM_Help_Trouble_23"), "check"       },
        { getText("UI_MSM_Help_Trouble_24"), "check"       },
        { getText("UI_MSM_Help_Trouble_25"), "dim"         },
        { getText("UI_MSM_Help_Trouble_26"), "dim"         },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_27"), "header"      },
        { getText("UI_MSM_Help_Trouble_28"), "body"        },
        { getText("UI_MSM_Help_Trouble_29"), "body"        },
        { "",                                              },
        { getText("UI_MSM_Help_Trouble_30"), "header"      },
        { getText("UI_MSM_Help_Trouble_31"), "body"        },
        { getText("UI_MSM_Help_Trouble_32"), "body"        },
        { getText("UI_MSM_Help_Trouble_33"), "body"        },
        { getText("UI_MSM_Help_Trouble_34"), "body"        },
    }
end

-- REFERENCE ────────────────────────────────────────────────────────────────────

local function limits_lines()
    return {
        { getText("UI_MSM_Help_Limits_01"), "header"       },
        { getText("UI_MSM_Help_Limits_02"), "body"         },
        { getText("UI_MSM_Help_Limits_03"), "body"         },
        { getText("UI_MSM_Help_Limits_04"), "body"         },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_05"), "header"       },
        { getText("UI_MSM_Help_Limits_06"), "body"         },
        { getText("UI_MSM_Help_Limits_07"), "body"         },
        { getText("UI_MSM_Help_Limits_08"), "body"         },
        { getText("UI_MSM_Help_Limits_09"), "body"         },
        { getText("UI_MSM_Help_Limits_10"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_11"), "header"       },
        { getText("UI_MSM_Help_Limits_12"), "body"         },
        { getText("UI_MSM_Help_Limits_13"), "dim"          },
        { getText("UI_MSM_Help_Limits_14"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_15"), "header"       },
        { getText("UI_MSM_Help_Limits_16"), "body"         },
        { getText("UI_MSM_Help_Limits_17"), "dim"          },
        { getText("UI_MSM_Help_Limits_18"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_19"), "header"       },
        { getText("UI_MSM_Help_Limits_20"), "warn"         },
        { getText("UI_MSM_Help_Limits_21"), "good"         },
        { getText("UI_MSM_Help_Limits_22"), "body"         },
        { getText("UI_MSM_Help_Limits_23"), "dim"          },
        { "",                                              },
        { getText("UI_MSM_Help_Limits_24"), "header"       },
        { getText("UI_MSM_Help_Limits_25"), "body"         },
        { getText("UI_MSM_Help_Limits_26"), "body"         },
        { getText("UI_MSM_Help_Limits_27"), "dim"          },
    }
end

local function locations_lines()
    return {
        { getText("UI_MSM_Help_Locations_01"), "header"    },
        { getText("UI_MSM_Help_Locations_02"), "body"      },
        { getText("UI_MSM_Help_Locations_03"), "body"      },
        { getText("UI_MSM_Help_Locations_04"), "dim"       },
        { getText("UI_MSM_Help_Locations_05"), "dim"       },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_06"), "header"    },
        { getText("UI_MSM_Help_Locations_07"), "body"      },
        { getText("UI_MSM_Help_Locations_08"), "body"      },
        { getText("UI_MSM_Help_Locations_09"), "dim"       },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_10"), "header"    },
        { getText("UI_MSM_Help_Locations_11"), "body"      },
        { getText("UI_MSM_Help_Locations_12"), "dim"       },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_13"), "header"    },
        { getText("UI_MSM_Help_Locations_14"), "body"      },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_15"), "body"      },
        { getText("UI_MSM_Help_Locations_16"), "body"      },
        { getText("UI_MSM_Help_Locations_17"), "body"      },
        { getText("UI_MSM_Help_Locations_18"), "body"      },
        { getText("UI_MSM_Help_Locations_19"), "body"      },
        { getText("UI_MSM_Help_Locations_20"), "body"      },
        { getText("UI_MSM_Help_Locations_21"), "body"      },
        { getText("UI_MSM_Help_Locations_22"), "body"      },
        { getText("UI_MSM_Help_Locations_23"), "body"      },
        { getText("UI_MSM_Help_Locations_24"), "body"      },
        { "",                                              },
        { getText("UI_MSM_Help_Locations_25"), "header"    },
        { getText("UI_MSM_Help_Locations_26"), "body"      },
        { getText("UI_MSM_Help_Locations_27"), "body"      },
        { getText("UI_MSM_Help_Locations_28"), "dim"       },
        { getText("UI_MSM_Help_Locations_29"), "dim"       },
    }
end

local function glossary_lines()
    return {
        { getText("UI_MSM_Help_Glossary_01"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_02"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_03"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_04"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_05"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_06"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_07"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_08"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_09"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_10"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_11"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_12"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_13"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_14"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_15"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_16"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_17"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_18"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_19"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_20"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_21"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_22"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_23"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_24"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_25"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_26"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_27"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_28"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_29"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_30"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_31"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_32"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_33"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_34"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_35"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_36"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_37"), "gloss_d"    },
        { "",                                              },
        { getText("UI_MSM_Help_Glossary_38"), "gloss_t"    },
        { getText("UI_MSM_Help_Glossary_39"), "gloss_d"    },
        { getText("UI_MSM_Help_Glossary_40"), "gloss_d"    },
    }
end

-- LINKS ────────────────────────────────────────────────────────────────────────

local function links_lines()
    return {
        { getText("UI_MSM_Help_Links_01"), "header"        },
        { getText("UI_MSM_Help_Links_02"), "body"          },
        { getText("UI_MSM_Help_Links_03"), "body"          },
        { "",                                              },
        { getText("UI_MSM_Help_Links_04"), "header"        },
        { getText("UI_MSM_Help_Links_05"), "body"          },
        { getText("UI_MSM_Help_Links_06"), "body"          },
        { getText("UI_MSM_Help_Links_07"), "body"          },
        { getText("UI_MSM_Help_Links_08"), "body"          },
        { getText("UI_MSM_Help_Links_09"), "body"          },
        { "",                                              },
        { getText("UI_MSM_Help_Links_10"), "header"        },
        { getText("UI_MSM_Help_Links_11"), "body"          },
        { getText("UI_MSM_Help_Links_12"), "body"          },
        { getText("UI_MSM_Help_Links_13"), "dim"           },
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
        { id="stripmods",   label=getText("UI_MSM_Help_PageStripmods"),  lines=stripmods_lines   },
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
