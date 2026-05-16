-- UI/Base/Sections/HelpNav.lua
-- Left nav panel for HelpScreen.
-- makeWatcherStatusDot lives in elements/Panel.lua.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, undefined-field

ManualSave = ManualSave or {}

-- Creates the scrollable left nav panel for HelpScreen.
--
-- opts:
--   y           number    top y (d.titleH)
--   w           number    nav column width
--   h           number    nav column height
--   rowH        number?   row height (default TH.FONT_HGT_SMALL+9)
--   categories  table     CATEGORIES table: { id, label, pages={id,label,...} }
--   getSection  fun():str returns the currently active section id
--   onNavigate  fun(id)   called when the user picks a page
--
-- Returns { scrollTo:fun(sectionId) }
--
function ManualSave.makeHelpNav(parent, opts)
    local TH   = ManualSave.Theme
    local rowH = opts.rowH or (TH.FONT_HGT_SMALL + 9)

    local navItems = {}
    for _, cat in ipairs(opts.categories) do
        table.insert(navItems, { _cat=true, label=cat.label })
        for _, page in ipairs(cat.pages) do
            table.insert(navItems, { _cat=false, id=page.id, label=page.label })
        end
    end

    local initIdx = 1
    for i, it in ipairs(navItems) do
        if not it._cat and it.id == opts.getSection() then initIdx = i; break end
    end

    local navList = ManualSave.makeScrollList(parent, {
        x=0, y=opts.y, w=opts.w, h=opts.h,
        rowH=rowH, items=navItems,
        bg = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B },
        drawRow = function(panel, item, x, y, w, h)
            if item._cat then
                panel:drawRect(x, y, w, h, 1, TH.BG_R*0.65, TH.BG_G*0.65, TH.BG_B*0.65)
                panel:drawText(item.label:upper(), x+8, y+math.floor((h-TH.FONT_HGT_SMALL)/2),
                    TH.DIM_R, TH.DIM_G, TH.DIM_B, 0.85, UIFont.Small)
                panel:drawRect(x, y+h-1, w, 1, 1, TH.LINE_R*0.5, TH.LINE_G*0.5, TH.LINE_B*0.5)
            else
                local isSel = (item.id == opts.getSection())
                if isSel then ManualSave.Draw.rowHighlight(panel, y, w, h, 16, 0.22) end
                panel:drawText(item.label, x+18, y+math.floor((h-TH.FONT_HGT_SMALL)/2),
                    isSel and TH.TEXT_R or TH.MUTED_R,
                    isSel and TH.TEXT_G or TH.MUTED_G,
                    isSel and TH.TEXT_B or TH.MUTED_B, 1, UIFont.Small)
                panel:drawRect(x, y+h-1, w, 1, 1, TH.LINE_R, TH.LINE_G, TH.LINE_B)
            end
        end,
        onSelect   = function(item)
            if item._cat then return end
            opts.onNavigate(item.id)
        end,
        onActivate = function(item)
            if item._cat then return end
            opts.onNavigate(item.id)
        end,
    })
    navList.scrollToIndex(initIdx)

    local idxMap = {}
    for i, it in ipairs(navItems) do
        if not it._cat then idxMap[it.id] = i end
    end

    ManualSave.makePanel(parent, {
        x=opts.w, y=opts.y, w=1, h=opts.h,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 }, border=false,
    })

    return {
        scrollTo = function(sid)
            local idx = idxMap[sid]
            if idx then navList.scrollToIndex(idx) end
        end,
    }
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/HelpNav.lua loaded.")
