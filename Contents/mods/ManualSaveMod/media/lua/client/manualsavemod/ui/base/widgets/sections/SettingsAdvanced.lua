-- UI/Base/Widgets/Sections/SettingsAdvanced.lua
-- Advanced settings section: verbose log toggle, reset all settings.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { x, y, w, h }
function ManualSave.makeSettingsAdvanced(parent, opts)
    local TH    = ManualSave.Theme
    local w     = opts.w
    local p     = ManualSave.makeScrollPanel(parent, {
        x=opts.x, y=opts.y, w=w, h=opts.h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local ROW_H = TH.FONT_HGT_SMALL * 2 + 18
    local cy    = TH.PAD
    local ss    = ManualSave.SettingsScreen

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavAdvanced") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    ManualSave.makeSettingsCheckRow(p, {
        x=0, y=cy, w=w, h=ROW_H,
        label    = getText("UI_MSM_Settings_VerboseTitle"),
        desc     = getText("UI_MSM_Settings_VerboseDesc"),
        getValue = function() return ManualSave.Config.get("VERBOSE_LOG") ~= "0" end,
        onToggle = function()
            ManualSave.Config.set("VERBOSE_LOG",
                ManualSave.Config.get("VERBOSE_LOG") == "0" and "1" or "0")
        end,
    })
    cy = cy + ROW_H + TH.PAD

    cy = cy + ManualSave.makeDangerSeparator(p, {
        x=14, y=cy, w=w-28,
        labelKey = "UI_MSM_Settings_DangerZone",
    }) + TH.GAP

    local btnW = ManualSave.textBtnW(getText("UI_MSM_Settings_BtnResetAll"), 80)
    ManualSave.makeButton(p, {
        x=14, y=cy, w=btnW, h=TH.BUTTON_HGT,
        label   = getText("UI_MSM_Settings_BtnResetAll"),
        style   = "danger",
        onClick = function()
            if ss._resetDialogOpen then return end
            ss._resetDialogOpen = true
            ManualSave.openConfirmDialog({
                title   = getText("UI_MSM_Settings_ResetAllTitle"),
                body    = getText("UI_MSM_Settings_ResetAllBody"),
                confirm = getText("UI_MSM_Settings_BtnResetAll"),
                danger  = true,
                onConfirm = function()
                    ss._resetDialogOpen = false
                    ManualSave.Config.reset()
                    ManualSave.closeSettingsScreen()
                    ManualSave.openSettingsScreen()
                end,
                onCancel = function()
                    ss._resetDialogOpen = false
                end,
            })
        end,
    })

    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsAdvanced.lua loaded.")
