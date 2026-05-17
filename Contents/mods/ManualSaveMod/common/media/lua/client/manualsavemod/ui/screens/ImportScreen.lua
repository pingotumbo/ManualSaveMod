-- UI/Screens/ImportScreen.lua
-- Scan vanilla PZ saves and import selected ones into ManualSave backups.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave             = ManualSave or {}
ManualSave.ImportScreen = ManualSave.ImportScreen or {}

local _screen    = nil
local _importing = false

local SCAN_FILE  = "ManualSave_VanillaScan.txt"
local QUEUE_FILE = "ManualSave_ImportQueue.txt"

-- ── I/O helpers ───────────────────────────────────────────────────────────────

function ManualSave.ImportScreen.readScanFile()
    local r = getFileReader(SCAN_FILE, true)
    if not r then return {} end
    local entries = {}
    while true do
        local line = r:readLine()
        if not line then break end
        line = line:match("^%s*(.-)%s*$") or ""
        if line == "##SCAN_DONE##" then break end
        local gmode, world, date, imp, sizeMB = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        if not gmode then
            gmode, world, date, imp = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        end
        if gmode and gmode ~= "" and world and world ~= "" then
            local sz = tonumber(sizeMB)
            table.insert(entries, {
                gmode    = gmode,
                world    = world,
                date     = date or "",
                imported = (imp == "1"),
                sizeMB   = sz or 0,
                checked  = false,
            })
        end
    end
    r:close()
    return entries
end

function ManualSave.ImportScreen.writeQueueFile(items)
    local w = getFileWriter(QUEUE_FILE, true, false)
    if not w then return false end
    for _, e in ipairs(items) do
        if not e.isHeader and e.checked then
            w:write(e.gmode .. "|" .. e.world .. "\r\n")
        end
    end
    w:close()
    return true
end

local function countChecked(flatItems)
    local n, mb = 0, 0
    for _, e in ipairs(flatItems) do
        if not e.isHeader and e.checked then
            n  = n  + 1
            mb = mb + (e.sizeMB or 0)
        end
    end
    return n, mb
end

-- ── Sort helpers ───────────────────────────────────────────────────────────────
-- sortMode: "name_asc" | "name_desc" | "date_new" | "date_old"
local function sortFlat(items, mode)
    if mode == "name_asc" then
        table.sort(items, function(a, b) return (a.world or ""):lower() < (b.world or ""):lower() end)
    elseif mode == "name_desc" then
        table.sort(items, function(a, b) return (a.world or ""):lower() > (b.world or ""):lower() end)
    elseif mode == "date_new" then
        table.sort(items, function(a, b) return (a.date or "") > (b.date or "") end)
    elseif mode == "date_old" then
        table.sort(items, function(a, b) return (a.date or "") < (b.date or "") end)
    end
end

-- ── Screen ────────────────────────────────────────────────────────────────────

function ManualSave.openImportScreen()
    if _screen then _screen.panel:bringToTop(); return end
    if _importing then return end

    local TH   = ManualSave.Theme
    local PAD  = TH.PAD
    local GAP  = TH.GAP
    local FHS  = TH.FONT_HGT_SMALL
    local BTNH = TH.BUTTON_HGT

    local ITEM_ROW_H = FHS * 2 + 10

    -- Sort cycle: name_asc → name_desc → date_new → date_old → name_asc
    local SORT_CYCLE = { "name_asc", "name_desc", "date_new", "date_old" }
    local SORT_KEYS  = {
        name_asc  = "UI_MSM_Import_SortNameAsc",
        name_desc = "UI_MSM_Import_SortNameDesc",
        date_new  = "UI_MSM_Import_SortDateNew",
        date_old  = "UI_MSM_Import_SortDateOld",
    }
    local sortMode = "date_new"

    -- Filter cycle: "all" → "unimported" → "imported" → "all"
    -- (button label always shows the CURRENT filter state)
    local FILTER_CYCLE = { "all", "unimported", "imported" }
    local filterMode   = "all"

    -- Measure button widths from all possible labels
    local sortBtnW = 0
    for _, k in ipairs(SORT_CYCLE) do
        sortBtnW = math.max(sortBtnW,
            getTextManager():MeasureStringX(UIFont.Small, getText(SORT_KEYS[k])) + 16)
    end
    local cancelW    = ManualSave.textBtnW(getText("UI_MSM_Common_BtnCancel"),       60)
    local selectAllW = math.max(
        ManualSave.textBtnW(getText("UI_MSM_Import_BtnSelectAll"),   70),
        ManualSave.textBtnW(getText("UI_MSM_Import_BtnUnselectAll"), 70))
    local filterW = math.max(
        ManualSave.textBtnW(getText("UI_MSM_Import_FilterAll"),        80),
        ManualSave.textBtnW(getText("UI_MSM_Import_FilterUnimported"), 80),
        ManualSave.textBtnW(getText("UI_MSM_Import_FilterImported"),   80))
    local importBtnW = math.max(180, ManualSave.textBtnW(getText("UI_MSM_Import_BtnImport"), 120))

    local W = math.max(600,
        PAD + cancelW + GAP + selectAllW + GAP + filterW + GAP + sortBtnW
        + GAP + 28 + GAP + importBtnW + PAD)
    local H = 480

    local phase     = "scanning"
    local allFlat   = {}   -- raw flat list from scan (no headers)
    local displayed = {}   -- grouped list shown in scrollList
    local searchTxt = ""
    local errMsg    = ""

    local d = ManualSave.makeFloatingPanel({
        w=W, h=H, title=getText("UI_MSM_Import_Title"),
        onClose = function() ManualSave.closeImportScreen() end,
    })
    local p      = d.panel
    local titleH = d.titleH
    _screen = d

    -- ── Forward refs ──────────────────────────────────────────────────────────
    local scrollList
    local sortBtnHandle
    local selectBtnHandle
    local filterBtnHandle

    -- ── Rebuild displayed list ────────────────────────────────────────────────
    local function rebuild()
        local term = searchTxt
        local filtered = {}
        for _, e in ipairs(allFlat) do
            local matchS = term == "" or
                (e.world or ""):lower():find(term, 1, true) or
                (e.gmode or ""):lower():find(term, 1, true)
            local matchF = filterMode == "all"
                or (filterMode == "unimported" and not e.imported)
                or (filterMode == "imported"   and     e.imported)
            if matchS and matchF then table.insert(filtered, e) end
        end
        sortFlat(filtered, sortMode)
        displayed = filtered
        if scrollList then scrollList.setItems(displayed, true) end

        -- Update select button label
        if selectBtnHandle then
            local allChecked = true
            for _, e in ipairs(filtered) do
                if not e.checked then allChecked = false; break end
            end
            selectBtnHandle.setLabel(allChecked and
                getText("UI_MSM_Import_BtnUnselectAll") or
                getText("UI_MSM_Import_BtnSelectAll"))
        end

        -- Update filter button label
        if filterBtnHandle then
            local lbl = filterMode == "unimported" and getText("UI_MSM_Import_FilterUnimported")
                     or filterMode == "imported"   and getText("UI_MSM_Import_FilterImported")
                     or getText("UI_MSM_Import_FilterAll")
            filterBtnHandle.setLabel(lbl)
        end

        -- Update sort button label
        if sortBtnHandle then
            sortBtnHandle.setLabel(getText(SORT_KEYS[sortMode]))
        end
    end

    -- ── Status bar ────────────────────────────────────────────────────────────
    local statusH = FHS + 10
    ManualSave.makeLabel(p, {
        x=0, y=titleH, w=W, h=statusH,
        bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 },
        textX=PAD, textY=5,
        getText = function()
            if phase == "scanning" then return getText("UI_MSM_Import_Scanning") end
            if phase ~= "ready"   then return getText("UI_MSM_Import_ErrPrefix") .. errMsg end
            local n     = #allFlat
            local sel, mb = countChecked(allFlat)
            local base  = n .. " " .. (n ~= 1 and getText("UI_MSM_Import_FoundPlural") or getText("UI_MSM_Import_FoundSingle"))
            if sel > 0 then
                base = base .. "   " .. sel .. " " .. getText("UI_MSM_Import_Selected")
                if mb > 0 then base = base .. " " .. mb .. " MB" end
            end
            return base
        end,
        getR = function() return phase == "ready" and TH.TEXT_R or (phase == "scanning" and TH.MUTED_R or TH.DANGER_R) end,
        getG = function() return phase == "ready" and TH.TEXT_G or (phase == "scanning" and TH.MUTED_G or TH.DANGER_G) end,
        getB = function() return phase == "ready" and TH.TEXT_B or (phase == "scanning" and TH.MUTED_B or TH.DANGER_B) end,
    })

    -- ── Search ────────────────────────────────────────────────────────────────
    local searchY = titleH + statusH + GAP
    ManualSave.makeTextInput(p, {
        x=PAD, y=searchY, w=W - PAD * 2, h=BTNH,
        icon="search", placeholder=getText("UI_MSM_Import_SearchPlaceholder"),
        onChange = function(text) searchTxt = text:lower(); rebuild() end,
    })

    -- ── Scroll list ───────────────────────────────────────────────────────────
    local listY = searchY + BTNH + GAP
    local listH = H - listY - BTNH - PAD * 2 - GAP

    scrollList = ManualSave.makeScrollList(p, {
        x=PAD, y=listY, w=W - PAD * 2, h=listH,
        rowH     = ITEM_ROW_H,
        items    = displayed,
        bg       = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B },
        drawRow  = function(panel, item, rx, ry, rw, rh, _, _)
            if item.checked then
                panel:drawRect(rx, ry, rw, rh, 0.10, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
            end
            ManualSave.Draw.separator(panel, rx, ry + rh - 1, rw, 0.12)

            local cbSz = 13
            local cbX  = rx + 8
            local cbY  = ry + math.floor((rh - cbSz) / 2)
            ManualSave.Draw.checkbox(panel, cbX, cbY, cbSz, item.checked)

            local nameX  = cbX + cbSz + 8
            local alpha  = item.imported and 0.55 or 1
            local lineY  = ry + math.floor((rh / 2) - FHS) - 1
            local line2Y = lineY + FHS + 2

            panel:drawText(item.world, nameX, lineY,
                TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, alpha, UIFont.Small)
            if item.imported then
                local iw = getTextManager():MeasureStringX(UIFont.Small, item.world)
                ManualSave.Draw.badge(panel, nameX + iw + 6, lineY + 1,
                    getText("UI_MSM_Import_BadgeReimport"), "dim")
            end

            panel:drawText(item.gmode, nameX, line2Y,
                TH.DIM_R, TH.DIM_G, TH.DIM_B, 0.7, UIFont.Small)
            if item.date ~= "" then
                local gmW = getTextManager():MeasureStringX(UIFont.Small, item.gmode)
                panel:drawText(item.date, nameX + gmW + 10, line2Y,
                    TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.45, UIFont.Small)
            end

            if item.sizeMB and item.sizeMB > 0 then
                local szStr = tostring(item.sizeMB) .. " MB"
                local szW   = getTextManager():MeasureStringX(UIFont.Small, szStr)
                panel:drawText(szStr, rx + rw - 14 - szW, ry + math.floor((rh - FHS) / 2),
                    TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.45, UIFont.Small)
            end
        end,
        onSelect = function(item, _)
            item.checked = not item.checked
            rebuild()
        end,
    })

    -- ── Footer buttons ────────────────────────────────────────────────────────
    local btnY        = H - BTNH - PAD
    local cancelX     = PAD
    local selectAllX  = cancelX    + cancelW    + GAP
    local filterX     = selectAllX + selectAllW + GAP
    local sortX       = filterX    + filterW    + GAP
    local importBtnX  = W - PAD - importBtnW
    local helpX       = importBtnX - GAP - 28

    ManualSave.makeButton(p, {
        x=cancelX, y=btnY, w=cancelW, h=BTNH,
        label=getText("UI_MSM_Common_BtnCancel"), style="normal",
        onClick = function() ManualSave.closeImportScreen() end,
    })

    selectBtnHandle = ManualSave.makeButton(p, {
        x=selectAllX, y=btnY, w=selectAllW, h=BTNH,
        label=getText("UI_MSM_Import_BtnSelectAll"), style="normal",
        onClick = function()
            if phase ~= "ready" then return end
            local allChecked = true
            for _, e in ipairs(displayed) do
                if not e.isHeader and not e.checked then allChecked = false; break end
            end
            for _, e in ipairs(displayed) do
                if not e.isHeader then e.checked = not allChecked end
            end
            rebuild()
        end,
    })

    filterBtnHandle = ManualSave.makeButton(p, {
        x=filterX, y=btnY, w=filterW, h=BTNH,
        label=getText("UI_MSM_Import_FilterAll"), style="normal",
        onClick = function()
            if phase ~= "ready" then return end
            local cur = filterMode
            local next = FILTER_CYCLE[1]
            for i, v in ipairs(FILTER_CYCLE) do
                if v == cur then next = FILTER_CYCLE[(i % #FILTER_CYCLE) + 1]; break end
            end
            filterMode = next
            rebuild()
        end,
    })

    sortBtnHandle = ManualSave.makeButton(p, {
        x=sortX, y=btnY, w=sortBtnW, h=BTNH,
        label=getText(SORT_KEYS[sortMode]), style="normal",
        onClick = function()
            if phase ~= "ready" then return end
            local cur = sortMode
            local next = SORT_CYCLE[1]
            for i, v in ipairs(SORT_CYCLE) do
                if v == cur then next = SORT_CYCLE[(i % #SORT_CYCLE) + 1]; break end
            end
            sortMode = next
            rebuild()
        end,
    })

    ManualSave.makeButton(p, {
        x=helpX, y=btnY, w=28, h=BTNH, label="?", style="normal",
        onClick = function()
            if ManualSave.openHelpScreen then ManualSave.openHelpScreen("import") end
        end,
    })

    ManualSave.makeButton(p, {
        x=importBtnX, y=btnY, w=importBtnW, h=BTNH,
        label=getText("UI_MSM_Import_BtnImport"), style="primary", enabled=false,
        update = function(self2)
            local n = countChecked(allFlat)
            self2:setTitle(n > 0
                and getText("UI_MSM_Import_BtnImportN", tostring(n))
                or  getText("UI_MSM_Import_BtnImport"))
            self2:setEnable(phase == "ready" and n > 0)
        end,
        onClick = function()
            if phase ~= "ready" then return end
            local n = countChecked(allFlat)
            if n == 0 then return end
            if not ManualSave.ImportScreen.writeQueueFile(allFlat) then
                phase = "error"; errMsg = getText("UI_MSM_Import_ErrQueueFile"); return
            end
            local progressPanel = ManualSave.openProgressPanel and
                ManualSave.openProgressPanel({ label = getText("UI_MSM_Import_BtnImport") }) or nil
            _importing = true; _screen = nil; d.close()
            ManualSave.SignalBus.send("IMPORT", nil, function(status)
                _importing = false
                if progressPanel then
                    if status == "OK" then
                        pcall(progressPanel.showDone)
                        local t = 0
                        local closeH
                        closeH = function()
                            t = t + 1
                            if t >= 60 then
                                Events.OnRenderTick.Remove(closeH)
                                pcall(progressPanel.close)
                            end
                        end
                        Events.OnRenderTick.Add(closeH)
                    else
                        pcall(progressPanel.close)
                    end
                end
                if status == "OK" then
                    for _, e in ipairs(allFlat) do
                        if e.checked then
                            pcall(ManualSave.MetaCache.tryEnrichNative, e.gmode, e.world, e.world)
                        end
                    end
                    if ManualSave.LoadScreen._screen then
                        ManualSave.LoadScreen._state.saves = ManualSave.SaveManager.listSaves()
                        ManualSave.LoadScreen.applyFilter()
                    end
                end
            end, 7200)
        end,
    })

    -- ── Kick off scan ─────────────────────────────────────────────────────────
    ManualSave.SignalBus.send("SCAN_VANILLA", nil, function(status)
        if status ~= "OK" then
            phase = "error"; errMsg = getText("UI_MSM_Import_ErrScanFailed"); return
        end
        allFlat = ManualSave.ImportScreen.readScanFile()
        phase   = "ready"
        rebuild()
    end, 3600)

    d.open()
end

function ManualSave.closeImportScreen()
    if not _screen then return end
    local d = _screen; _screen = nil
    if not _importing then ManualSave.SignalBus.cancel() end
    d.close()
end

print("[ManualSaveMod] UI/Screens/ImportScreen.lua loaded.")
