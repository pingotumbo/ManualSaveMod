-- UI/Screens/SettingsScreen.lua
-- Settings overlay: floating panel with left nav and four tabbed sections.
-- Pure assembler: all logic lives in sections/Settings*.lua.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave                = ManualSave or {}
ManualSave.SettingsScreen = ManualSave.SettingsScreen or {}

local W, H  = 640, 560
local NAV_W = 148

local SECTIONS = {
    { id="general",  labelKey="UI_MSM_Settings_NavGeneral"  },
    { id="progress", labelKey="UI_MSM_Settings_NavProgress" },
    { id="paths",    labelKey="UI_MSM_Settings_NavPaths"    },
    { id="advanced", labelKey="UI_MSM_Settings_NavAdvanced" },
}

function ManualSave.openSettingsScreen()
    local ss = ManualSave.SettingsScreen
    if ss._screen then
        ss._screen.panel:bringToTop()
        return
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
    -- Links: right from nav -> content; left from content -> nav.
    local IN = ManualSave.InputNav
    local mgr, groups = IN.buildManager({
        { id="nav",     layout="vertical", wrap=true },
        { id="content", layout="vertical", wrap=true },
    }, {
        { from=1, on="right", to=2 },
        { from=2, on="left",  to=1 },
    })
    local navGroup, contentGroup = groups[1], groups[2]
    mgr.onCancel = function() ManualSave.closeSettingsScreen() end

    -- Tag the inner panel so child widgets walking up via findNavGroup land in
    -- the right group: nav-side widgets land in navGroup, section-side widgets
    -- land in contentGroup. Each panel gets its own _inputNavGroup pointer.
    d.panel._inputNav      = mgr
    d.panel._inputNavGroup = contentGroup   -- safe default for footer-area widgets

    -- Push the manager when the floating panel opens; pop on close.
    local origOpen = d.open
    d.open = function()
        IN.pushActive(mgr)
        if origOpen then origOpen() end
    end
    d.onClose(function() IN.popActive(mgr) end)

    -- The floating window's X button (no overlay close): register at the end
    -- of the content group's tab order.
    if d.xButton then contentGroup:add(d.xButton) end

    -- makeSettingsNav builds a ScrollList registered as a single item in
    -- navGroup (via opts.focusGroup). Up/Down inside the list cycles
    -- sections; Left/Right exit via the link to contentGroup.
    ManualSave.makeSettingsNav(d.panel, {
        y=cy, h=ch, sections=SECTIONS, navW=NAV_W,
        focusGroup      = navGroup,
        onSectionChange = function() contentGroup:focusFirst() end,
    })

    local sx = NAV_W + 1
    local sw = W - NAV_W - 1
    local sh = ch - footerH

    local builders = {
        general  = ManualSave.makeSettingsGeneral,
        progress = ManualSave.makeSettingsProgress,
        paths    = ManualSave.makeSettingsPaths,
        advanced = ManualSave.makeSettingsAdvanced,
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

    d.open()
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
