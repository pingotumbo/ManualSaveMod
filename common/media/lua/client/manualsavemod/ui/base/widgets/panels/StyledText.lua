-- UI/Base/Widgets/Panels/StyledText.lua
-- Scrollable styled-text panel. Full scroll state management (wheel + drag).
-- Used by HelpScreen content area; exported as a generic factory.
---@diagnostic disable: undefined-global, undefined-doc-name

ManualSave = ManualSave or {}

-- Creates a scrollable styled-text panel and adds it to parent.
--
-- Line format: { text:string, style:string? }
-- Styles:
--   ""          vertical gap
--   header      accent section title + horizontal rule
--   sub         bright subheading
--   body        normal body text (slight indent)
--   dim         muted text (slight indent)
--   warn        danger-coloured text (slight indent)
--   good        green success text (slight indent)
--   callout     accent left-bar callout
--   callout_w   danger left-bar callout
--   callout_g   green left-bar callout
--   check       ">" bullet item
--   gloss_t     glossary term (accent)
--   gloss_d     glossary definition (muted, indented)
--
-- opts:
--   x, y, w, h   number
--   getLines     fun(): { {string, string?} }[]
--   bg           { r, g, b }?   background (default Theme BG)
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, getLines:fun():table, bg:{r:number,g:number,b:number}? }
---@return { panel:ISPanel, resetScroll:fun() }
function ManualSave.makeScrollText(parent, opts)
    local SCROLL = 10
    local GOOD_R, GOOD_G, GOOD_B = 0.37, 0.63, 0.35

    local w = opts.w
    local h = opts.h

    local scrollY   = 0
    local sbDrag    = false
    local sbDragY   = 0
    local sbDragScr = 0

    local function computeH(lines)
        local TH   = ManualSave.Theme
        local y    = TH.PAD
        local lh   = TH.FONT_HGT_SMALL + 3
        local gapH = math.floor(TH.FONT_HGT_SMALL * 0.55)
        for _, ln in ipairs(lines) do
            local style = ln[2]
            if not style or style == "" then
                y = y + gapH
            elseif style == "header" then
                if y > TH.PAD then y = y + TH.GAP end
                y = y + lh + 1 + TH.GAP
            else
                y = y + lh
            end
        end
        return y + TH.PAD
    end

    local function drawLines(self2, lines, drawW)
        local TH   = ManualSave.Theme
        local lh   = TH.FONT_HGT_SMALL + 3
        local gapH = math.floor(TH.FONT_HGT_SMALL * 0.55)
        local x2   = TH.PAD
        local y2   = TH.PAD - scrollY
        for _, ln in ipairs(lines) do
            local text, style = ln[1], ln[2]
            if not style or style == "" then
                y2 = y2 + gapH
            elseif style == "header" then
                if y2 + scrollY > TH.PAD then y2 = y2 + TH.GAP end
                self2:drawText(text, x2, y2, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 0.95, UIFont.Small)
                y2 = y2 + lh
                self2:drawRect(x2, y2, drawW - TH.PAD * 2, 1, 0.3, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
                y2 = y2 + 1 + TH.GAP
            elseif style == "sub" then
                self2:drawText(text, x2, y2, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Small)
                y2 = y2 + lh
            elseif style == "body" then
                self2:drawText(text, x2+8, y2, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 0.80, UIFont.Small)
                y2 = y2 + lh
            elseif style == "dim" then
                self2:drawText(text, x2+8, y2, TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 1, UIFont.Small)
                y2 = y2 + lh
            elseif style == "warn" then
                self2:drawText(text, x2+8, y2, TH.DANGER_R, TH.DANGER_G, TH.DANGER_B, 0.9, UIFont.Small)
                y2 = y2 + lh
            elseif style == "good" then
                self2:drawText(text, x2+8, y2, GOOD_R, GOOD_G, GOOD_B, 0.9, UIFont.Small)
                y2 = y2 + lh
            elseif style == "callout" then
                self2:drawRect(x2+2, y2, 3, lh, 1, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
                self2:drawText(text, x2+14, y2, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 0.90, UIFont.Small)
                y2 = y2 + lh
            elseif style == "callout_w" then
                self2:drawRect(x2+2, y2, 3, lh, 1, TH.DANGER_R, TH.DANGER_G, TH.DANGER_B)
                self2:drawText(text, x2+14, y2, TH.DANGER_R, TH.DANGER_G, TH.DANGER_B, 0.85, UIFont.Small)
                y2 = y2 + lh
            elseif style == "callout_g" then
                self2:drawRect(x2+2, y2, 3, lh, 1, GOOD_R, GOOD_G, GOOD_B)
                self2:drawText(text, x2+14, y2, GOOD_R, GOOD_G, GOOD_B, 0.85, UIFont.Small)
                y2 = y2 + lh
            elseif style == "check" then
                self2:drawText(">", x2+6, y2, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 1, UIFont.Small)
                self2:drawText(text, x2+16, y2, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 0.80, UIFont.Small)
                y2 = y2 + lh
            elseif style == "gloss_t" then
                self2:drawText(text, x2, y2, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 1, UIFont.Small)
                y2 = y2 + lh
            elseif style == "gloss_d" then
                self2:drawText(text, x2+8, y2, TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.90, UIFont.Small)
                y2 = y2 + lh
            end
        end
    end

    local panel = ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y or 0, w=w, h=h,
        bg={ r=opts.bg and opts.bg.r or ManualSave.Theme.BG_R,
             g=opts.bg and opts.bg.g or ManualSave.Theme.BG_G,
             b=opts.bg and opts.bg.b or ManualSave.Theme.BG_B, a=1 },
        border=false,
        prerender = function(self2)
            local TH     = ManualSave.Theme
            local lines  = opts.getLines()
            local totalH = computeH(lines)
            local needSB = totalH > h
            local drawW  = w - (needSB and SCROLL + 2 or 0)
            self2:setStencilRect(0, 0, drawW, h)
            drawLines(self2, lines, drawW)
            self2:clearStencilRect()
            if needSB then
                local maxScr = totalH - h
                local ratio  = h / totalH
                local thumbH = math.max(20, math.floor(h * ratio))
                local thumbY = math.floor((scrollY / maxScr) * (h - thumbH))
                local sx     = w - SCROLL
                self2:drawRect(sx, 0, SCROLL, h, 0.35, TH.LINE_R, TH.LINE_G, TH.LINE_B)
                self2:drawRect(sx + 2, thumbY + 1, SCROLL - 4, thumbH - 2, 0.55,
                    TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
            end
        end,
        onMouseWheel = function(_, delta)
            local lines  = opts.getLines()
            local totalH = computeH(lines)
            local maxScr = math.max(0, totalH - h)
            if maxScr == 0 then return false end
            local step = (ManualSave.Theme.FONT_HGT_SMALL + 3) * 3
            scrollY = math.max(0, math.min(maxScr, scrollY - delta * step))
            return true
        end,
        onMouseDown = function(_, mx, my)
            local lines  = opts.getLines()
            local totalH = computeH(lines)
            if totalH <= h then return end
            if mx < w - SCROLL then return end
            sbDrag    = true
            sbDragY   = my
            sbDragScr = scrollY
            return true
        end,
        onMouseMove = function(self2)
            if not sbDrag then return end
            if not isMouseButtonDown(0) then ---@diagnostic disable-line
                sbDrag = false; return
            end
            local lines  = opts.getLines()
            local totalH = computeH(lines)
            local maxScr = totalH - h
            if maxScr <= 0 then sbDrag = false; return end
            local thumbH = math.max(20, math.floor(h * h / totalH))
            local ratio  = maxScr / (h - thumbH)
            scrollY = math.max(0, math.min(maxScr,
                sbDragScr + (self2:getMouseY() - sbDragY) * ratio))
        end,
        onMouseUp = function() sbDrag = false end,
    })

    local obj = { panel = panel }
    function obj.resetScroll() scrollY = 0 end
    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/StyledText.lua loaded.")
