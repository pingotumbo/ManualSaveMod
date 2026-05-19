-- UI/Base/Widgets/Sections/SettingsNav.lua
-- Left navigation panel for SettingsScreen.
-- Reads/writes ManualSave.SettingsScreen._section and ._sectionPanels.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { y, h, sections, navW?, focusGroup?, onSectionChange? }
-- sections: array of { id, labelKey }
-- focusGroup: if set, the underlying scroll list is registered into this group
--             explicitly (a single focusable element on the left column).
-- onSectionChange: optional callback fired after a section switch.
--
-- Mirrors HelpScreen's left nav pattern: one scroll list whose Up/Down moves
-- the section cursor internally, and whose Enter/A "activates" the section.
-- Left/Right do nothing inside the list, so they bubble up to the FocusManager
-- which hands focus to the linked content group on the right.
function ManualSave.makeSettingsNav(parent, opts)
    local TH       = ManualSave.Theme
    local navW     = opts.navW or 148
    local sections = opts.sections
    local ss       = ManualSave.SettingsScreen
    local rowH     = TH.FONT_HGT_SMALL + 18

    local function applySection(id)
        if ss._section == id then return end
        ss._section = id
        for sid, sp in pairs(ss._sectionPanels) do
            sp:setVisible(sid == id)
        end
        if opts.onSectionChange then opts.onSectionChange(id) end
    end

    local items = {}
    for _, sec in ipairs(sections) do
        table.insert(items, { id=sec.id, label=getText(sec.labelKey) })
    end

    local navList = ManualSave.makeScrollList(parent, {
        x=0, y=opts.y, w=navW, h=opts.h,
        rowH=rowH, items=items,
        bg = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B },
        drawRow = function(panel, item, x, y, w, h, isCursor, _)
            local isSel = (item.id == ss._section)
            if isSel then
                ManualSave.Draw.rowHighlight(panel, y, w, h, 16, 0.22)
            end
            -- Keyboard / gamepad cursor highlight on the focused row (matches
            -- the live internal cursor of the scroll list, not the active
            -- section). Drawn only when nav mode is active so mouse users
            -- don't see a permanent highlight.
            if isCursor and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
                panel:drawRect(x, y, w, h,
                    TH.FOCUS_BG_A, TH.FOCUS_BG_R, TH.FOCUS_BG_G, TH.FOCUS_BG_B)
            end
            panel:drawText(item.label, x + 18, y + math.floor((h - TH.FONT_HGT_SMALL) / 2),
                isSel and TH.TEXT_R or TH.MUTED_R,
                isSel and TH.TEXT_G or TH.MUTED_G,
                isSel and TH.TEXT_B or TH.MUTED_B,
                1, UIFont.Small)
            panel:drawRect(x, y + h - 1, w, 1, 1, TH.LINE_R, TH.LINE_G, TH.LINE_B)
        end,
        onSelect   = function(item) applySection(item.id) end,
        onNavigate = function(item) applySection(item.id) end,
        onActivate = function(item) applySection(item.id) end,
        focusGroup = opts.focusGroup,
    })

    -- Pre-position the list cursor on the currently active section so the
    -- first Down press moves to the next section (not "starts" from 0). This
    -- avoids the wasted-first-keypress feel you'd get with the default
    -- `selected = 0` and matches how a freshly opened native scroll list
    -- behaves when something is already chosen.
    for i, it in ipairs(items) do
        if it.id == ss._section then
            if navList.setSelected then navList.setSelected(i) end
            break
        end
    end

    -- Right-side divider line (visual continuity with the original tab nav).
    ManualSave.makePanel(parent, {
        x=navW, y=opts.y, w=1, h=opts.h,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 }, border=false,
    })

    return navList
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsNav.lua loaded.")
