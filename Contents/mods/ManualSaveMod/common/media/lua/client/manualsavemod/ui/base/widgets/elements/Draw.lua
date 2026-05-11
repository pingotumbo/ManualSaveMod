-- UI/Base/Elements/Draw.lua
-- Visual helper functions called inside panel prerender callbacks.
-- These are NOT widgets — they draw directly into the panel passed as first argument.
---@diagnostic disable: undefined-global

ManualSave       = ManualSave or {}
ManualSave.Draw  = ManualSave.Draw or {}

local T = function() return ManualSave.Theme end

-- ── Badge ─────────────────────────────────────────────────────────────────────

-- Draws a small labelled pill (e.g. "QUICK", "NATIVE", "IMPORTED").
-- style: "accent" | "native" | "danger" | "ok" | "dim"
--        or a table { r, g, b } for a custom colour.
---@param panel  ISPanel
---@param x      number
---@param y      number
---@param text   string
---@param style  "accent"|"native"|"danger"|"ok"|"dim"|{r:number,g:number,b:number}
function ManualSave.Draw.badge(panel, x, y, text, style)
    local TH = T()
    local r, g, b
    if type(style) == "table" then
        r, g, b = style.r, style.g, style.b
    elseif style == "native" then
        r, g, b = TH.NATIVE_R, TH.NATIVE_G, TH.NATIVE_B
    elseif style == "danger" then
        r, g, b = TH.DANGER_R, TH.DANGER_G, TH.DANGER_B
    elseif style == "ok" then
        r, g, b = 0.30, 0.72, 0.36
    elseif style == "dim" then
        r, g, b = TH.DIM_R, TH.DIM_G, TH.DIM_B
    else -- "accent" and default
        r, g, b = TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B
    end
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local tw = getTextManager():MeasureStringX(UIFont.Small, text)
    local pw, ph = tw + 10, fh + 4
    panel:drawRect(x, y, pw, ph, 0.12, r, g, b)
    panel:drawRectBorder(x, y, pw, ph, 0.65, r, g, b)
    panel:drawText(text, x + 5, y + 2, r, g, b, 1, UIFont.Small)
end

-- ── Row highlight ─────────────────────────────────────────────────────────────

-- Draws a left-anchored horizontal gradient for a selected list row.
-- A solid accent stripe is drawn on the left edge.
---@param panel      ISPanel
---@param y          number   top of the row (relative to panel)
---@param w          number   row width
---@param h          number   row height
---@param steps      number?  gradient steps (default 32)
---@param totalAlpha number?  total opacity of the gradient (default 0.42)
function ManualSave.Draw.rowHighlight(panel, y, w, h, steps, totalAlpha)
    local TH   = T()
    steps      = steps or 32
    totalAlpha = totalAlpha or 0.42
    local perA = totalAlpha / steps
    for i = 0, steps - 1 do
        local rw = math.floor(w * (steps - i) / steps)
        panel:drawRect(0, y, rw, h - 1, perA, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
    end
    panel:drawRect(0, y, 3, h - 1, 1, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
end

-- ── Accent bar ────────────────────────────────────────────────────────────────

-- Draws a thin horizontal bar in accent colour (used at the top of panels and sections).
---@param panel  ISPanel
---@param x      number
---@param y      number
---@param w      number
---@param h      number?  bar thickness (default 2)
---@param dimmed boolean? if true draws at 70% brightness
function ManualSave.Draw.accentBar(panel, x, y, w, h, dimmed)
    local TH = T()
    h        = h or 2
    local f  = dimmed and 0.7 or 1.0
    panel:drawRect(x, y, w, h, 1, TH.ACCENT_R * f, TH.ACCENT_G * f, TH.ACCENT_B * f)
end

-- ── Separator ─────────────────────────────────────────────────────────────────

-- Draws a 1-pixel horizontal divider line.
---@param panel  ISPanel
---@param x      number
---@param y      number
---@param w      number
---@param alpha  number?  opacity (default 1)
function ManualSave.Draw.separator(panel, x, y, w, alpha)
    local TH = T()
    panel:drawRect(x, y, w, 1, alpha or 1, TH.LINE_R, TH.LINE_G, TH.LINE_B)
end

-- ── Thumbnail fade ────────────────────────────────────────────────────────────

-- Draws a black gradient over the bottom portion of a thumbnail or banner image.
-- Call this after drawing the texture, before drawing any text on top.
---@param panel    ISPanel
---@param w        number  panel width
---@param h        number  panel height
---@param coverage number? fraction of height covered by the fade (default 0.55)
function ManualSave.Draw.thumbnailFade(panel, w, h, coverage)
    coverage      = coverage or 0.55
    local gradH   = math.floor(h * coverage)
    local steps   = 24
    local perA    = 0.85 / steps
    for i = 0, steps - 1 do
        local rh = math.floor(gradH * (i + 1) / steps)
        panel:drawRect(0, h - rh, w, rh, perA, 0, 0, 0)
    end
end

-- ── Circle border ─────────────────────────────────────────────────────────────

-- Draws an octagon-approximated circle border (no rounded-rect API in PZ).
-- Used for info/circle-style buttons.
---@param panel ISPanel
---@param x number   top-left x
---@param y number   top-left y
---@param w number
---@param h number
---@param alpha number
---@param r number
---@param g number
---@param b number
function ManualSave.Draw.circleBorder(panel, x, y, w, h, alpha, r, g, b)
    local c = math.max(2, math.floor(math.min(w, h) * 0.22))
    panel:drawRect(x + c,     y,         w - c*2, 1,       alpha, r, g, b)
    panel:drawRect(x + c,     y + h - 1, w - c*2, 1,       alpha, r, g, b)
    panel:drawRect(x,         y + c,     1,       h - c*2, alpha, r, g, b)
    panel:drawRect(x + w - 1, y + c,     1,       h - c*2, alpha, r, g, b)
    panel:drawRect(x + c - 1,     y + 1,     1, 1, alpha, r, g, b)
    panel:drawRect(x + w - c,     y + 1,     1, 1, alpha, r, g, b)
    panel:drawRect(x + c - 1,     y + h - 2, 1, 1, alpha, r, g, b)
    panel:drawRect(x + w - c,     y + h - 2, 1, 1, alpha, r, g, b)
end

-- ── Pixel circle ─────────────────────────────────────────────────────────────

-- Draws a 1-pixel-wide circle border using the Bresenham mid-point algorithm.
---@param panel ISPanel
---@param cx number  centre pixel (integer)
---@param cy number
---@param r  number  radius in pixels
---@param alpha number
---@param cr number
---@param cg number
---@param cb number
function ManualSave.Draw.pixelCircle(panel, cx, cy, r, alpha, cr, cg, cb)
    local x, y = r, 0
    local p = 1 - r
    while x >= y do
        panel:drawRect(cx + x, cy + y, 1, 1, alpha, cr, cg, cb)
        panel:drawRect(cx + y, cy + x, 1, 1, alpha, cr, cg, cb)
        panel:drawRect(cx - y, cy + x, 1, 1, alpha, cr, cg, cb)
        panel:drawRect(cx - x, cy + y, 1, 1, alpha, cr, cg, cb)
        panel:drawRect(cx - x, cy - y, 1, 1, alpha, cr, cg, cb)
        panel:drawRect(cx - y, cy - x, 1, 1, alpha, cr, cg, cb)
        panel:drawRect(cx + y, cy - x, 1, 1, alpha, cr, cg, cb)
        panel:drawRect(cx + x, cy - y, 1, 1, alpha, cr, cg, cb)
        y = y + 1
        if p < 0 then
            p = p + 2 * y + 1
        else
            x = x - 1
            p = p + 2 * (y - x) + 1
        end
    end
end

-- ── Sort arrow ────────────────────────────────────────────────────────────────

-- Draws a small 5-wide 4-tall triangle pointing up or down.
---@param panel ISPanel
---@param x number  top-left x of the triangle bounding box
---@param y number  top-left y
---@param up boolean
---@param r number
---@param g number
---@param b number
---@param alpha number
function ManualSave.Draw.sortArrow(panel, x, y, up, r, g, b, alpha)
    if up then
        panel:drawRect(x + 2, y,     1, 1, alpha, r, g, b)
        panel:drawRect(x + 1, y + 1, 3, 1, alpha, r, g, b)
        panel:drawRect(x,     y + 2, 5, 1, alpha, r, g, b)
        panel:drawRect(x,     y + 3, 5, 1, alpha, r, g, b)
    else
        panel:drawRect(x,     y,     5, 1, alpha, r, g, b)
        panel:drawRect(x,     y + 1, 5, 1, alpha, r, g, b)
        panel:drawRect(x + 1, y + 2, 3, 1, alpha, r, g, b)
        panel:drawRect(x + 2, y + 3, 1, 1, alpha, r, g, b)
    end
end

-- ── Search icon ───────────────────────────────────────────────────────────────

-- Draws a magnifier shape: octagon lens + diagonal handle.
---@param panel ISPanel
---@param cx number  centre x of the lens
---@param cy number  centre y of the lens
---@param r  number  radius of the lens
---@param alpha number
---@param colR number
---@param colG number
---@param colB number
function ManualSave.Draw.searchIcon(panel, cx, cy, r, alpha, colR, colG, colB)
    ManualSave.Draw.circleBorder(panel, cx - r, cy - r, r * 2, r * 2, alpha, colR, colG, colB)
    panel:drawRect(cx + r,     cy + r - 1, 2, 1, alpha, colR, colG, colB)
    panel:drawRect(cx + r + 1, cy + r,     2, 1, alpha, colR, colG, colB)
    panel:drawRect(cx + r + 2, cy + r + 1, 2, 1, alpha, colR, colG, colB)
end

-- ── Expand icon ───────────────────────────────────────────────────────────────

-- Draws four corner-bracket "expand" corners suggesting "open full list".
---@param panel ISPanel
---@param x number   top-left of bounding box
---@param y number
---@param size number  total size in pixels (e.g. 7 or 9)
---@param alpha number
---@param r number
---@param g number
---@param b number
function ManualSave.Draw.expandIcon(panel, x, y, size, alpha, r, g, b)
    local a = math.max(2, math.floor(size * 0.35))   -- arm length (2–3px)
    -- top-left
    panel:drawRect(x,             y,             a,     1,     alpha, r, g, b)
    panel:drawRect(x,             y + 1,         1,     a - 1, alpha, r, g, b)
    -- top-right
    panel:drawRect(x + size - a,  y,             a,     1,     alpha, r, g, b)
    panel:drawRect(x + size - 1,  y + 1,         1,     a - 1, alpha, r, g, b)
    -- bottom-left
    panel:drawRect(x,             y + size - 1,  a,     1,     alpha, r, g, b)
    panel:drawRect(x,             y + size - a,  1,     a - 1, alpha, r, g, b)
    -- bottom-right
    panel:drawRect(x + size - a,  y + size - 1,  a,     1,     alpha, r, g, b)
    panel:drawRect(x + size - 1,  y + size - a,  1,     a - 1, alpha, r, g, b)
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Draw.lua loaded.")
