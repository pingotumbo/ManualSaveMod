-- UI/Screens/SettingsScreen.lua
-- Settings overlay: floating panel with left nav and four tabbed sections.
-- Pure assembler: all logic lives in sections/Settings*.lua.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave                = ManualSave or {}
ManualSave.SettingsScreen = ManualSave.SettingsScreen or {}

local W, H  = 640, 560
local NAV_W = 148

local SECTIONS = {
    { id="general",   labelKey="UI_MSM_Settings_NavGeneral"   },
    { id="progress",  labelKey="UI_MSM_Settings_NavProgress"  },
    { id="paths",     labelKey="UI_MSM_Settings_NavPaths"     },
    { id="shortcuts", labelKey="UI_MSM_Settings_NavShortcuts" },
    { id="advanced",  labelKey="UI_MSM_Settings_NavAdvanced"  },
}

function ManualSave.openSettingsScreen(joypadData)
    local ss = ManualSave.SettingsScreen
    if ss._screen then
        ss._screen.panel:bringToTop()
        return
    end
    -- If no joypadData was provided (e.g. opened by mouse click), recover the
    -- active joypad ourselves so the focus transfer still happens on gamepad.
    if not joypadData and JoypadState and JoypadState.getMainMenuJoypad then
        joypadData = JoypadState.getMainMenuJoypad()
    end

    local TH = ManualSave.Theme
    ss._section         = "general"
    ss._sectionPanels   = {}
    ss._resetDialogOpen = false

    local footerH = TH.FONT_HGT_SMALL + TH.PAD * 2

    local d = ManualSave.makeFloatingPanel({
        w=W, h=H,
        title     = getText("UI_MSM_Settings_Title"),
        installNav = false,   -- custom 2-group nav installed below
        onClose   = function() ManualSave.closeSettingsScreen() end,
    })
    ss._screen = d

    local cy = d.titleH
    local ch = H - cy

    -- Two cross-linked focus groups:
    --   navGroup     = vertical list of section tabs on the left
    --   contentGroup = vertical list of widgets on the right (slider rows,
    --                  option cards, checkbox rows, ...). Hidden section
    --                  panels report isVisible()=false, so their widgets
    --                  are skipped by FocusGroup.isNavigable automatically.
    -- Three horizontally-cycling groups: nav (left column) → content (right
    -- column) → header (the X button) → nav. D-pad Right/Left cycles through
    -- them in order so the user can reach every region without ever having to
    -- press Up/Down at the right edge.
    local IN = ManualSave.InputNav
    local mgr, groups = IN.buildManager({
        { id="nav",     layout="vertical",   wrap=true },
        { id="content", layout="vertical",   wrap=true },
        { id="header",  layout="horizontal", wrap=false },
    }, {
        { from=1, on="right", to=2 }, { from=2, on="left",  to=1 },
        { from=2, on="right", to=3 }, { from=3, on="left",  to=2 },
        { from=3, on="right", to=1 }, { from=1, on="left",  to=3 },
    })
    local navGroup, contentGroup, headerGroup = groups[1], groups[2], groups[3]
    mgr.onCancel = function() ManualSave.closeSettingsScreen() end

    -- Tag the inner panel so child widgets walking up via findNavGroup land in
    -- the right group: nav-side widgets land in navGroup, section-side widgets
    -- land in contentGroup. Each panel gets its own _inputNavGroup pointer.
    d.panel._inputNav      = mgr
    d.panel._inputNavGroup = contentGroup   -- safe default for footer-area widgets
    -- Floating-compatible markers for AnalogStick drag + L1/R1 floating rotator
    -- (Floating.lua sets these automatically only when installNav~=false; we
    -- opted out and built a custom manager above, so wire them manually here).
    mgr._dragTarget = d.panel
    mgr._isFloating = true

    -- Push the manager when the floating panel opens; pop on close. Forward
    -- all args (joypadData) to the underlying open so floating joypad-focus
    -- transfer can fire when SettingsScreen is opened from a gamepad.
    local origOpen = d.open
    d.open = function(...)
        IN.pushActive(mgr)
        if origOpen then origOpen(...) end
    end
    d.onClose(function() IN.popActive(mgr) end)

    -- The X (close) button is the only widget in the dedicated headerGroup,
    -- so pressing Right from content (or Left from nav, wrapping around) lands
    -- on it. A press closes the panel via the click handler set in Floating.
    if d.xButton then headerGroup:add(d.xButton) end

    -- makeSettingsNav builds a ScrollList registered as a single item in
    -- navGroup (via opts.focusGroup). Up/Down inside the list cycles
    -- sections; Left/Right exit via the link to contentGroup.
    ManualSave.makeSettingsNav(d.panel, {
        y=cy, h=ch, sections=SECTIONS, navW=NAV_W,
        focusGroup      = navGroup,
        -- Silent focusFirst so the section switch produces only the nav sound
        -- from the scroll list itself (one Down = one tick, not two).
        onSectionChange = function() contentGroup:focusFirst(true) end,
    })

    local sx = NAV_W + 1
    local sw = W - NAV_W - 1
    local sh = ch - footerH

    local builders = {
        general   = ManualSave.makeSettingsGeneral,
        progress  = ManualSave.makeSettingsProgress,
        paths     = ManualSave.makeSettingsPaths,
        shortcuts = ManualSave.makeSettingsShortcuts,
        advanced  = ManualSave.makeSettingsAdvanced,
    }
    for _, sec in ipairs(SECTIONS) do
        local sp = builders[sec.id](d.panel, { x=sx, y=cy, w=sw, h=sh })
        -- Section widgets register into contentGroup via walk-up on this panel.
        sp._inputNavGroup = contentGroup
        ss._sectionPanels[sec.id] = sp
        sp:setVisible(sec.id == ss._section)
    end

    local fY = H - footerH
    ManualSave.makePanel(d.panel, {
        x=sx, y=fY, w=sw, h=1,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.5 }, border=false,
    })
    ManualSave.makeLabel(d.panel, {
        x=sx + TH.PAD, y=fY + TH.PAD, w=sw - TH.PAD * 2,
        getText = function() return getText("UI_MSM_Settings_Saved") end,
        r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=0.8,
    })

    d.open(joypadData)
end

function ManualSave.closeSettingsScreen()
    local ss = ManualSave.SettingsScreen
    if not ss._screen then return end
    local d         = ss._screen
    ss._screen      = nil
    ss._sectionPanels   = {}
    ss._resetDialogOpen = false
    d.close()
end

print("[ManualSaveMod] UI/Screens/SettingsScreen.lua loaded.")
