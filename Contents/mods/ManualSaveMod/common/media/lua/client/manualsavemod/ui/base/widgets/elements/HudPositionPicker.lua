-- UI/Base/Widgets/Elements/HudPositionPicker.lua
-- Interactive HUD position picker: click-to-place schematic, 3x3 compass preset grid,
-- snap guides, coordinates readout, and a Hide toggle.
-- All position state is persisted immediately via Config keys.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

-- 9 natural positions used by applySnap to gently pull the indicator toward
-- standard HUD anchors during drag (mouse / keyboard / joypad). The visible
-- 3x3 compass preset grid has been removed; only the snap behaviour remains.
local DEFAULT_ANCHORS = {
    { id="tl", x=0.05, y=0.08 }, { id="tc", x=0.50, y=0.08 }, { id="tr", x=0.95, y=0.08 },
    { id="ml", x=0.05, y=0.50 }, { id="mc", x=0.50, y=0.50 }, { id="mr", x=0.95, y=0.50 },
    { id="bl", x=0.05, y=0.88 }, { id="bc", x=0.50, y=0.88 }, { id="br", x=0.95, y=0.88 },
}
local SNAP_THRESH = 0.06

-- opts: {
--   x?, y, w
--   configKeyX      string   Config key for normalised X (stored as "0.500")
--   configKeyY      string   Config key for normalised Y
--   configKeyHide   string   Config key for hide flag ("0" / "1")
--   anchors?        array    { id, x, y } snap targets (default: 9-point grid)
--   hideHudKey?     string   i18n key for Hide HUD button
--   hiddenTextKey?  string   i18n key for the "hidden" overlay text
--   anchorPrefix?   string   i18n prefix for anchor names  (default "UI_MSM_Anchor_")
--   customKey?      string   i18n key for "Custom" position label
-- }
function ManualSave.makeHudPositionPicker(parent, opts)
    local TH          = ManualSave.Theme
    local anchors     = opts.anchors    or DEFAULT_ANCHORS
    local anchorPfx   = opts.anchorPrefix or "UI_MSM_Anchor_"
    local customKey   = opts.customKey    or "UI_MSM_Anchor_Custom"
    local hideHudKey  = opts.hideHudKey   or "UI_MSM_Settings_HideHud"
    local hiddenTxtKey= opts.hiddenTextKey or "UI_MSM_Settings_PreviewHudHidden"

    -- Live state (normalised 0-1 coords)
    local posX    = tonumber(ManualSave.Config.get(opts.configKeyX)) or 0.500
    local posY    = tonumber(ManualSave.Config.get(opts.configKeyY)) or 0.880
    local hidden  = ManualSave.Config.get(opts.configKeyHide) == "1"
    local dragging = false
    local snapVX   = nil
    local snapHY   = nil
    -- Edit mode (keyboard / joypad): when true, arrows move the indicator and
    -- Up/Down/Left/Right are NOT exit directions. Toggled on Activate (Enter/A),
    -- exited by Activate again or Cancel (Esc/B). The schematic widget consumes
    -- Cancel while in edit so the surrounding screen does not close.
    local editing = false

    local function findAnchor()
        for _, a in ipairs(anchors) do
            if math.abs(a.x - posX) < 0.001 and math.abs(a.y - posY) < 0.001 then
                return a.id
            end
        end
        return nil
    end

    local function applySnap(nx, ny)
        snapVX = nil; snapHY = nil
        local bestDX, bestDY = SNAP_THRESH, SNAP_THRESH
        for _, a in ipairs(anchors) do
            local dx = math.abs(a.x - nx)
            local dy = math.abs(a.y - ny)
            if dx < bestDX then nx = a.x; bestDX = dx; snapVX = a.x end
            if dy < bestDY then ny = a.y; bestDY = dy; snapHY = a.y end
        end
        return nx, ny
    end

    local function savePosXY()
        ManualSave.Config.set(opts.configKeyX, string.format("%.3f", posX))
        ManualSave.Config.set(opts.configKeyY, string.format("%.3f", posY))
    end

    -- Layout
    -- Left side: schematic + coordinates readout.
    -- Right side: a single "Hide HUD" toggle button, vertically centred.
    -- The 3x3 compass preset grid has been removed (snap logic preserved
    -- via DEFAULT_ANCHORS so the indicator still snaps near the 9 natural
    -- positions when dragged with mouse / keyboard / joypad).
    local HIDE_W    = 120
    local COMBO_GAP = TH.GAP * 2
    local w         = opts.w
    local schW      = w - COMBO_GAP - HIDE_W
    local SCH_H     = 98
    local COMBO_H   = SCH_H + 4 + TH.FONT_HGT_SMALL

    local combo = ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y, w=w, h=COMBO_H,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
    })

    -- Schematic (click-to-place + drag, keyboard arrows nudge the indicator)
    local schematic = ManualSave.makePanel(combo, {
        x=0, y=0, w=schW, h=SCH_H,
        bg={ r=TH.BG_R * 0.55, g=TH.BG_G * 0.50, b=TH.BG_B * 0.45, a=1 }, border=false,
        prerender = function(pv)
            local TH2 = ManualSave.Theme

            if dragging then
                local mdown = false
                pcall(function() mdown = isMouseButtonDown(0) end)
                if not mdown then
                    dragging = false; snapVX = nil; snapHY = nil; savePosXY()
                else
                    local ax, ay = 0, 0
                    pcall(function() ax = pv:getAbsoluteX(); ay = pv:getAbsoluteY() end)
                    local nx = math.max(0.02, math.min(0.98, ((tonumber(getMouseX()) or 0) - ax) / pv.width))
                    local ny = math.max(0.02, math.min(0.98, ((tonumber(getMouseY()) or 0) - ay) / pv.height))
                    posX, posY = applySnap(nx, ny)
                end
            end

            pv:drawRectBorder(0, 0, pv.width, pv.height, 0.35,
                TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)

            if hidden then
                local txt = getText(hiddenTxtKey)
                local tw  = getTextManager():MeasureStringX(UIFont.Small, txt)
                pv:drawText(txt,
                    math.floor((pv.width  - tw) / 2),
                    math.floor((pv.height - TH2.FONT_HGT_SMALL) / 2),
                    TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.55, UIFont.Small)
            else
                -- Minimap: moodle strip, player dot, hotbar
                pv:drawRect(pv.width - 9, 3, 6, 28, 0.12, 1, 1, 1)
                pv:drawRect(math.floor(pv.width/2)-2, math.floor(pv.height/2)-2, 4, 4, 0.20, 1, 1, 1)
                local hbW = math.floor(pv.width * 0.38)
                local hbX = math.floor((pv.width - hbW) / 2)
                pv:drawRectBorder(hbX, pv.height - 7, hbW, 4, 0.22, TH2.DIM_R, TH2.DIM_G, TH2.DIM_B)

                -- Snap guides, tinted accent so they match the indicator pill
                -- and the rest of the mod's accent palette.
                if snapVX then
                    pv:drawRect(math.floor(snapVX * pv.width), 0, 1, pv.height, 0.5,
                        TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                end
                if snapHY then
                    pv:drawRect(0, math.floor(snapHY * pv.height), pv.width, 1, 0.5,
                        TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                end

                -- Indicator pill
                local IND_W, IND_H = 34, 7
                local indX = math.max(0, math.min(pv.width  - IND_W,
                    math.floor(posX * pv.width)  - math.floor(IND_W / 2)))
                local indY = math.max(0, math.min(pv.height - IND_H,
                    math.floor(posY * pv.height) - math.floor(IND_H / 2)))
                pv:drawRect(indX, indY, IND_W, IND_H, 0.9,
                    TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            end

            -- InputNav focus ring (drawn last so it sits on top).
            -- In edit mode the ring is drawn unconditionally (keyboardActive
            -- check skipped) and tinted accent so the user can see they are
            -- modifying the position, not just hovering.
            local showRing = editing or
                (pv.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive)
            if showRing then
                local rR = editing and TH2.ACCENT_R or TH2.FOCUS_R
                local rG = editing and TH2.ACCENT_G or TH2.FOCUS_G
                local rB = editing and TH2.ACCENT_B or TH2.FOCUS_B
                for i = 0, TH2.FOCUS_BW - 1 do
                    pv:drawRectBorder(i, i, pv.width - i*2, pv.height - i*2, 1,
                        rR, rG, rB)
                end
            end
        end,
        onMouseDown = function(sp, mx, my)
            if hidden then return end
            local indPx = math.floor(posX * sp.width)
            local indPy = math.floor(posY * sp.height)
            if math.abs(mx - indPx) <= 20 and math.abs(my - indPy) <= 12 then
                dragging = true
            else
                local nx = math.max(0.02, math.min(0.98, mx / sp.width))
                local ny = math.max(0.02, math.min(0.98, my / sp.height))
                posX, posY = applySnap(nx, ny)
                savePosXY()
            end
        end,
        onMouseUp = function()
            if dragging then
                dragging = false; snapVX = nil; snapHY = nil; savePosXY()
            end
        end,
    })
    -- Keyboard / joypad arrow handling:
    --   - Outside edit mode: arrows return false so FocusGroup moves focus to
    --     the next/prev widget normally. The schematic acts as a plain focusable.
    --   - Inside edit mode: arrows nudge the indicator (3% per press, smooth
    --     with key auto-repeat) and are consumed so focus stays here.
    schematic.onArrow = function(_, direction)
        if not editing then return false end
        if hidden then return false end
        local STEP = 0.03
        if direction == "up"    then posY = math.max(0.02, posY - STEP)
        elseif direction == "down"  then posY = math.min(0.98, posY + STEP)
        elseif direction == "left"  then posX = math.max(0.02, posX - STEP)
        elseif direction == "right" then posX = math.min(0.98, posX + STEP)
        else return false
        end
        snapVX, snapHY = nil, nil
        savePosXY()
        return true
    end
    -- Activate (Enter / A) toggles edit mode. Saving happens on every nudge,
    -- so leaving edit just commits the current value and unlocks navigation.
    schematic.onActivate = function()
        if hidden then return end
        editing = not editing
    end
    -- Cancel (Esc / B) while in edit exits edit mode without propagating to
    -- the FocusManager's onCancel (which would close the surrounding screen).
    schematic.onCancel = function()
        if not editing then return false end
        editing = false
        return true
    end

    -- Coordinates readout below schematic
    ManualSave.makePanel(combo, {
        x=0, y=SCH_H + 4, w=schW, h=TH.FONT_HGT_SMALL,
        bg={r=0,g=0,b=0,a=0}, border=false,
        prerender = function(pv)
            local TH2 = ManualSave.Theme
            local txt
            if hidden then
                txt = getText(hiddenTxtKey)
            else
                local aid   = findAnchor()
                local aname = aid and getText(anchorPfx .. aid) or getText(customKey)
                txt = aname
                    .. "   X " .. string.format("%.1f", posX * 100) .. "%"
                    .. "   Y " .. string.format("%.1f", posY * 100) .. "%"
            end
            pv:drawText(txt, 0, 0, TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.7, UIFont.Small)
        end,
    })

    -- Hide HUD toggle button, vertically centred on the right side of the
    -- combo. The 3x3 compass preset grid has been removed; the snap logic
    -- (defined above via DEFAULT_ANCHORS + applySnap) still nudges the
    -- indicator toward the 9 natural positions during mouse / keyboard drag.
    local hideX = schW + COMBO_GAP
    local hideY = math.floor((COMBO_H - TH.BUTTON_HGT) / 2)
    local hideBtn = ManualSave.makePanel(combo, {
        x=hideX, y=hideY, w=HIDE_W, h=TH.BUTTON_HGT,
        bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }, border=false,
        prerender = function(pv)
            local TH2  = ManualSave.Theme
            local over = false
            pcall(function() over = pv:isMouseOver() end)
            if hidden then
                pv:drawRect(0, 0, pv.width, pv.height, 0.12,
                    TH2.DANGER_R, TH2.DANGER_G, TH2.DANGER_B)
                pv:drawRectBorder(0, 0, pv.width, pv.height, 0.55,
                    TH2.DANGER_R, TH2.DANGER_G, TH2.DANGER_B)
            else
                if over then pv:drawRect(0, 0, pv.width, pv.height, 0.06, 1, 1, 1) end
                pv:drawRectBorder(0, 0, pv.width, pv.height, 0.30,
                    TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
            end
            local dotSz = 6
            local dotX  = 8
            local dotY  = math.floor((pv.height - dotSz) / 2)
            if hidden then
                pv:drawRect(dotX, dotY, dotSz, dotSz, 0.9,
                    TH2.DANGER_R, TH2.DANGER_G, TH2.DANGER_B)
            else
                pv:drawRectBorder(dotX, dotY, dotSz, dotSz, 0.55,
                    TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B)
            end
            local lbl = getText(hideHudKey)
            local tR  = hidden and TH2.DANGER_R or TH2.MUTED_R
            local tG  = hidden and TH2.DANGER_G or TH2.MUTED_G
            local tB  = hidden and TH2.DANGER_B or TH2.MUTED_B
            local ty2 = math.floor((pv.height - TH2.FONT_HGT_SMALL) / 2)
            pv:drawText(lbl, dotX + dotSz + 6, ty2, tR, tG, tB, 1, UIFont.Small)
            -- InputNav focus ring (last so it sits on top)
            if pv.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
                for i = 0, TH2.FOCUS_BW - 1 do
                    pv:drawRectBorder(i, i, pv.width - i*2, pv.height - i*2, 1,
                        TH2.FOCUS_R, TH2.FOCUS_G, TH2.FOCUS_B)
                end
            end
        end,
        onMouseDown = function()
            hidden = not hidden
            ManualSave.Config.set(opts.configKeyHide, hidden and "1" or "0")
            return true
        end,
    })
    -- Keyboard: Enter toggles hidden.
    hideBtn.onActivate = function()
        hidden = not hidden
        ManualSave.Config.set(opts.configKeyHide, hidden and "1" or "0")
    end

    -- Auto-register the two interactive zones in the parent's nav group.
    -- schematic = position editor (edit mode toggle inside).
    -- hideBtn   = HUD visibility toggle.
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then
            g:add(schematic)
            g:add(hideBtn)
        end
    end

    return COMBO_H
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/HudPositionPicker.lua loaded.")
