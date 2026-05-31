-- UI/Base/Widgets/Sections/SettingsShortcuts.lua
-- Shortcuts section: lets the user rebind the in-game quick-save / quick-load
-- keyboard shortcuts. Each row is a label + description + a key-rebind button.
-- The current value is stored in Config (SHORTCUT_QUICK_SAVE / _QUICK_LOAD) as
-- the short key name ("K", "F9", "TAB"), or "" to disable.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { x, y, w, h }
function ManualSave.makeSettingsShortcuts(parent, opts)
    local TH = ManualSave.Theme
    local w  = opts.w
    local p  = ManualSave.makeScrollPanel(parent, {
        x=opts.x, y=opts.y, w=w, h=opts.h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local cy = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavShortcuts") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    -- Each row: title + description on the left, rebind button on the right.
    local ROW_H    = TH.FONT_HGT_SMALL * 2 + 14
    local BTN_W    = 120
    local BTN_H    = TH.BUTTON_HGT
    local rows = {
        { key="SHORTCUT_QUICK_SAVE",
          titleKey = "UI_MSM_Settings_ShortcutQuickSaveTitle",
          descKey  = "UI_MSM_Settings_ShortcutQuickSaveDesc" },
        { key="SHORTCUT_QUICK_LOAD",
          titleKey = "UI_MSM_Settings_ShortcutQuickLoadTitle",
          descKey  = "UI_MSM_Settings_ShortcutQuickLoadDesc" },
    }
    for _, row in ipairs(rows) do
        local key      = row.key
        local rightX   = w - 14 - BTN_W
        local descMaxW = rightX - 14 - TH.GAP

        ManualSave.makeLabel(p, {
            x=14, y=cy + 2, w=descMaxW,
            getText = function() return getText(row.titleKey) end,
            r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
        })
        ManualSave.makeLabel(p, {
            x=14, y=cy + 2 + TH.FONT_HGT_SMALL + 2, w=descMaxW,
            getText = function() return getText(row.descKey) end,
            r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
        })

        ManualSave.makeKeyBindButton(p, {
            x=rightX, y=cy + math.floor((ROW_H - BTN_H) / 2),
            w=BTN_W, h=BTN_H,
            getValue = function() return ManualSave.Config.get(key) end,
            onChange = function(newKey)
                ManualSave.Config.set(key, newKey or "")
            end,
        })

        cy = cy + ROW_H + TH.GAP
    end

    -- Reset to defaults button. Restores both shortcuts to their out-of-box
    -- values (K / F9). The keybind buttons above will auto-refresh via their
    -- update() polling once Config.set changes the stored value.
    cy = cy + TH.GAP
    local resetLabel = getText("UI_MSM_Settings_ShortcutsReset")
    local resetW = math.max(160, ManualSave.textBtnW(resetLabel, 160))
    ManualSave.makeButton(p, {
        x = 14, y = cy, w = resetW, h = TH.BUTTON_HGT,
        label = resetLabel, style = "normal",
        onClick = function()
            ManualSave.Config.set("SHORTCUT_QUICK_SAVE", "K")
            ManualSave.Config.set("SHORTCUT_QUICK_LOAD", "F9")
        end,
    })
    cy = cy + TH.BUTTON_HGT + TH.GAP

    -- Hint at the bottom: how to disable a shortcut.
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_ShortcutsHint") end,
        r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=0.7,
    })

    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsShortcuts.lua loaded.")
