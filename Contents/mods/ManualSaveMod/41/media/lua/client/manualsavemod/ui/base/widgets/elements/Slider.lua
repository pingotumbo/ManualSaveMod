-- UI/Base/Widgets/Elements/Slider.lua
-- Horizontal numeric range slider with label and live value display.
-- Drag handled via getMouseX() delta to avoid getAbsoluteX() / isLeftMouseButtonDown().
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

-- opts: {
--   x?, y, w, h?
--   min, max            number   range
--   value               number   initial value
--   labelKey            string   i18n key shown on the left
--   formatValue?        fun(v)   returns display string (default: tostring(v) .. " px")
--   onChange?           fun(v)   called every frame while dragging (live preview)
--   onRelease?          fun(v)   called on mouse-up (persist to config)
-- }
-- Returns { getValue: fun():number, setValue: fun(number) }
function ManualSave.makeSlider(parent, opts)
    local TH        = ManualSave.Theme
    local PAD       = 14
    local TRACK_H   = 4
    local THUMB_W   = 8
    local THUMB_H   = 12
    local ROW_H     = opts.h or (TH.FONT_HGT_SMALL + 20)
    local TRACK_Y   = TH.FONT_HGT_SMALL + 8

    local min   = opts.min   or 0
    local max   = opts.max   or 100
    local value = math.max(min, math.min(max, opts.value or min))

    local dragging    = false
    local downAbsX    = 0
    local downPanelX  = 0

    local function xToValue(panelW, mx)
        local trackW = panelW - PAD * 2
        local f = math.max(0, math.min(1, (mx - PAD) / trackW))
        return math.floor(min + f * (max - min))
    end

    local function valueToF()
        return (value - min) / (max - min)
    end

    -- Keyboard / gamepad step. One unit per press is fine because key auto-repeat
    -- gives smooth continuous adjustment when the user holds the arrow key.
    local KEY_STEP = opts.keyStep or 1

    local pv = ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y, w=opts.w, h=ROW_H,
        bg={r=0,g=0,b=0,a=0}, border=false,
        prerender = function(pv)
            local TH2    = ManualSave.Theme
            local trackW = pv.width - PAD * 2
            -- separator
            pv:drawRect(0, pv.height - 1, pv.width, 1, 0.3, TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
            -- label
            pv:drawText(getText(opts.labelKey), PAD, 4,
                TH2.TEXT_R, TH2.TEXT_G, TH2.TEXT_B, 1, UIFont.Small)
            -- value display
            local fmt  = opts.formatValue and opts.formatValue(value) or (tostring(value) .. " px")
            local fmtW = getTextManager():MeasureStringX(UIFont.Small, fmt)
            pv:drawText(fmt, pv.width - PAD - fmtW, 4,
                TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B, 0.75, UIFont.Small)
            -- track background
            pv:drawRect(PAD, TRACK_Y, trackW, TRACK_H, 0.55, 0, 0, 0)
            -- track fill
            local fillW = math.floor(valueToF() * trackW)
            if fillW > 0 then
                pv:drawRect(PAD, TRACK_Y, fillW, TRACK_H, 0.9,
                    TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            end
            -- thumb
            local thumbX = math.max(PAD,
                math.min(PAD + trackW - THUMB_W,
                    PAD + fillW - math.floor(THUMB_W / 2)))
            local thumbY = TRACK_Y + math.floor((TRACK_H - THUMB_H) / 2)
            pv:drawRect(thumbX, thumbY, THUMB_W, THUMB_H, 1,
                TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            -- InputNav focus ring: drawn last so it sits on top of the slider.
            if pv.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
                for i = 0, TH2.FOCUS_BW - 1 do
                    pv:drawRectBorder(i, i, pv.width - i*2, pv.height - i*2, 1,
                        TH2.FOCUS_R, TH2.FOCUS_G, TH2.FOCUS_B)
                end
            end
        end,
        onMouseDown = function(sp, mx, _)
            dragging     = true
            downAbsX     = tonumber(getMouseX()) or 0
            downPanelX   = mx
            value        = xToValue(sp.width, mx)
            if opts.onChange then opts.onChange(value) end
        end,
        onMouseMove = function(self2, _, _)
            if not dragging then return end
            local panelX = downPanelX + ((tonumber(getMouseX()) or 0) - downAbsX)
            value = xToValue(self2.width, panelX)
            if opts.onChange then opts.onChange(value) end
        end,
        onMouseUp = function(sp, mx, _)
            if not dragging then return end
            dragging = false
            value    = xToValue(sp.width, mx)
            if opts.onChange  then opts.onChange(value)  end
            if opts.onRelease then opts.onRelease(value) end
        end,
    })

    -- InputNav: Left/Right adjusts value when the slider is focused.
    -- Up/Down are treated as "leave the slider" (return false → group exits).
    -- Each adjustment fires onChange (live preview); Enter commits via onRelease.
    pv.onArrow = function(_, direction)
        if direction == "left" then
            value = math.max(min, value - KEY_STEP)
            if opts.onChange then opts.onChange(value) end
            return true
        elseif direction == "right" then
            value = math.min(max, value + KEY_STEP)
            if opts.onChange then opts.onChange(value) end
            return true
        end
        return false
    end
    pv.onActivate = function()
        if opts.onRelease then opts.onRelease(value) end
    end

    -- Auto-register into the parent's nav group via walk-up.
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then g:add(pv) end
    end

    return {
        getValue = function() return value end,
        setValue = function(v)
            value = math.max(min, math.min(max, v))
        end,
    }
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Slider.lua loaded.")
