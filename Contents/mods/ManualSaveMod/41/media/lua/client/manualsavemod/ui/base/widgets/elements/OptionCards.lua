-- UI/Base/Widgets/Elements/OptionCards.lua
-- Horizontal row of selectable cards, each with an optional image preview and a title bar.
-- Selection state is read live via getValue() so the display stays in sync.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

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

    for i, cd in ipairs(cards) do
        local cardX = (i - 1) * (cardW + gap)
        local val   = cd.value
        local tex   = cd.tex
        ManualSave.makePanel(parent, {
            x=(opts.x or 0) + cardX, y=opts.y, w=cardW, h=cardH,
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
                if opts.onChange then opts.onChange(val) end
                return true
            end,
        })
    end

    return cardH
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/OptionCards.lua loaded.")
