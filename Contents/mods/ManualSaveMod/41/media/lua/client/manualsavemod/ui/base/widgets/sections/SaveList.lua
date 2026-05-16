-- UI/Base/Widgets/Sections/SaveList.lua
-- Self-contained save list: sort toolbar, search, scroll list.
-- All filter/sort/selection logic is internal.
-- Sets ManualSave.LoadScreen._list and _applyFilter.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, need-check-nil

ManualSave = ManualSave or {}

-- opts: { contentY, contentH, listW }
function ManualSave.makeSaveList(parent, opts)
    local TH       = ManualSave.Theme
    local contentY = opts.contentY
    local contentH = opts.contentH
    local listW    = opts.listW
    local toolY    = contentY + TH.PAD - 2

    -- ── Logic ─────────────────────────────────────────────────────────────────

    local function resolveModList(modsStr)
        if not modsStr or modsStr == "" then return {} end
        local parts = {}
        for entry in modsStr:gmatch("[^,]+") do
            local s = entry:match("^%s*(.-)%s*$")
            if s ~= "" then table.insert(parts, s) end
        end
        local iniNames = {}
        for _, p in ipairs(parts) do
            local n = p:match("^mod%s*=%s*(.-)%s*$")
            if n and n ~= "" then table.insert(iniNames, { name=n }) end
        end
        if #iniNames > 0 then return iniNames end
        local result = {}
        for _, p in ipairs(parts) do table.insert(result, { name=p }) end
        return result
    end

    local MONTHS = {
        -- English
        jan=1, feb=2, mar=3, apr=4, may=5, jun=6,
        jul=7, aug=8, sep=9, oct=10, nov=11, dec=12,
        -- Italian / locale variants
        gen=1, mag=5, giu=6, lug=7, ago=8, set=9, ott=10, dic=12,
        -- German / Dutch
        mai=5, okt=10, dez=12, mrt=3, mei=5,
        -- French
        fev=2, avr=4, aou=8,
        -- Spanish / Portuguese unique entries
        ene=1, abr=4,
    }
    local function parseDateNum(s)
        if not s or s == "" then return 0 end
        local d, mon, y, h, mn = s:match("(%d+)%s+(%a+)%s+(%d+)%s+(%d+):(%d+)")
        if not d then return 0 end
        local m = MONTHS[mon:lower():sub(1, 3)]
        if not m then return 0 end
        return tonumber(y)*100000000 + m*1000000 + tonumber(d)*10000
             + tonumber(h)*100 + tonumber(mn)
    end

    local function parseSizeNum(s)
        if not s or s == "" then return 0 end
        s = s:gsub(",", ".")  -- Italian / locale decimal separator -> dot
        local n, unit = s:match("([%d%.]+)%s*(%a+)")
        if not n then return 0 end
        local v = tonumber(n) or 0
        return unit:lower() == "gb" and v * 1024 or v
    end

    local function applyFilter()
        local st   = ManualSave.LoadScreen._state
        local list = ManualSave.LoadScreen._list
        if not st or not list then return end
        local text     = st.searchText:lower()
        local filtered = {}
        for _, b in ipairs(st.saves) do
            local match = text == ""
                or (b.slot  or ""):lower():find(text, 1, true)
                or (b.world or ""):lower():find(text, 1, true)
            if match then table.insert(filtered, b) end
        end
        if st.sortMode == "name" then
            table.sort(filtered, function(a, b2)
                local an, bn = (a.slot or ""):lower(), (b2.slot or ""):lower()
                if st.sortAsc then return an < bn else return an > bn end
            end)
        elseif st.sortMode == "size" then
            local sn = {}
            for _, b in ipairs(filtered) do sn[b] = parseSizeNum(b.SIZE) end
            table.sort(filtered, function(a, b2)
                if st.sortAsc then return sn[a] < sn[b2] else return sn[a] > sn[b2] end
            end)
        else
            local dn = {}
            for _, b in ipairs(filtered) do dn[b] = parseDateNum(b.DATE) end
            table.sort(filtered, function(a, b2)
                if st.sortAsc then return dn[a] < dn[b2] else return dn[a] > dn[b2] end
            end)
        end
        st.filtered = filtered
        list.setItems(filtered)
        if st.selected then
            for i, b in ipairs(filtered) do
                if b.slot == st.selected.slot and b.world == st.selected.world then
                    list.setSelected(i); break
                end
            end
        end
    end

    local function selectItem(item)
        local st = ManualSave.LoadScreen._state
        -- cancel any in-progress rename
        if st.renamingSlot then
            st.renamingSlot = false
            local entry = ManualSave.LoadScreen._renameEntry
            if entry then entry.setVisible(false) end
        end
        st.selected      = item
        st.fadealpha     = 0
        st.selectedThumb = nil
        pcall(function()
            local tex = getTextureFromSaveDir(item.slot .. ".png", "ManualSave_Thumbs")
                     or getTextureFromSaveDir("thumb.png", "MSM_THUMB_" .. item.slot)
            st.selectedThumb = tex
        end)
        st.selectedMods = resolveModList(item.MODS or "")
        local ls    = ManualSave.LoadScreen
        local batOk = ManualSave.SignalBus.isBatAlive() ~= false
        if ls._btnLoad  then ls._btnLoad.setEnabled(not item.CORRUPTED and batOk) end
        if ls._btnMore  then ls._btnMore.setEnabled(true) end
        if ls._actBtns  then
            ls._actBtns.rename.setEnabled(batOk)
            ls._actBtns.clone.setEnabled(batOk)
            ls._actBtns.delete.setEnabled(batOk)
        end
        if ManualSave.UI and ManualSave.UI.evalConditions then
            ManualSave.UI.evalConditions()
        end
    end

    local slotDisplay = ManualSave.slotDisplay

    local function truncatePx(font, text, maxW)
        if getTextManager():MeasureStringX(font, text) <= maxW then return text end
        local len = math.max(1, math.floor(#text * maxW / getTextManager():MeasureStringX(font, text)) - 2)
        local s = text:sub(1, len)
        while #s > 0 and getTextManager():MeasureStringX(font, s .. "...") > maxW do
            s = s:sub(1, #s - 1)
        end
        return s .. "..."
    end

    local function drawRow(panel, item, x, y, w, h, selected, _)
        local TH2 = ManualSave.Theme
        if selected then
            ManualSave.Draw.rowHighlight(panel, y, w, h, 32)
        end
        panel:drawRect(x, y + h - 1, w, 1, 1, TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
        local label = (item.gameMode or "")
        if (item.world or "") ~= "" then label = label .. "  |  " .. item.world end
        panel:drawText(label, x + 14, y + 8, TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B, 1, UIFont.Small)
        local dateStr = item.DATE or ""
        if dateStr ~= "" then
            local dw = getTextManager():MeasureStringX(UIFont.Small, dateStr)
            panel:drawText(dateStr, x + w - dw - 14, y + 8, TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 1, UIFont.Small)
        end
        local tag, style
        if item.SOURCE == "NATIVE" then
            tag, style = "NATIVE", "native"
        elseif item.TYPE == "QUICK" or (item.slot or ""):find("%[QUICK_SAVE%]") then
            tag, style = "QUICK", "accent"
        end
        local nameMaxW = w - 28 - (tag and (getTextManager():MeasureStringX(UIFont.Small, tag) + 24) or 0)
        panel:drawText(truncatePx(UIFont.Medium, slotDisplay(item.slot), nameMaxW),
            x + 14, y + 8 + TH2.FONT_HGT_SMALL + 2,
            TH2.TEXT_R, TH2.TEXT_G, TH2.TEXT_B, 1, UIFont.Medium)
        if tag then
            local bw = getTextManager():MeasureStringX(UIFont.Small, tag) + 10
            ManualSave.Draw.badge(panel, x + w - bw - 14, y + 8 + TH2.FONT_HGT_SMALL + 6, tag, style)
        end
    end

    -- ── UI ────────────────────────────────────────────────────────────────────

    -- Toolbar width: natural sum of per-button widths (text + arrow + padding).
    local toolbarW = TH.GAP * 2
    for _, lbl in ipairs({ getText("UI_MSM_List_SortDate"), getText("UI_MSM_List_SortName"), getText("UI_MSM_List_SortSize") }) do
        toolbarW = toolbarW + getTextManager():MeasureStringX(UIFont.Small, lbl) + 9 + 16
    end
    ManualSave.makeToolbar(parent, {
        x=TH.PAD, y=toolY, w=toolbarW, h=TH.BUTTON_HGT,
        items = {
            { id="date", label=getText("UI_MSM_List_SortDate"), kind="toggle", group="sort", active=true,
              arrowFn = function()
                  local st = ManualSave.LoadScreen._state
                  return st and st.sortMode == "date" and (st.sortAsc and "up" or "down") or nil
              end },
            { id="name", label=getText("UI_MSM_List_SortName"), kind="toggle", group="sort", active=false,
              arrowFn = function()
                  local st = ManualSave.LoadScreen._state
                  return st and st.sortMode == "name" and (st.sortAsc and "up" or "down") or nil
              end },
            { id="size", label=getText("UI_MSM_List_SortSize"), kind="toggle", group="sort", active=false,
              arrowFn = function()
                  local st = ManualSave.LoadScreen._state
                  return st and st.sortMode == "size" and (st.sortAsc and "up" or "down") or nil
              end },
        },
        onToggle = function(id, _)
            local st = ManualSave.LoadScreen._state
            if not st then return end
            if st.sortMode == id then st.sortAsc = not st.sortAsc
            else st.sortMode = id; st.sortAsc = (id ~= "size") end
            applyFilter()
        end,
    })

    ManualSave.makeTextInput(parent, {
        x=TH.PAD + toolbarW + TH.GAP, y=toolY,
        w=listW - TH.PAD * 2 - toolbarW - TH.GAP, h=TH.BUTTON_HGT,
        icon="search", placeholder=getText("UI_MSM_List_SearchPlaceholder"),
        onChange = function(text)
            local st = ManualSave.LoadScreen._state
            if st then st.searchText = text; applyFilter() end
        end,
    })

    local listY = toolY + TH.BUTTON_HGT + TH.GAP + 4
    ManualSave.LoadScreen._list = ManualSave.makeScrollList(parent, {
        x=TH.PAD, y=listY, w=listW - TH.PAD * 2, h=contentH - (listY - contentY),
        rowH=TH.ITEM_HGT, items={},
        bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B },
        drawRow    = drawRow,
        onSelect   = function(item) selectItem(item) end,
        onActivate = function(item)
            selectItem(item)
            local st = ManualSave.LoadScreen._state
            if not st or not st.selected or st.selected.CORRUPTED then return end
            if ManualSave.SignalBus.isBatAlive() == false then return end
            ManualSave.LoadScreen.confirmLoad(st.selected)
        end,
    })
    ManualSave.LoadScreen.applyFilter  = applyFilter
    ManualSave.LoadScreen._applyFilter = applyFilter

    ManualSave.makePanel(parent, {
        x=listW, y=contentY, w=1, h=contentH,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 }, border=false,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SaveList.lua loaded.")
