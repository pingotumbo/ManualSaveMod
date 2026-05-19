-- UI/Base/Widgets/Elements/OptionCards.lua
-- Horizontal row of selectable cards, each with an optional image preview and a title bar.
-- Selection state is read live via getValue() so the display stays in sync.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

-- opts: {
--   x?, y, w
--   cards               array  { value, titleKey, tex? }
--   getValue            fun()  returns the currently selected value
--   onChange            fun(value)  called when a card is clicked
--   previewH?           number  height of the image area (default 64)
--   titleBarH?          number  height of the title bar below the image (default 26)
-- }
function ManualSave.makeOptionCards(parent, opts)
    local TH       = ManualSave.Theme
    local cards    = opts.cards or {}
    local prevH    = opts.previewH  or 64
    local titleH   = opts.titleBarH or 26
    local cardH    = prevH + titleH
    local n        = #cards
    local gap      = n > 1 and TH.GAP or 0
    local cardW    = n > 0 and math.floor((opts.w - gap * (n - 1)) / n) or opts.w

    -- Cursor used by keyboard navigation: index of the card currently being
    -- "considered" via arrow keys (separate from the selected value).
    -- Defaults to the index of the currently selected card so the cursor lines
    -- up with the user's current choice when the row first gains focus.
    local function indexOfSelected()
        if not opts.getValue then return 1 end
        local cur = opts.getValue()
        for i, cd in ipairs(cards) do
            if cd.value == cur then return i end
        end
        return 1
    end
    local focusIdx = indexOfSelected()

    -- Invisible row container that owns the keyboard focus. Registered into the
    -- parent's nav group; child card panels are positioned inside it. This lets
    -- the entire row receive a single focus indicator that surrounds the cursor
    -- card, while keeping the individual card panels independent for mouse hit.
    local row = ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y, w=opts.w, h=cardH,
        bg={r=0,g=0,b=0,a=0}, border=false,
    })

    -- Focus ring drawn in render (after children) so the cards don't cover it.
    -- prerender fires BEFORE child render, so a ring drawn there would be hidden
    -- by each card's own prerender filling its entire area.
    local origRender = row.render
    row.render = function(pv)
        if origRender then origRender(pv) else ISPanel.render(pv) end
        if not pv.isFocused or not (ManualSave.InputNav and ManualSave.InputNav.keyboardActive) then
            return
        end
        local idx = math.max(1, math.min(n, focusIdx))
        local cx  = (idx - 1) * (cardW + gap)
        local TH2 = ManualSave.Theme
        for i = 0, TH2.FOCUS_BW - 1 do
            pv:drawRectBorder(cx + i, i, cardW - i*2, cardH - i*2, 1,
                TH2.FOCUS_R, TH2.FOCUS_G, TH2.FOCUS_B)
        end
    end

    for i, cd in ipairs(cards) do
        local cardX = (i - 1) * (cardW + gap)
        local val   = cd.value
        local tex   = cd.tex
        ManualSave.makePanel(row, {
            x=cardX, y=0, w=cardW, h=cardH,
            bg={r=0,g=0,b=0,a=0}, border=false,
            prerender = function(pv)
                local TH2  = ManualSave.Theme
                local isOn = opts.getValue and opts.getValue() == val
                local over = false
                pcall(function() over = pv:isMouseOver() end)

                -- image area
                pv:drawRect(0, 0, pv.width, prevH, 1, 0.06, 0.05, 0.04)
                if tex then
                    pv:drawTextureScaled(tex, 0, 0, pv.width, prevH, 1)
                end

                -- title bar
                pv:drawRect(0, prevH, pv.width, titleH, 1,
                    TH2.PANEL_R, TH2.PANEL_G, TH2.PANEL_B)
                local tR = isOn and TH2.ACCENT_R or TH2.TEXT_R
                local tG = isOn and TH2.ACCENT_G or TH2.TEXT_G
                local tB = isOn and TH2.ACCENT_B or TH2.TEXT_B
                local fy = prevH + math.floor((titleH - TH2.FONT_HGT_SMALL) / 2)
                pv:drawText(getText(cd.titleKey), 8, fy, tR, tG, tB, 1, UIFont.Small)

                -- accent line at top of title bar when selected
                if isOn then
                    pv:drawRect(0, prevH, pv.width, 2, 1,
                        TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                end

                -- border
                local bA = isOn and 0.95 or (over and 0.45 or 0.35)
                local bR = isOn and TH2.ACCENT_R or TH2.LINE_R * (over and 2 or 1)
                local bG = isOn and TH2.ACCENT_G or TH2.LINE_G * (over and 2 or 1)
                local bB = isOn and TH2.ACCENT_B or TH2.LINE_B * (over and 2 or 1)
                pv:drawRectBorder(0, 0, pv.width, pv.height, bA, bR, bG, bB)
            end,
            onMouseDown = function()
                focusIdx = i
                if opts.onChange then opts.onChange(val) end
                return true
            end,
        })
    end

    -- Keyboard navigation: Left/Right move the cursor between cards while
    -- there is still room. When the cursor is already at the edge and the
    -- user presses Left/Right outward, we return false so the surrounding
    -- FocusGroup can resolve the input (cross-group exit to the next column,
    -- for instance). Without this the row would trap the focus forever.
    -- Up/Down always fall through so vertical nav still escapes upward.
    row.onArrow = function(_, direction)
        if direction == "left" then
            if focusIdx <= 1 then return false end
            focusIdx = focusIdx - 1
            return true
        elseif direction == "right" then
            if focusIdx >= n then return false end
            focusIdx = focusIdx + 1
            return true
        end
        return false
    end
    row.onActivate = function()
        local cd = cards[focusIdx]
        if cd and opts.onChange then opts.onChange(cd.value) end
    end

    -- Auto-register the row in the parent's nav group via walk-up.
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then g:add(row) end
    end

    return cardH
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/OptionCards.lua loaded.")
