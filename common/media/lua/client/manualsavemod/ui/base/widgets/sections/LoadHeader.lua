-- UI/Base/Widgets/Sections/LoadHeader.lua
-- Title bar for LoadScreen: accent bar, "MANUAL SAVES" title, dynamic save-count
-- subtitle, and the Help button. Reads ManualSave.LoadScreen._state each frame.
---@diagnostic disable: undefined-global, undefined-doc-name

ManualSave = ManualSave or {}

-- Creates the LoadScreen title bar (background + text + help button).
-- opts: { w, h }
function ManualSave.makeLoadHeader(parent, opts)
    local TH = ManualSave.Theme
    local w  = opts.w
    local h  = opts.h

    local hp = ManualSave.makeHeaderPanel(parent, {
        x=0, y=0, w=w, h=h,
        bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 },
        bottomBorder = true,
    })

    local ty  = math.floor((h - TH.FONT_HGT_LARGE) / 2)
    local ty2 = math.floor((h - TH.FONT_HGT_SMALL) / 2) + 1
    local tx2 = TH.PAD + getTextManager():MeasureStringX(UIFont.Large, "MANUAL SAVES") + 14

    ManualSave.makeLabel(hp, {
        x=TH.PAD, y=ty, w=w - TH.PAD, h=TH.FONT_HGT_LARGE,
        text="MANUAL SAVES", font=UIFont.Large,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B,
    })

    ManualSave.makeLabel(hp, {
        x=tx2, y=ty2, w=w - tx2, h=TH.FONT_HGT_SMALL,
        getText = function()
            local st = ManualSave.LoadScreen._state
            if not st then return "" end
            local totalMB = 0
            for _, m in ipairs(st.saves) do
                local n = m.SIZE and m.SIZE:match("^([%d%.]+)")
                if n then totalMB = totalMB + tonumber(n) end
            end
            local sub = tostring(#st.saves) .. " saves"
            if totalMB > 0 then
                local sizeStr = totalMB >= 1024
                    and string.format("%.1f GB", totalMB / 1024)
                    or  string.format("%.0f MB", totalMB)
                sub = sub .. "  \194\183  " .. sizeStr
            end
            return sub
        end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B,
    })

    local helpBtnW = 52
    ManualSave.makeButton(parent, {
        x=w - TH.PAD - helpBtnW, y=math.floor((h - TH.BUTTON_HGT) / 2),
        w=helpBtnW, h=TH.BUTTON_HGT,
        label="Help", style="normal",
        onClick = function() ManualSave.openHelpScreen() end,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/LoadHeader.lua loaded.")
