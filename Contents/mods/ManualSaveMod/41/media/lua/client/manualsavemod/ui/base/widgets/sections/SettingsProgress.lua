-- UI/Base/Widgets/Sections/SettingsProgress.lua
-- Progress HUD settings section: spinner style, size slider, animated preview, HUD position picker.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { x, y, w, h }
function ManualSave.makeSettingsProgress(parent, opts)
    local TH    = ManualSave.Theme
    local w     = opts.w
    local p     = ManualSave.makeScrollPanel(parent, {
        x=opts.x, y=opts.y, w=w, h=opts.h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local cy    = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavProgress") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    -- Live preview state shared between dropdown, slider, animated preview.
    local previewStyle  = ManualSave.Config.get("SPINNER_STYLE") or "spiffo"
    local previewSizePx = math.max(24, math.min(128,
        tonumber(ManualSave.Config.get("SPINNER_SIZE_PX")) or 64))

    -- Row 1: spinner Style dropdown on the left, animated preview on the right.
    -- The two share the same row height (120 px = preview height).
    local PREVIEW_H = 120
    local STYLE_W   = math.floor((w - 28 - TH.GAP) * 0.42)
    local PREVIEW_W = w - 28 - TH.GAP - STYLE_W
    local DD_H      = TH.BUTTON_HGT + 4

    -- Style label + dropdown anchored to the top of the row.
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=STYLE_W,
        getText = function() return getText("UI_MSM_Settings_SpinnerStyleTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    local ddY = cy + TH.FONT_HGT_SMALL + 4
    ManualSave.makeDropdown(p, {
        x=14, y=ddY, w=STYLE_W, h=DD_H,
        value = previewStyle,
        items = {
            { id="spiffo", label = getText("UI_MSM_Settings_SpinnerSpiffo") },
            { id="none",   label = getText("UI_MSM_Settings_SpinnerNone")   },
        },
        onChange = function(id)
            previewStyle = id
            ManualSave.Config.set("SPINNER_STYLE", id)
        end,
    })

    -- Animated preview occupies the right half of the row.
    ManualSave.makeAnimatedPreview(p, {
        x = 14 + STYLE_W + TH.GAP, y = cy, w = PREVIEW_W, h = PREVIEW_H,
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
    cy = cy + PREVIEW_H + TH.GAP

    -- Row 2: spinner size slider, full width below the row above.
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
