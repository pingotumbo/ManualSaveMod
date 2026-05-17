-- UI/Base/Widgets/Sections/SettingsProgress.lua
-- Progress HUD settings section: spinner style, size slider, animated preview, HUD position picker.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { x, y, w, h }
function ManualSave.makeSettingsProgress(parent, opts)
    local TH    = ManualSave.Theme
    local w     = opts.w
    local p     = ManualSave.makePanel(parent, {
        x=opts.x, y=opts.y, w=w, h=opts.h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local cy    = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavProgress") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    -- Live preview state shared between slider and animated preview
    local previewStyle  = ManualSave.Config.get("SPINNER_STYLE") or "spiffo"
    local previewSizePx = math.max(24, math.min(128,
        tonumber(ManualSave.Config.get("SPINNER_SIZE_PX")) or 64))

    -- Spinner style row
    local compactH = TH.BUTTON_HGT + 12
    ManualSave.makeSettingToolbar(p, {
        x=0, y=cy, w=w, key="SPINNER_STYLE",
        titleKey = "UI_MSM_Settings_SpinnerStyleTitle",
        items = {
            { id="spiffo", labelKey="UI_MSM_Settings_SpinnerSpiffo", value="spiffo" },
            { id="none",   labelKey="UI_MSM_Settings_SpinnerNone",   value="none"   },
        },
        onPreview = function(v) previewStyle = v end,
    })
    cy = cy + compactH + TH.GAP

    -- Spinner size slider
    ManualSave.makeSlider(p, {
        x=0, y=cy, w=w,
        min=24, max=128, value=previewSizePx,
        labelKey    = "UI_MSM_Settings_SpinnerSizeTitle",
        formatValue = function(v) return tostring(v) .. " px" end,
        onChange  = function(v) previewSizePx = v end,
        onRelease = function(v)
            previewSizePx = v
            ManualSave.Config.set("SPINNER_SIZE_PX", tostring(v))
        end,
    })
    cy = cy + (TH.FONT_HGT_SMALL + 20) + TH.GAP

    -- Animated spinner preview
    ManualSave.makeAnimatedPreview(p, {
        x=14, y=cy, w=w-28, h=120,
        textures = {
            "media/textures/MSM_SpiffoHammer_01_WindUp.png",
            "media/textures/MSM_SpiffoHammer_02_MidSwing.png",
            "media/textures/MSM_SpiffoHammer_03_Strike.png",
            "media/textures/MSM_SpiffoHammer_04_Rest.png",
        },
        fps      = 8,
        getSize  = function() return previewSizePx end,
        isActive = function() return previewStyle == "spiffo" end,
        noActiveKey = "UI_MSM_Settings_PreviewNoSpinner",
    })
    cy = cy + 120 + TH.GAP

    -- HUD position block
    ManualSave.makePanel(p, {
        x=0, y=cy, w=w, h=1,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.35 }, border=false,
    })
    cy = cy + 1 + TH.GAP

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_HudPosTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_HudPosDesc") end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    ManualSave.makeHudPositionPicker(p, {
        x=14, y=cy, w=w-28,
        configKeyX    = "HUD_POS_X",
        configKeyY    = "HUD_POS_Y",
        configKeyHide = "HUD_HIDDEN",
    })

    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsProgress.lua loaded.")
