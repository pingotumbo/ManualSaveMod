-- UI/Base/Widgets/Panels/StyledText.lua
-- Scrollable styled-text panel. Full scroll state management (wheel + drag).
-- Used by HelpScreen content area; exported as a generic factory.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, need-check-nil, inject-field

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

    local w = opts.w
    local h = opts.h

    local scrollY   = 0
    local sbDrag    = false
    local sbDragY   = 0
    local sbDragScr = 0
    -- Frame counter for inline image (animated GIF-like) lines. Bumped once
    -- per prerender; image lines compute their frame index from it via fps.
    local imgTick   = 0

    -- Expand \n within lines (no word-wrap; panel is scrollable). Image lines
    -- carry a table payload instead of a string, so they pass through as-is.
    local function expandLines(rawLines)
        local out = {}
        for _, ln in ipairs(rawLines) do
            local text, style = ln[1] or "", ln[2]
            if style == "image" or type(text) ~= "string" then
                table.insert(out, ln)
            else
                for seg in (text .. "\n"):gmatch("([^\n]*)\n") do
                    table.insert(out, { seg, style })
                end
            end
        end
        return out
    end

    -- Word-wraps a single line of text to fit within maxW pixels using the
    -- given font. Returns a flat list of visual lines (always at least one
    -- entry — empty input yields {""}). A single word longer than maxW is
    -- left on its own line; the stencil rect will clip the overflow.
    local function wrapText(text, font, maxW)
        if not text or text == "" then return { "" } end
        if maxW <= 0 then return { text } end
        local tm = getTextManager()
        if tm:MeasureStringX(font, text) <= maxW then return { text } end
        local out, line = {}, ""
        for word in (text .. " "):gmatch("([^ ]+) ") do
            local try = (line == "") and word or (line .. " " .. word)
            if tm:MeasureStringX(font, try) <= maxW then
                line = try
            else
                if line ~= "" then table.insert(out, line) end
                line = word
            end
        end
        if line ~= "" then table.insert(out, line) end
        if #out == 0 then out[1] = "" end
        return out
    end

    -- Returns the number of visual rows a styled line will occupy after wrapping
    -- against the current panel width. Centralized so computeH and drawLines
    -- can't disagree about wrap boundaries.
    local function wrappedRows(text, style, drawW)
        local s = ManualSave.Styles[style]
        if not s then return { text or "" } end
        local maxW = drawW - ManualSave.Theme.PAD - (s.indent or 0)
        return wrapText(text or "", s.font, maxW)
    end

    local function computeH(lines, drawW)
        local TH   = ManualSave.Theme
        local y    = TH.PAD
        local lh   = TH.FONT_HGT_SMALL + 3
        local gapH = math.floor(TH.FONT_HGT_SMALL * 0.55)
        for _, ln in ipairs(lines) do
            local text, style = ln[1], ln[2]
            if not style or style == "" then
                y = y + gapH
            elseif style == "image" then
                -- text is a table { textures=, fps=, aspect= }
                if y > TH.PAD then y = y + TH.GAP end
                local imgW = drawW - TH.PAD * 2
                local imgH = math.floor(imgW * ((text and text.aspect) or 0.4325))
                y = y + imgH + TH.GAP
            elseif style == "header" then
                if y > TH.PAD then y = y + TH.GAP end
                local rows = wrappedRows(text, style, drawW)
                y = y + lh * #rows + 1 + TH.GAP
            else
                local rows = wrappedRows(text, style, drawW)
                y = y + lh * #rows
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
            elseif style == "image" then
                -- Inline animated image: width fills the drawable area,
                -- height computed from the declared aspect (h/w). Frame index
                -- advances via imgTick / fps, no per-image state needed.
                if y2 + scrollY > TH.PAD then y2 = y2 + TH.GAP end
                local imgW   = drawW - TH.PAD * 2
                local imgH   = math.floor(imgW * ((text and text.aspect) or 0.4325))
                local frames = (text and text.textures) or {}
                local n      = #frames
                if n > 0 then
                    local fps = (text and text.fps) or 8
                    local idx = (math.floor(imgTick / fps) % n) + 1
                    local tex = frames[idx]
                    if tex then
                        self2:drawTextureScaled(tex, x2, y2, imgW, imgH, 1)
                    end
                end
                y2 = y2 + imgH + TH.GAP
            else
                local s = ManualSave.Styles[style]
                if s then
                    local rows = wrappedRows(text, style, drawW)
                    if style == "header" then
                        if y2 + scrollY > TH.PAD then y2 = y2 + TH.GAP end
                        for _, row in ipairs(rows) do
                            self2:drawText(row, x2, y2, s.r, s.g, s.b, s.a, s.font)
                            y2 = y2 + lh
                        end
                        if s.rule then
                            self2:drawRect(x2, y2, drawW - TH.PAD * 2, 1, 0.3, s.r, s.g, s.b)
                            y2 = y2 + 1 + TH.GAP
                        end
                    elseif style == "check" then
                        local bc = s.bullet_color
                        -- Bullet only on the first wrapped row; continuation
                        -- rows align under the text (no double bullets).
                        self2:drawText(">", x2 + 6, y2, bc.r, bc.g, bc.b, 1, s.font)
                        for _, row in ipairs(rows) do
                            self2:drawText(row, x2 + s.indent, y2, s.r, s.g, s.b, s.a, s.font)
                            y2 = y2 + lh
                        end
                    elseif s.bar then
                        local b = s.bar
                        -- Left bar spans all wrapped rows of this paragraph.
                        self2:drawRect(x2 + 2, y2, 3, lh * #rows, 1, b.r, b.g, b.b)
                        for _, row in ipairs(rows) do
                            self2:drawText(row, x2 + s.indent, y2, s.r, s.g, s.b, s.a, s.font)
                            y2 = y2 + lh
                        end
                    else
                        for _, row in ipairs(rows) do
                            self2:drawText(row, x2 + s.indent, y2, s.r, s.g, s.b, s.a, s.font)
                            y2 = y2 + lh
                        end
                    end
                end
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
            imgTick      = (imgTick + 1) % 1000000
            local lines  = expandLines(opts.getLines())
            -- Two-pass: assume no scrollbar first to know the wrap width, then
            -- if it overflows, recompute with the narrower drawW (scrollbar
            -- visible). One iteration is enough because the scrollbar can only
            -- ever shrink the width, not grow it.
            local drawW  = w
            local totalH = computeH(lines, drawW)
            local needSB = totalH > h
            if needSB then
                drawW  = w - (SCROLL + 2)
                totalH = computeH(lines, drawW)
            end
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
            -- InputNav focus ring: drawn last so it sits on top of the content.
            -- Tells the user "arrow keys scroll this panel now".
            if self2.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
                for i = 0, TH.FOCUS_BW - 1 do
                    self2:drawRectBorder(i, i, self2.width - i*2, self2.height - i*2, 1,
                        TH.FOCUS_R, TH.FOCUS_G, TH.FOCUS_B)
                end
            end
        end,
        onMouseWheel = function(_, delta)
            local lines  = expandLines(opts.getLines())
            -- Assume scrollbar visible when measuring — if it isn't needed,
            -- totalH will simply be <= h either way. Using the narrower width
            -- here keeps wrap counts consistent with what prerender drew.
            local totalH = computeH(lines, w - SCROLL - 2)
            local maxScr = math.max(0, totalH - h)
            if maxScr == 0 then return false end
            local step = (ManualSave.Theme.FONT_HGT_SMALL + 3) * 3
            scrollY = math.max(0, math.min(maxScr, scrollY - delta * step))
            return true
        end,
        onMouseDown = function(_, mx, my)
            local lines  = expandLines(opts.getLines())
            local totalH = computeH(lines, w - SCROLL - 2)
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
            local lines  = expandLines(opts.getLines())
            local totalH = computeH(lines, w - SCROLL - 2)
            local maxScr = totalH - h
            if maxScr <= 0 then sbDrag = false; return end
            local thumbH = math.max(20, math.floor(h * h / totalH))
            local ratio  = maxScr / (h - thumbH)
            scrollY = math.max(0, math.min(maxScr,
                sbDragScr + (self2:getMouseY() - sbDragY) * ratio))
        end,
        onMouseUp = function() sbDrag = false end,
    })

    -- Keyboard scroll: when this panel is the focused widget in a FocusGroup,
    -- Up/Down scroll the text by one line (with key auto-repeat held down it
    -- becomes a smooth continuous scroll). Left/Right return false so the
    -- group can move focus to a sibling widget (left section nav etc.).
    panel.onArrow = function(_, direction)
        if direction ~= "up" and direction ~= "down" then return false end
        local lines  = expandLines(opts.getLines())
        local totalH = computeH(lines, w - SCROLL - 2)
        local maxScr = math.max(0, totalH - h)
        if maxScr == 0 then return false end
        local step = (ManualSave.Theme.FONT_HGT_SMALL + 3)
        if direction == "up" then
            scrollY = math.max(0, scrollY - step)
        else
            scrollY = math.min(maxScr, scrollY + step)
        end
        return true
    end

    -- Right-stick continuous scroll: see ScrollList for the contract.
    panel.onAnalogScroll = function(_, _, dy)
        if not dy or dy == 0 then return false end
        local lines  = expandLines(opts.getLines())
        local totalH = computeH(lines, w - SCROLL - 2)
        local maxScr = math.max(0, totalH - h)
        if maxScr == 0 then return false end
        scrollY = math.max(0, math.min(maxScr, scrollY + dy))
        return true
    end

    -- InputNav auto-register: scroll-text panels become a single navigable
    -- region. Up/Down on it scrolls the content; Left/Right hands off via the
    -- group exit chain. opts.focusGroup = false suppresses registration.
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then g:add(panel) end
    end

    local obj = { panel = panel }
    function obj.resetScroll() scrollY = 0 end
    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/StyledText.lua loaded.")
