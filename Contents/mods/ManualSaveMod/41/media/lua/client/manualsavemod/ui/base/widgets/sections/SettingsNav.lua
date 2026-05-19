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
        local id = sec.id
        ManualSave.makeButton(p, {
            x=0, y=iy, w=navW - 1, h=NAV_ITEM_H,
            label = getText(sec.labelKey),
            style = "tab",
            activeIf = function() return ss._section == id end,
            onClick = function()
                if ss._section == id then return end
                ss._section = id
                for sid, sp in pairs(ss._sectionPanels) do
                    sp:setVisible(sid == id)
                end
            end,
        })
        iy = iy + NAV_ITEM_H + 2
    end

    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsNav.lua loaded.")
