-- UI/Base/Widgets/Sections/SettingsGeneral.lua
-- General settings section: confirm toggles + thumbnail chooser.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { x, y, w, h }
function ManualSave.makeSettingsGeneral(parent, opts)
    local TH    = ManualSave.Theme
    local w     = opts.w
    local p     = ManualSave.makeScrollPanel(parent, {
        x=opts.x, y=opts.y, w=w, h=opts.h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local ROW_H = TH.FONT_HGT_SMALL * 2 + 28
    local cy    = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavGeneral") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    local rows = {
        { key="CONFIRM_LOAD",      titleKey="UI_MSM_Settings_ConfirmLoadTitle", descKey="UI_MSM_Settings_ConfirmLoadDesc" },
        { key="CONFIRM_DELETE",    titleKey="UI_MSM_Settings_ConfirmDelTitle",  descKey="UI_MSM_Settings_ConfirmDelDesc"  },
        { key="SHOW_WATCHER_WARN", titleKey="UI_MSM_Settings_WatcherWarnTitle", descKey="UI_MSM_Settings_WatcherWarnDesc" },
    }
    for _, row in ipairs(rows) do
        local key = row.key
        ManualSave.makeSettingsCheckRow(p, {
            x=0, y=cy, w=w, h=ROW_H,
            label    = getText(row.titleKey),
            desc     = getText(row.descKey),
            getValue = function() return ManualSave.Config.get(key) ~= "0" end,
            onToggle = function()
                ManualSave.Config.set(key, ManualSave.Config.get(key) == "0" and "1" or "0")
            end,
        })
        cy = cy + ROW_H
    end

    cy = cy + TH.GAP * 3

    ManualSave.makePanel(p, {
        x=0, y=cy, w=w, h=1,
        bg={r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.4}, border=false,
    })
    cy = cy + 1 + TH.GAP

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_SaveImageTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_SaveImageDesc") end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    ManualSave.makeOptionCards(p, {
        x=14, y=cy, w=w-28,
        getValue = function() return ManualSave.Config.get("THUMB_SOURCE") end,
        onChange = function(val) ManualSave.Config.set("THUMB_SOURCE", val) end,
        cards = {
            { value="screenshot",  titleKey="UI_MSM_Settings_ThumbScreenshotTitle",
              tex=getTexture("media/textures/MSM_ThumbPreview_Screenshot.png") },
            { value="placeholder", titleKey="UI_MSM_Settings_ThumbPlaceholderTitle",
              tex=getTexture("media/textures/MSM_ThumbPreview_Placeholder.png") },
        },
    })

    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsGeneral.lua loaded.")
