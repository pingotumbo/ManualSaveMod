-- UI/Base/Widgets/Sections/ModSearchControls.lua
-- Search bar + sort button + category dropdown + quick-action buttons for EditModsScreen.
-- Also defines ManualSave.EditModsScreen.applySort() and .refreshList().
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave              = ManualSave or {}
ManualSave.EditModsScreen = ManualSave.EditModsScreen or {}

function ManualSave.EditModsScreen.applySort()
    local st = ManualSave.EditModsScreen._state
    if not st then return end
    local sk = ManualSave.EditMods.sortKey
    local sortMode = st.sortMode
    if sortMode == "name_asc" then
        table.sort(st.allMods, function(a, b) return sk(a.name) < sk(b.name) end)
    elseif sortMode == "name_desc" then
        table.sort(st.allMods, function(a, b) return sk(a.name) > sk(b.name) end)
    else
        table.sort(st.allMods, function(a, b)
            if a.status ~= b.status then return a.status == "ok" end
            if a.inSave  ~= b.inSave  then return a.inSave  end
            return sk(a.name) < sk(b.name)
        end)
    end
end

function ManualSave.EditModsScreen.refreshList()
    local st = ManualSave.EditModsScreen._state
    if not st then return end
    local term = st.lastSearch
    st.filteredMods = {}
    for _, m in ipairs(st.allMods) do
        local matchS = term == "" or m.name:lower():find(term, 1, true)
        local matchT = st.activeTag == "all"
        if not matchT then
            for _, t in ipairs(m.tags or {}) do
                if t == st.activeTag then matchT = true; break end
            end
        end
        if matchS and matchT then table.insert(st.filteredMods, m) end
    end
    local sl = ManualSave.EditModsScreen._scrollList
    if sl then sl.setItems(st.filteredMods, true) end
    local cb = ManualSave.EditModsScreen._createBtn
    if cb then
        local dirty = false
        for _, m in ipairs(st.allMods) do
            if m.checked ~= m.inSave then dirty = true; break end
        end
        cb.setEnabled(dirty)
    end
    local sb = ManualSave.EditModsScreen._sortBtn
    if sb then
        local lbl = st.sortMode == "name_asc"  and getText("UI_MSM_EditMods_SortName")
                 or st.sortMode == "name_desc" and getText("UI_MSM_EditMods_SortNameDesc")
                 or getText("UI_MSM_EditMods_SortDefault")
        sb.setLabel(lbl)
    end
end

-- opts: { W, PAD, GAP, BUTH, searchY, ctrlY }
function ManualSave.makeModSearchControls(parent, opts)
    local TH      = ManualSave.Theme
    local W       = opts.W
    local PAD     = opts.PAD
    local GAP     = opts.GAP
    local BUTH    = opts.BUTH
    local searchY = opts.searchY
    local ctrlY   = opts.ctrlY

    ManualSave.makeTextInput(parent, {
        x = PAD, y = searchY, w = W - PAD * 2, h = BUTH,
        icon = "search",
        placeholder = getText("UI_MSM_EditMods_Search"),
        value = "",
        onChange = function(text)
            local st = ManualSave.EditModsScreen._state
            if st then st.lastSearch = text:lower() end
            ManualSave.EditModsScreen.refreshList()
        end,
    })

    local sortLbl0 = getText("UI_MSM_EditMods_SortDefault")
    local sortLbl1 = getText("UI_MSM_EditMods_SortName")
    local sortLbl2 = getText("UI_MSM_EditMods_SortNameDesc")
    local sortW    = math.max(
        getTextManager():MeasureStringX(UIFont.Small, sortLbl0),
        getTextManager():MeasureStringX(UIFont.Small, sortLbl1),
        getTextManager():MeasureStringX(UIFont.Small, sortLbl2)) + 16

    ManualSave.EditModsScreen._sortBtn = ManualSave.makeButton(parent, {
        x = PAD, y = ctrlY, w = sortW, h = BUTH,
        label = sortLbl0, style = "normal",
        onClick = function()
            local st = ManualSave.EditModsScreen._state
            if not st then return end
            if st.sortMode == "default" then st.sortMode = "name_asc"
            elseif st.sortMode == "name_asc" then st.sortMode = "name_desc"
            else st.sortMode = "default" end
            ManualSave.EditModsScreen.applySort()
            ManualSave.EditModsScreen.refreshList()
        end,
    })

    local st      = ManualSave.EditModsScreen._state
    local allTags = st and st.allTags or {}
    local dropW   = 200
    local dropX   = PAD + sortW + GAP
    local dropItems = { { id="all", label=getText("UI_MSM_EditMods_TagAll") } }
    for _, t in ipairs(allTags) do table.insert(dropItems, { id=t, label=t }) end
    ManualSave.makeDropdown(parent, {
        x = dropX, y = ctrlY, w = dropW, h = BUTH,
        items = dropItems,
        value = "all",
        onChange = function(id, _)
            local st2 = ManualSave.EditModsScreen._state
            if st2 then st2.activeTag = id end
            ManualSave.EditModsScreen.refreshList()
        end,
    })

    -- Compute dimensions for both buttons up-front so the visually-left button
    -- (Escludi mancanti / QuickSelectBad) can be created FIRST. Creating in
    -- visual left-to-right order matches the focus group iteration, so D-pad
    -- right/left moves in the expected direction. Previously "Reimposta" was
    -- created first and the nav order felt mirrored.
    local hasMissing = false
    if st then
        for _, m in ipairs(st.allMods) do if m.status == "missing" then hasMissing = true; break end end
    end

    local qb2Lbl = getText("UI_MSM_EditMods_QuickDeselect")
    local qb2W   = getTextManager():MeasureStringX(UIFont.Small, qb2Lbl) + 16

    if hasMissing then
        local qb1Lbl = getText("UI_MSM_EditMods_QuickSelectBad")
        local qb1W   = getTextManager():MeasureStringX(UIFont.Small, qb1Lbl) + 16
        ManualSave.makeButton(parent, {
            x = W - PAD - qb2W - GAP - qb1W, y = ctrlY, w = qb1W, h = BUTH,
            label = qb1Lbl, style = "normal",
            onClick = function()
                local st2 = ManualSave.EditModsScreen._state
                if not st2 then return end
                for _, m in ipairs(st2.allMods) do
                    if m.status == "missing" then m.checked = false end
                end
                ManualSave.EditModsScreen.refreshList()
            end,
        })
    end

    ManualSave.makeButton(parent, {
        x = W - PAD - qb2W, y = ctrlY, w = qb2W, h = BUTH,
        label = qb2Lbl, style = "normal",
        onClick = function()
            local st2 = ManualSave.EditModsScreen._state
            if not st2 then return end
            for _, m in ipairs(st2.allMods) do m.checked = m.inSave end
            ManualSave.EditModsScreen.refreshList()
        end,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/ModSearchControls.lua loaded.")
