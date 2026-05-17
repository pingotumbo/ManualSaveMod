-- UI/Base/Widgets/Sections/SettingsNav.lua
-- Left navigation panel for SettingsScreen.
-- Reads/writes ManualSave.SettingsScreen._section and ._sectionPanels.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { y, h, sections, navW? }
-- sections: array of { id, labelKey }
function ManualSave.makeSettingsNav(parent, opts)
    local TH       = ManualSave.Theme
    local navW     = opts.navW or 148
    local sections = opts.sections
    local ss       = ManualSave.SettingsScreen

    local p = ManualSave.makePanel(parent, {
        x=0, y=opts.y, w=navW, h=opts.h, border=false,
        bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 },
        prerender = function(np)
            np:drawRect(np.width - 1, 0, 1, np.height, 1,
                TH.LINE_R, TH.LINE_G, TH.LINE_B)
        end,
    })

    local NAV_ITEM_H = TH.FONT_HGT_SMALL + 18
    local iy = 8
    for _, sec in ipairs(sections) do
        local id  = sec.id
        local btn = ISButton:new(0, iy, navW - 1, NAV_ITEM_H, getText(sec.labelKey), p, function()
            if ss._section == id then return end
            ss._section = id
            for sid, sp in pairs(ss._sectionPanels) do
                sp:setVisible(sid == id)
            end
        end)
        btn:initialise()
        btn:instantiate()
        btn.backgroundColor          = { r=0, g=0, b=0, a=0 }
        btn.backgroundColorMouseOver = { r=0, g=0, b=0, a=0 }
        btn.borderColor              = { r=0, g=0, b=0, a=0 }
        btn.textColor                = { r=0, g=0, b=0, a=0 }
        local capturedId = id
        btn.render = function(self2)
            local TH2      = ManualSave.Theme
            local isActive = (ss._section == capturedId)
            local over     = false
            pcall(function() over = self2:isMouseOver() end)
            if isActive then
                self2:drawRect(0, 0, self2.width, self2.height, 0.12,
                    TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                self2:drawRect(0, 0, 3, self2.height, 1,
                    TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            elseif over then
                self2:drawRect(0, 0, self2.width, self2.height, 0.06, 1, 1, 1)
            end
            local fh  = TH2.FONT_HGT_SMALL
            local ty2 = math.floor((self2.height - fh) / 2)
            local tR  = isActive and TH2.TEXT_R  or TH2.MUTED_R
            local tG  = isActive and TH2.TEXT_G  or TH2.MUTED_G
            local tB  = isActive and TH2.TEXT_B  or TH2.MUTED_B
            self2:drawText(self2:getTitle(), 14, ty2, tR, tG, tB, 1, UIFont.Small)
        end
        p:addChild(btn)
        iy = iy + NAV_ITEM_H + 2
    end

    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsNav.lua loaded.")
