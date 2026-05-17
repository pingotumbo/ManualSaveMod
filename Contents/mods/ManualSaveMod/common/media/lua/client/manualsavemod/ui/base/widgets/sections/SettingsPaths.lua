-- UI/Base/Widgets/Sections/SettingsPaths.lua
-- Paths settings section: backup directory input.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { x, y, w, h }
function ManualSave.makeSettingsPaths(parent, opts)
    local TH = ManualSave.Theme
    local w  = opts.w
    local p  = ManualSave.makePanel(parent, {
        x=opts.x, y=opts.y, w=w, h=opts.h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local cy = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavPaths") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    ManualSave.makePanel(p, {
        x=0, y=cy, w=w, h=1,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.5 }, border=false,
    })
    cy = cy + 1 + TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_BackupTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + 2
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_BackupDesc") end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP + 4

    ManualSave.makePathInput(p, {
        x=14, y=cy, w=w-14,
        configKey      = "BACKUP_DIR",
        placeholderKey = "UI_MSM_Settings_BackupPlaceholder",
        resetBtnKey    = "UI_MSM_Settings_BtnResetPath",
        resetValue     = "",
        -- onChange: hook here in future to notify watcher of path change
    })
    cy = cy + (TH.BUTTON_HGT + 2) + TH.GAP

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_BackupDefault") end,
        r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=0.9,
    })

    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsPaths.lua loaded.")
