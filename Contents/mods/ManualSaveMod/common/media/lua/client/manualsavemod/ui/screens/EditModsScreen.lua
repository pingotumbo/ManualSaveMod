-- UI/Screens/EditModsScreen.lua
-- Floating panel: browse and edit the mod list for a cloned save.
-- Shows all installed mods; save mods start checked. Clone disabled when unchanged.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, unused-local, undefined-field

ManualSave = ManualSave or {}

-- Returns the first alphabetical character (A-Z) from str, or "?" if none found.
local function firstAlpha(str)
    for i = 1, #str do
        local c = str:sub(i, i)
        if c:match("[%a]") then return c:upper() end
    end
    return "?"
end

-- Sort key: strips all leading [tag] groups so "[B42] Home Inventory" sorts as "home inventory".
local function sortKey(name)
    local s = name:lower()
    local prev
    repeat
        prev = s
        s = s:match("^%s*%[.-%]%s*(.*)") or s
    until s == prev
    return s ~= "" and s or name:lower()
end

-- Opens the Edit Mods floating panel for a given save slot.
--
-- opts:
--   save        table   MetaCache record (.slot, .GMODE/.gameMode, .WORLD/.world, .MODS)
--   onCreated   fun(newSlot:string, keptMods:string)?
--
function ManualSave.openEditModsScreen(opts)
    local TH   = ManualSave.Theme
    local save = opts.save

    local W    = 720
    local H    = 600
    local PAD  = TH.PAD
    local GAP  = TH.GAP
    local FHS  = TH.FONT_HGT_SMALL
    local BUTH = TH.BUTTON_HGT

    -- ── Step 1: Enumerate all installed mods ──────────────────────────────────
    local installedData   = {}  -- id -> { name, icon, tags }
    local displayToRealId = {}  -- display name -> id (for old saves with display names in MODS)

    pcall(function()
        local active = getActivatedMods()
        for i = 0, active:size() - 1 do
            local id   = active:get(i)
            local info = getModInfoByID(id)
            local name = info and info:getName() or id
            local icon = nil
            local tags = {}
            if info then
                local iconKey = info:getIcon()
                if iconKey and iconKey ~= "" then icon = getTexture(iconKey) end
                pcall(function()
                    local reader = getModFileReader(id, "mod.info", false)
                    if reader then
                        while true do
                            local line = reader:readLine()
                            if line == nil then break end
                            local tagStr = line:match("^tags=(.*)$")
                            if tagStr then
                                for tag in (tagStr .. ","):gmatch("([^,]+),") do
                                    local t = tag:match("^%s*(.-)%s*$")
                                    if t ~= "" and not t:match("^Build %d") then
                                        table.insert(tags, t)
                                    end
                                end
                                break
                            end
                        end
                        reader:close()
                    end
                end)
            end
            installedData[id]     = { name = name, icon = icon, tags = tags }
            displayToRealId[name] = id
        end
    end)

    -- ── Step 2: Build saveModIds from MetaCache ────────────────────────────────
    local saveModIds = {}
    local saveIdSet  = {}
    local hasMOD_IDS = save.MOD_IDS and save.MOD_IDS ~= ""
    local idSource   = hasMOD_IDS and save.MOD_IDS
                    or (save.MODS and save.MODS ~= "") and save.MODS
                    or ""
    for raw in (idSource .. ","):gmatch("([^,]+),") do
        local token = raw:match("^%s*(.-)%s*$")
        if token ~= "" then
            local id = hasMOD_IDS and token or (displayToRealId[token] or token)
            if not saveIdSet[id] then
                table.insert(saveModIds, id)
                saveIdSet[id] = true
            end
        end
    end

    -- ── Auto-migrate: persist resolved MOD_IDS for old saves ──────────────────
    local hasInstalled = false
    for _ in pairs(installedData) do hasInstalled = true; break end
    if not hasMOD_IDS and hasInstalled and #saveModIds > 0 then
        local resolvedStr = table.concat(saveModIds, ", ")
        local gmode = save.GMODE or save.gameMode
        local world = save.WORLD or save.world
        local slot  = save.slot
        pcall(function()
            local meta = ManualSave.MetaCache.read(gmode, world, slot)
            if meta and (not meta.MOD_IDS or meta.MOD_IDS == "") then
                meta.MOD_IDS = resolvedStr
                ManualSave.MetaCache.write(gmode, world, slot, meta)
            end
        end)
        save.MOD_IDS = resolvedStr
    end

    -- ── Step 3: Build allMods ──────────────────────────────────────────────────
    local allMods = {}
    local seenIds = {}

    for id, dat in pairs(installedData) do
        local inSave = saveIdSet[id] == true
        seenIds[id]  = true
        table.insert(allMods, {
            id        = id,
            name      = dat.name,
            letter    = firstAlpha(dat.name),
            icon      = dat.icon,
            tags      = dat.tags,
            installed = true,
            inSave    = inSave,
            checked   = inSave,
            status    = "ok",
            note      = "",
        })
    end

    for _, id in ipairs(saveModIds) do
        if not seenIds[id] then
            table.insert(allMods, {
                id        = id,
                name      = id,
                letter    = firstAlpha(id),
                icon      = nil,
                tags      = {},
                installed = false,
                inSave    = true,
                checked   = true,
                status    = "missing",
                note      = getText("UI_MSM_EditMods_NotInstalled"),
            })
        end
    end

    -- ── Collect unique tags across all installed mods ──────────────────────────
    local allTags = {}
    local tagSet  = {}
    for _, m in ipairs(allMods) do
        for _, t in ipairs(m.tags or {}) do
            if not tagSet[t] then tagSet[t] = true; table.insert(allTags, t) end
        end
    end
    table.sort(allTags)

    -- ── Sort helpers ───────────────────────────────────────────────────────────
    local sortMode = "default"  -- "default" | "name_asc" | "name_desc"

    local function applySort()
        if sortMode == "name_asc" then
            table.sort(allMods, function(a, b) return sortKey(a.name) < sortKey(b.name) end)
        elseif sortMode == "name_desc" then
            table.sort(allMods, function(a, b) return sortKey(a.name) > sortKey(b.name) end)
        else
            table.sort(allMods, function(a, b)
                if a.status ~= b.status then return a.status == "ok" end
                if a.inSave  ~= b.inSave  then return a.inSave  end
                return sortKey(a.name) < sortKey(b.name)
            end)
        end
    end
    applySort()

    -- ── Counters ──────────────────────────────────────────────────────────────
    local function computeCounters()
        local inSaveCount, missing, toAdd, toRemove = 0, 0, 0, 0
        for _, m in ipairs(allMods) do
            if m.inSave              then inSaveCount = inSaveCount + 1 end
            if not m.installed       then missing     = missing     + 1 end
            if m.checked and not m.inSave  then toAdd    = toAdd    + 1 end
            if not m.checked and m.inSave  then toRemove = toRemove + 1 end
        end
        return inSaveCount, missing, toAdd, toRemove
    end

    -- ── isDirty: true when selection differs from the original save ────────────
    local function isDirty()
        for _, m in ipairs(allMods) do
            if m.checked ~= m.inSave then return true end
        end
        return false
    end

    -- ── Row draw ───────────────────────────────────────────────────────────────
    local function drawModRow(panel, item, x, y, w, h, _, _)
        local cr, cg, cb, ca
        if item.status == "missing" then
            cr, cg, cb, ca = TH.WARN_R, TH.WARN_G, TH.WARN_B, 1.0
        elseif item.inSave then
            cr, cg, cb, ca = TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1.0
        else
            cr, cg, cb, ca = TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.55
        end

        ManualSave.Draw.separator(panel, x, y + h - 1, w, 0.18)

        local cbSz = 13
        local cbX  = x + 8
        local cbY  = y + math.floor((h - cbSz) / 2)
        ManualSave.Draw.checkbox(panel, cbX, cbY, cbSz, item.checked)

        local bSz = 24
        local bX  = cbX + cbSz + 8
        local bY2 = y + math.floor((h - bSz) / 2)
        ManualSave.Draw.iconBadge(panel, bX, bY2, bSz, item.letter, item.icon, cr, cg, cb, ca)

        if item.status == "missing" then
            local bt  = getText("UI_MSM_EditMods_BadgeMissing")
            local btW = getTextManager():MeasureStringX(UIFont.Small, bt) + 10
            local btH = FHS + 4
            ManualSave.Draw.badge(panel, w - 14 - btW, y + math.floor((h - btH) / 2), bt, "warn")
        end

        local textX = bX + bSz + 6
        local nameY2, noteY2
        if item.note ~= "" then
            nameY2 = y + math.floor((h - FHS * 2 - 3) / 2)
            noteY2 = nameY2 + FHS + 3
        else
            nameY2 = y + math.floor((h - FHS) / 2)
        end
        panel:drawText(item.name, textX, nameY2, cr, cg, cb, ca, UIFont.Small)
        if item.note ~= "" then
            panel:drawText(item.note, textX, noteY2,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.7 * ca, UIFont.Small)
        end
    end

    -- ── Error line helper ──────────────────────────────────────────────────────
    local function makeErrLine(parent, x, y, w, h)
        local txt = ""
        ManualSave.makeLabel(parent, {
            x=x, y=y, w=w, h=h,
            getText = function() return txt end,
            r = 0.90, g = 0.25, b = 0.22, a = 1,
        })
        return {
            show = function(msg) txt = msg or "" end,
            hide = function()    txt = ""         end,
        }
    end

    -- ── Floating panel ─────────────────────────────────────────────────────────
    local d
    d = ManualSave.makeFloatingPanel({
        w       = W,
        h       = H,
        title   = getText("UI_MSM_EditMods_Title") .. " - " .. (save.slot or ""),
        onClose = function() if d then d.close() end end,
    })
    local p      = d.panel
    local titleH = d.titleH

    -- ── Layout ─────────────────────────────────────────────────────────────────
    local errLH     = FHS + 2
    local footerH   = PAD + FHS + GAP + BUTH + GAP + errLH + GAP + BUTH + PAD
    local headerH   = titleH + PAD + FHS + GAP * 2
    local searchY   = headerH + GAP
    local ctrlY     = searchY + BUTH + GAP   -- sort + category + quick-actions row
    local listY     = ctrlY   + BUTH + GAP
    local listH     = H - listY - footerH
    local nameAreaY = H - footerH + PAD
    local nameTI_Y  = nameAreaY + FHS + GAP
    local errLY     = nameTI_Y  + BUTH + GAP
    local btnY      = errLY     + errLH + GAP

    -- ── Shared state ───────────────────────────────────────────────────────────
    local activeTag       = "all"
    local lastSearch      = ""
    local filteredMods    = {}
    local errLine         -- forward ref
    local scrollList      -- forward ref
    local createBtnHandle -- forward ref
    local sortBtnHandle   -- forward ref

    local function refreshList()
        local term = lastSearch
        filteredMods = {}
        for _, m in ipairs(allMods) do
            local matchS = term == "" or m.name:lower():find(term, 1, true)
            local matchT = activeTag == "all"
            if not matchT then
                for _, t in ipairs(m.tags or {}) do
                    if t == activeTag then matchT = true; break end
                end
            end
            if matchS and matchT then table.insert(filteredMods, m) end
        end
        if scrollList      then scrollList.setItems(filteredMods, true) end
        if createBtnHandle then createBtnHandle.setEnabled(isDirty()) end
        if sortBtnHandle   then
            local lbl = sortMode == "name_asc"  and getText("UI_MSM_EditMods_SortName")
                     or sortMode == "name_desc" and getText("UI_MSM_EditMods_SortNameDesc")
                     or getText("UI_MSM_EditMods_SortDefault")
            sortBtnHandle.setLabel(lbl)
        end
    end
    refreshList()

    -- ── Search input ────────────────────────────────────────────────────────────
    ManualSave.makeTextInput(p, {
        x = PAD, y = searchY, w = W - PAD * 2, h = BUTH,
        icon = "search",
        placeholder = getText("UI_MSM_EditMods_Search"),
        value = "",
        onChange = function(text) lastSearch = text:lower(); refreshList() end,
    })

    -- ── Controls row: sort | category dropdown | [exclude missing] | reset ──────
    local sortLbl0  = getText("UI_MSM_EditMods_SortDefault")
    local sortLbl1  = getText("UI_MSM_EditMods_SortName")
    local sortLbl2  = getText("UI_MSM_EditMods_SortNameDesc")
    local sortW     = math.max(
        getTextManager():MeasureStringX(UIFont.Small, sortLbl0),
        getTextManager():MeasureStringX(UIFont.Small, sortLbl1),
        getTextManager():MeasureStringX(UIFont.Small, sortLbl2)) + 16

    sortBtnHandle = ManualSave.makeButton(p, {
        x = PAD, y = ctrlY, w = sortW, h = BUTH,
        label = sortLbl0, style = "normal",
        onClick = function()
            if sortMode == "default" then sortMode = "name_asc"
            elseif sortMode == "name_asc" then sortMode = "name_desc"
            else sortMode = "default" end
            applySort()
            refreshList()
        end,
    })

    -- Category dropdown (only if there are tags)
    local dropW = 200
    local dropX = PAD + sortW + GAP
    local dropItems = { { id="all", label=getText("UI_MSM_EditMods_TagAll") } }
    for _, t in ipairs(allTags) do table.insert(dropItems, { id=t, label=t }) end
    ManualSave.makeDropdown(p, {
        x = dropX, y = ctrlY, w = dropW, h = BUTH,
        items = dropItems,
        value = "all",
        onChange = function(id, _) activeTag = id; refreshList() end,
    })

    -- "Reset" button (always visible, right-aligned)
    local qb2Lbl = getText("UI_MSM_EditMods_QuickDeselect")
    local qb2W   = getTextManager():MeasureStringX(UIFont.Small, qb2Lbl) + 16
    ManualSave.makeButton(p, {
        x = W - PAD - qb2W, y = ctrlY, w = qb2W, h = BUTH,
        label = qb2Lbl, style = "normal",
        onClick = function()
            for _, m in ipairs(allMods) do m.checked = m.inSave end
            refreshList()
        end,
    })

    -- "Exclude missing" button (only created when missing mods exist)
    local hasMissingMods = false
    for _, m in ipairs(allMods) do if m.status == "missing" then hasMissingMods = true; break end end
    if hasMissingMods then
        local qb1Lbl = getText("UI_MSM_EditMods_QuickSelectBad")
        local qb1W   = getTextManager():MeasureStringX(UIFont.Small, qb1Lbl) + 16
        ManualSave.makeButton(p, {
            x = W - PAD - qb2W - GAP - qb1W, y = ctrlY, w = qb1W, h = BUTH,
            label = qb1Lbl, style = "normal",
            onClick = function()
                for _, m in ipairs(allMods) do
                    if m.status == "missing" then m.checked = false end
                end
                refreshList()
            end,
        })
    end

    -- ── Scroll list ─────────────────────────────────────────────────────────────
    scrollList = ManualSave.makeScrollList(p, {
        x = PAD, y = listY, w = W - PAD * 2, h = listH,
        rowH     = FHS * 2 + 12,
        items    = filteredMods,
        bg       = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B },
        drawRow  = drawModRow,
        onSelect = function(item, _)
            item.checked = not item.checked
            refreshList()
        end,
    })

    -- ── Footer: name label + name input + buttons ───────────────────────────────
    local defaultName = ManualSave.sanitize(
        (save.slot or "") .. "_modded")

    ManualSave.makeLabel(p, {
        x = PAD, y = nameAreaY, w = W - PAD * 2, h = FHS,
        text = getText("UI_MSM_EditMods_NameLabel"),
        r = TH.DIM_R, g = TH.DIM_G, b = TH.DIM_B, a = 0.75,
    })
    local nameTI = ManualSave.makeTextInput(p, {
        x = PAD, y = nameTI_Y, w = W - PAD * 2, h = BUTH,
        placeholder = getText("UI_MSM_EditMods_NameLabel"),
        value       = defaultName,
        onChange = function(text)
            if not errLine then return end
            local name = ManualSave.sanitize(text)
            if name == "" then errLine.hide(); return end
            local st2 = ManualSave.LoadScreen and ManualSave.LoadScreen._state
            if not (st2 and st2.saves) then errLine.hide(); return end
            local gmode = save.GMODE or save.gameMode
            local world = save.WORLD or save.world
            for _, b in ipairs(st2.saves) do
                if b.slot == name and (b.GMODE or b.gameMode) == gmode and (b.WORLD or b.world) == world then
                    errLine.show(getText("UI_MSM_ErrNameExists")); return
                end
            end
            errLine.hide()
        end,
    })

    errLine = makeErrLine(p, PAD, errLY, W - PAD * 2, errLH)

    local cancelW = ManualSave.textBtnW(getText("UI_MSM_Common_BtnCancel"), 70)
    ManualSave.makeButton(p, {
        x = PAD, y = btnY, w = cancelW, h = BUTH,
        label = getText("UI_MSM_Common_BtnCancel"), style = "normal",
        onClick = function() d.close() end,
    })
    ManualSave.makeButton(p, {
        x = PAD + cancelW + GAP, y = btnY, w = 26, h = BUTH,
        label = "?", style = "normal",
        onClick = function()
            if ManualSave.openHelpScreen then ManualSave.openHelpScreen("editmods") end
        end,
    })

    local createLbl = getText("UI_MSM_EditMods_BtnCreate")
    local createW   = math.max(180, ManualSave.textBtnW(createLbl, 160))
    createBtnHandle = ManualSave.makeButton(p, {
        x = W - PAD - createW, y = btnY, w = createW, h = BUTH,
        label   = createLbl, style = "normal",
        enabled = false,
        onClick = function()
            if not isDirty() then return end
            local newName = ManualSave.sanitize(nameTI.getValue())
            if newName == "" or newName == (save.slot or "") then return end
            local st2 = ManualSave.LoadScreen and ManualSave.LoadScreen._state
            if st2 and st2.saves then
                local gmode = save.GMODE or save.gameMode
                local world = save.WORLD or save.world
                for _, b in ipairs(st2.saves) do
                    if b.slot == newName and (b.GMODE or b.gameMode) == gmode and (b.WORLD or b.world) == world then
                        if errLine then errLine.show(getText("UI_MSM_ErrNameExists")) end
                        return
                    end
                end
            end
            if errLine then errLine.hide() end

            local finalIds   = {}
            local finalNames = {}
            for _, m in ipairs(allMods) do
                if m.checked then
                    table.insert(finalIds,   m.id)
                    table.insert(finalNames, m.name)
                end
            end
            local keptStr = table.concat(finalNames, ", ")

            d.close()
            ManualSave.SignalBus.send("CLONE_MODS",
                { GMODE    = save.GMODE    or save.gameMode,
                  WORLD    = save.WORLD    or save.world,
                  OLD_SLOT = save.slot,
                  NEW_SLOT = newName,
                  MODS     = table.concat(finalIds, ",") },
                function(status)
                    if status ~= "OK" then return end
                    ManualSave.MetaCache.copy(
                        save.GMODE or save.gameMode,
                        save.WORLD or save.world,
                        save.slot, newName, true, nil,
                        { MODS    = keptStr,
                          MOD_IDS = table.concat(finalIds, ", ") })
                    if opts.onCreated then
                        pcall(opts.onCreated, newName, keptStr, table.concat(finalIds, ", "))
                    end
                end)
        end,
    })

    -- ── Counter label + separators ────────────────────────────────────────────
    local function buildCounter()
        local ins, miss, add, rem = computeCounters()
        local s = tostring(ins) .. " " .. getText("UI_MSM_EditMods_CntInSave")
        if miss > 0 then s = s .. "   " .. tostring(miss) .. " " .. getText("UI_MSM_EditMods_CntMissing") end
        if add  > 0 then s = s .. "   +" .. tostring(add)  .. " " .. getText("UI_MSM_EditMods_CntToAdd") end
        if rem  > 0 then s = s .. "   -" .. tostring(rem)  .. " " .. getText("UI_MSM_EditMods_CntToRemove") end
        return s
    end

    ManualSave.makeLabel(p, {
        x=PAD, y=titleH+PAD, w=W-PAD*2, h=FHS,
        getText = buildCounter,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.85,
    })
    ManualSave.makeSeparatorLine(p, { x=0, y=headerH,   w=W, alpha=0.3 })
    ManualSave.makeSeparatorLine(p, { x=0, y=H-footerH, w=W, alpha=0.3 })

    d.open()
    return d
end

print("[ManualSaveMod] UI/Screens/EditModsScreen.lua loaded.")
