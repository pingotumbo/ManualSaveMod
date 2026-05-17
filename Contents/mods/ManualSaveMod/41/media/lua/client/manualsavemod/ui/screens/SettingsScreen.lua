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
        title   = getText("UI_MSM_Settings_Title"),
        onClose = function() ManualSave.closeSettingsScreen() end,
    })
    ss._screen = d

    local cy = d.titleH
    local ch  = H - cy

    ManualSave.makeSettingsNav(d.panel, { y=cy, h=ch, sections=SECTIONS, navW=NAV_W })

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
