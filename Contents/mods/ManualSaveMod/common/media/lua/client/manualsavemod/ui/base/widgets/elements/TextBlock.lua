-- UI/Base/Elements/TextBlock.lua
-- Static styled text block with optional word-wrap and per-axis dynamic sizing.
-- Same line-style system as makeScrollText (header/sub/body/dim/warn/good/
-- callout/callout_w/callout_g/check/gloss_t/gloss_d / "" gap).
--
-- For scrollable content use makeScrollText; use this for panels that must
-- grow/shrink to fit their content.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, undefined-field, need-check-nil

ManualSave = ManualSave or {}

-- Creates a styled text block and adds it to parent.
--
-- opts:
--   x, y        number
--   w           number    pixel width; upper bound when dynamicW=true
--   h           number?   initial height (default 20); ignored when dynamicH=true
--   lines       {string, string?}[]          static line list
--   getLines    fun(): {string, string?}[]   called each frame (takes priority)
--   dynamicW    boolean?  resize to widest line, up to w   (default false)
--   dynamicH    boolean?  resize to total content height   (default true)
--   wordWrap    boolean?  wrap long body/dim/warn/good/callout/check lines
--                         (default true)
--   bg          {r,g,b,a}?  default transparent (a=0)
--   border      false|{r,g,b,a}?  default no border
--
-- Returns: { panel:ISPanel, getSize:fun():{w:number,h:number} }
--   getSize() returns the current pixel dimensions (updated after each render).
function ManualSave.makeTextBlock(parent, opts)
    local TH = ManualSave.Theme

    local maxW   = opts.w
    local dynW   = opts.dynamicW == true
    local dynH   = opts.dynamicH ~= false   -- default true
    local doWrap = opts.wordWrap ~= false    -- default true

    local curW = maxW
    local curH = opts.h or 20

    -- Wrap a single string to fit within pixelW.
    local function wrapLine(font, text, pixelW)
        if getTextManager():MeasureStringX(font, text) <= pixelW then
            return { text }
        end
        local result, line = {}, ""
        for word in (text .. " "):gmatch("([^ ]*) ") do
            local candidate = line == "" and word or (line .. " " .. word)
            if getTextManager():MeasureStringX(font, candidate) <= pixelW then
                line = candidate
            else
                if line ~= "" then table.insert(result, line) end
                line = word
            end
        end
        if line ~= "" then table.insert(result, line) end
        return #result > 0 and result or { text }
    end

    -- Expand raw lines: split on \n, then word-wrap using the style's indent.
    local function expandLines(rawLines, availW)
        local out = {}
        for _, ln in ipairs(rawLines) do
            local text, style = ln[1], ln[2]
            local segments = {}
            for seg in (text .. "\n"):gmatch("([^\n]*)\n") do
                table.insert(segments, seg)
            end
            for _, seg in ipairs(segments) do
                local wrapped
                local s = style and ManualSave.Styles[style]
                if doWrap and s then
                    local font  = s.font or UIFont.Small
                    local indW  = availW - (s.indent or 0)
                    wrapped = wrapLine(font, seg, indW)
                else
                    wrapped = { seg }
                end
                for _, wl in ipairs(wrapped) do
                    table.insert(out, { wl, style })
                end
            end
        end
        return out
    end

    -- Total pixel height for a set of expanded lines.
    local function measureH(expanded)
        local lh   = TH.FONT_HGT_SMALL + 3
        local gapH = math.floor(TH.FONT_HGT_SMALL * 0.55)
        local y    = TH.PAD
        for _, ln in ipairs(expanded) do
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

    -- Pixel width of the widest rendered line (lookup style for indent).
    local function measureW(expanded)
        local widest = 0
        for _, ln in ipairs(expanded) do
            local style = ln[2]
            if style and style ~= "" then
                local s = ManualSave.Styles[style]
                if s then
                    local tw = getTextManager():MeasureStringX(s.font, ln[1])
                    widest = math.max(widest, tw + s.indent + TH.PAD * 2)
                end
            end
        end
        return math.max(widest, 40)
    end

    local panel = ManualSave.makePanel(parent, {
        x = opts.x or 0, y = opts.y or 0,
        w = curW, h = curH,
        bg     = opts.bg     or { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=0 },
        border = opts.border == nil and false or opts.border,
        prerender = function(self2)
            ISPanel.prerender(self2)
            local rawLines = opts.getLines and opts.getLines()
                          or opts.lines or {}
            local drawW    = dynW and maxW or self2:getWidth()
            local expanded = expandLines(rawLines, drawW - TH.PAD * 2)

            if dynH then
                local needH = measureH(expanded)
                if needH ~= self2:getHeight() then
                    self2:setHeight(needH)
                    curH = needH
                end
            end
            if dynW then
                local needW = math.min(measureW(expanded), maxW)
                if needW ~= self2:getWidth() then
                    self2:setWidth(needW)
                    curW = needW
                end
            end

            local lh   = TH.FONT_HGT_SMALL + 3
            local gapH = math.floor(TH.FONT_HGT_SMALL * 0.55)
            local x2   = TH.PAD
            local y2   = TH.PAD
            local rw   = self2:getWidth()

            for _, ln in ipairs(expanded) do
                local text, style = ln[1], ln[2]
                if not style or style == "" then
                    y2 = y2 + gapH
                else
                    local s = ManualSave.Styles[style]
                    if s then
                        if style == "header" then
                            if y2 > TH.PAD then y2 = y2 + TH.GAP end
                            self2:drawText(text, x2, y2, s.r, s.g, s.b, s.a, s.font)
                            y2 = y2 + lh
                            if s.rule then
                                self2:drawRect(x2, y2, rw - TH.PAD * 2, 1, 0.3, s.r, s.g, s.b)
                                y2 = y2 + 1 + TH.GAP
                            end
                        elseif style == "check" then
                            local bc = s.bullet_color
                            self2:drawText(">", x2 + 6, y2, bc.r, bc.g, bc.b, 1, s.font)
                            self2:drawText(text, x2 + s.indent, y2, s.r, s.g, s.b, s.a, s.font)
                            y2 = y2 + lh
                        elseif s.bar then
                            local b = s.bar
                            self2:drawRect(x2 + 2, y2, 3, lh, 1, b.r, b.g, b.b)
                            self2:drawText(text, x2 + s.indent, y2, s.r, s.g, s.b, s.a, s.font)
                            y2 = y2 + lh
                        else
                            self2:drawText(text, x2 + s.indent, y2, s.r, s.g, s.b, s.a, s.font)
                            y2 = y2 + lh
                        end
                    end
                end
            end
        end,
    })

    return {
        panel   = panel,
        getSize = function() return { w = curW, h = curH } end,
    }
end

print("[ManualSaveMod] UI/Base/Elements/TextBlock.lua loaded.")
