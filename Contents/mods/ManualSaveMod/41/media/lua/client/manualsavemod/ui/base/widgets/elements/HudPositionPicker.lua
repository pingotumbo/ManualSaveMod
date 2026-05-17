-- UI/Base/Widgets/Elements/HudPositionPicker.lua
-- Interactive HUD position picker: click-to-place schematic, 3x3 compass preset grid,
-- snap guides, coordinates readout, and a Hide toggle.
-- All position state is persisted immediately via Config keys.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

local DEFAULT_ANCHORS = {
    { id="tl", x=0.05, y=0.08 }, { id="tc", x=0.50, y=0.08 }, { id="tr", x=0.95, y=0.08 },
    { id="ml", x=0.05, y=0.50 }, { id="mc", x=0.50, y=0.50 }, { id="mr", x=0.95, y=0.50 },
    { id="bl", x=0.05, y=0.88 }, { id="bc", x=0.50, y=0.88 }, { id="br", x=0.95, y=0.88 },
}
local DEFAULT_ANCHOR_GRID = {
    { "tl", "tc", "tr" },
    { "ml", "mc", "mr" },
    { "bl", "bc", "br" },
}
local SNAP_THRESH = 0.06

-- opts: {
--   x?, y, w
--   configKeyX      string   Config key for normalised X (stored as "0.500")
--   configKeyY      string   Config key for normalised Y
--   configKeyHide   string   Config key for hide flag ("0" / "1")
--   anchors?        array    { id, x, y } preset list (default: 9-point grid)
--   anchorGrid?     array    3×3 table of anchor ids for compass display
--   compassKey?     string   i18n key for compass label
--   hideHudKey?     string   i18n key for Hide HUD button
--   hiddenTextKey?  string   i18n key for the "hidden" overlay text
--   anchorPrefix?   string   i18n prefix for anchor names  (default "UI_MSM_Anchor_")
--   customKey?      string   i18n key for "Custom" position label
-- }
function ManualSave.makeHudPositionPicker(parent, opts)
    local TH          = ManualSave.Theme
    local anchors     = opts.anchors    or DEFAULT_ANCHORS
    local anchorGrid  = opts.anchorGrid or DEFAULT_ANCHOR_GRID
    local anchorPfx   = opts.anchorPrefix or "UI_MSM_Anchor_"
    local customKey   = opts.customKey    or "UI_MSM_Anchor_Custom"
    local compassKey  = opts.compassKey   or "UI_MSM_Settings_Compass"
    local hideHudKey  = opts.hideHudKey   or "UI_MSM_Settings_HideHud"
    local hiddenTxtKey= opts.hiddenTextKey or "UI_MSM_Settings_PreviewHudHidden"

    -- Live state (normalised 0-1 coords)
    local posX    = tonumber(ManualSave.Config.get(opts.configKeyX)) or 0.500
    local posY    = tonumber(ManualSave.Config.get(opts.configKeyY)) or 0.880
    local hidden  = ManualSave.Config.get(opts.configKeyHide) == "1"
    local dragging = false
    local snapVX   = nil
    local snapHY   = nil

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
    local COMP_W    = 120
    local COMP_H    = 68
    local COMBO_GAP = TH.GAP * 2
    local w         = opts.w
    local schW      = w - COMBO_GAP - COMP_W
    local SCH_H     = 98
    local CELL_GAP  = 2
    local cellW     = math.floor((COMP_W - CELL_GAP * 2) / 3)
    local cellH     = math.floor((COMP_H - CELL_GAP * 2) / 3)
    local COMBO_H   = math.max(SCH_H + 4 + TH.FONT_HGT_SMALL,
                               TH.FONT_HGT_SMALL + 2 + COMP_H + TH.GAP + TH.BUTTON_HGT)

    local combo = ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y, w=w, h=COMBO_H,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
    })

    -- Schematic (click-to-place + drag)
    ManualSave.makePanel(combo, {
        x=0, y=0, w=schW, h=SCH_H,
        bg={ r=TH.BG_R * 0.55, g=TH.BG_G * 0.50, b=TH.BG_B * 0.45, a=1 }, border=false,
        prerender = function(pv)
            local TH2 = ManualSave.Theme

            if dragging then
                local mdown = false
                pcall(function() mdown = getCore():isLeftMouseButtonDown() end)
                if not mdown then
                    dragging = false; snapVX = nil; snapHY = nil; savePosXY()
                else
                    local ax, ay = 0, 0
                    pcall(function() ax = pv:getAbsoluteX(); ay = pv:getAbsoluteY() end)
                    local nx = math.max(0.02, math.min(0.98, (getMouseX() - ax) / pv.width))
                    local ny = math.max(0.02, math.min(0.98, (getMouseY() - ay) / pv.height))
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
                return
            end

            -- Minimap: moodle strip, player dot, hotbar
            pv:drawRect(pv.width - 9, 3, 6, 28, 0.12, 1, 1, 1)
            pv:drawRect(math.floor(pv.width/2)-2, math.floor(pv.height/2)-2, 4, 4, 0.20, 1, 1, 1)
            local hbW = math.floor(pv.width * 0.38)
            local hbX = math.floor((pv.width - hbW) / 2)
            pv:drawRectBorder(hbX, pv.height - 7, hbW, 4, 0.22, TH2.DIM_R, TH2.DIM_G, TH2.DIM_B)

            -- Snap guides
            if snapVX then
                pv:drawRect(math.floor(snapVX * pv.width), 0, 1, pv.height, 0.5, 0.30, 0.68, 0.26)
            end
            if snapHY then
                pv:drawRect(0, math.floor(snapHY * pv.height), pv.width, 1, 0.5, 0.30, 0.68, 0.26)
            end

            -- Indicator pill
            local IND_W, IND_H = 34, 7
            local indX = math.max(0, math.min(pv.width  - IND_W,
                math.floor(posX * pv.width)  - math.floor(IND_W / 2)))
            local indY = math.max(0, math.min(pv.height - IND_H,
                math.floor(posY * pv.height) - math.floor(IND_H / 2)))
            pv:drawRect(indX, indY, IND_W, IND_H, 0.9,
                TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
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

    -- Compass label
    local compassX = schW + COMBO_GAP
    ManualSave.makePanel(combo, {
        x=compassX, y=0, w=COMP_W, h=TH.FONT_HGT_SMALL,
        bg={r=0,g=0,b=0,a=0}, border=false,
        prerender = function(pv)
            local TH2 = ManualSave.Theme
            pv:drawText(getText(compassKey), 0, 0,
                TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.6, UIFont.Small)
        end,
    })

    -- Compass 3x3 grid
    local gridY = TH.FONT_HGT_SMALL + 2
    for row = 0, 2 do
        for col = 0, 2 do
            local aid = anchorGrid[row + 1] and anchorGrid[row + 1][col + 1]
            if aid then
                local cx2 = compassX + col * (cellW + CELL_GAP)
                local cy2 = gridY    + row * (cellH + CELL_GAP)
                local capturedId = aid
                ManualSave.makePanel(combo, {
                    x=cx2, y=cy2, w=cellW, h=cellH,
                    bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }, border=false,
                    prerender = function(pv)
                        local TH2    = ManualSave.Theme
                        local active = (findAnchor() == capturedId)
                        local over   = false
                        pcall(function() over = pv:isMouseOver() end)
                        if active then
                            pv:drawRect(0, 0, pv.width, pv.height, 0.10,
                                TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                            pv:drawRectBorder(0, 0, pv.width, pv.height, 0.55,
                                TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                        else
                            if over then
                                pv:drawRect(0, 0, pv.width, pv.height, 0.06, 1, 1, 1)
                            end
                            pv:drawRectBorder(0, 0, pv.width, pv.height, 0.25,
                                TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
                        end
                        local barW = active and 18 or 14
                        local barH = active and 3  or 2
                        local bA   = active and 0.9 or 0.35
                        local bR   = active and TH2.ACCENT_R or TH2.DIM_R
                        local bG   = active and TH2.ACCENT_G or TH2.DIM_G
                        local bB2  = active and TH2.ACCENT_B or TH2.DIM_B
                        pv:drawRect(
                            math.floor((pv.width  - barW) / 2),
                            math.floor((pv.height - barH) / 2),
                            barW, barH, bA, bR, bG, bB2)
                    end,
                    onMouseDown = function()
                        for _, a in ipairs(anchors) do
                            if a.id == capturedId then
                                posX, posY = a.x, a.y
                                hidden = false; snapVX = nil; snapHY = nil
                                ManualSave.Config.set(opts.configKeyX, string.format("%.3f", posX))
                                ManualSave.Config.set(opts.configKeyY, string.format("%.3f", posY))
                                ManualSave.Config.set(opts.configKeyHide, "0")
                                break
                            end
                        end
                        return true
                    end,
                })
            end
        end
    end

    -- Hide HUD toggle button
    local hideBtnY = gridY + 3 * cellH + 2 * CELL_GAP + TH.GAP
    ManualSave.makePanel(combo, {
        x=compassX, y=hideBtnY, w=COMP_W, h=TH.BUTTON_HGT,
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
        end,
        onMouseDown = function()
            hidden = not hidden
            ManualSave.Config.set(opts.configKeyHide, hidden and "1" or "0")
            return true
        end,
    })

    return COMBO_H
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/HudPositionPicker.lua loaded.")
