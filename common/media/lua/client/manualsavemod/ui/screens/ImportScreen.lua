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
        local gmode, world, date, imp = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        if gmode and gmode ~= "" and world and world ~= "" then
            table.insert(entries, {
                gmode=gmode, world=world, date=date or "",
                imported=(imp == "1"), checked=false,
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
        if e.checked then w:write(e.gmode .. "|" .. e.world .. "\r\n") end
    end
    w:close()
    return true
end

function ManualSave.ImportScreen.countChecked(items)
    local n = 0
    for _, e in ipairs(items) do if e.checked then n = n + 1 end end
    return n
end

-- ── Screen ────────────────────────────────────────────────────────────────────

function ManualSave.openImportScreen()
    if _screen then _screen.panel:bringToTop(); return end
    if _importing then return end

    local TH    = ManualSave.Theme
    local W, H  = 600, 480
    local PAD   = TH.PAD
    local BTNH  = TH.BUTTON_HGT
    local FHS   = TH.FONT_HGT_SMALL
    local ROW_H = FHS * 2 + 10

    local phase    = "scanning"
    local allItems = {}
    local searchTxt = ""
    local errMsg   = ""

    local d = ManualSave.makeFloatingPanel({
        w=W, h=H, title=getText("UI_MSM_Import_Title"),
        onClose = function() ManualSave.closeImportScreen() end,
    })
    local p      = d.panel
    local titleH = d.titleH
    _screen = d

    -- Status bar
    local statusH = FHS + 10
    ManualSave.makeLabel(p, {
        x=0, y=titleH, w=W, h=statusH,
        bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 },
        textX=PAD, textY=5,
        getText = function()
            if phase == "scanning" then
                return getText("UI_MSM_Import_Scanning")
            elseif phase == "ready" then
                local n = #allItems
                return n > 0
                    and (n .. " " .. (n ~= 1 and getText("UI_MSM_Import_FoundPlural") or getText("UI_MSM_Import_FoundSingle")) .. getText("UI_MSM_Import_FoundSuffix"))
                    or  getText("UI_MSM_Import_NoSaves")
            else
                return getText("UI_MSM_Import_ErrPrefix") .. errMsg
            end
        end,
        getR = function() return phase == "ready" and TH.TEXT_R or (phase == "scanning" and TH.MUTED_R or TH.DANGER_R) end,
        getG = function() return phase == "ready" and TH.TEXT_G or (phase == "scanning" and TH.MUTED_G or TH.DANGER_G) end,
        getB = function() return phase == "ready" and TH.TEXT_B or (phase == "scanning" and TH.MUTED_B or TH.DANGER_B) end,
    })

    -- Search + list
    local searchY = titleH + statusH + 4
    local list    -- forward ref; set below before any callback fires

    ManualSave.makeTextInput(p, {
        x=PAD, y=searchY, w=W - PAD * 2, h=BTNH,
        icon="search", placeholder=getText("UI_MSM_Import_SearchPlaceholder"),
        onChange = function(text)
            searchTxt = text:lower()
            if not list then return end
            if searchTxt == "" then list.setItems(allItems); return end
            local out = {}
            for _, e in ipairs(allItems) do
                if (e.world or ""):lower():find(searchTxt, 1, true)
                or (e.gmode or ""):lower():find(searchTxt, 1, true) then
                    table.insert(out, e)
                end
            end
            list.setItems(out)
        end,
    })

    local listY = searchY + BTNH + 4
    local listH = H - listY - BTNH - PAD * 2 - 4

    list = ManualSave.makeScrollList(p, {
        x=PAD, y=listY, w=W - PAD * 2, h=listH,
        rowH=ROW_H, items=allItems,
        drawRow = function(panel, item, rx, ry, rw, rh, sel, _)
            if item.checked then
                panel:drawRect(rx, ry, rw, rh, 0.10, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
            elseif sel then
                panel:drawRect(rx, ry, rw, rh, 0.06, 1, 1, 1)
            end
            local cbW    = getTextManager():MeasureStringX(UIFont.Small, "[x] ")
            local lineY  = ry + math.floor((rh / 2) - FHS) - 1
            local line2Y = lineY + FHS + 2
            local cbR    = item.checked and TH.ACCENT_R or TH.MUTED_R * 0.6
            local cbG    = item.checked and TH.ACCENT_G or TH.MUTED_G * 0.6
            local cbB    = item.checked and TH.ACCENT_B or TH.MUTED_B * 0.6
            panel:drawText(item.checked and "[x]" or "[ ]", rx + 4, lineY, cbR, cbG, cbB, 1, UIFont.Small)
            local nameX = rx + 4 + cbW
            local alpha = item.imported and 0.55 or 1
            panel:drawText(item.world, nameX, lineY, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, alpha, UIFont.Small)
            if item.imported then
                local iw = getTextManager():MeasureStringX(UIFont.Small, item.world)
                panel:drawText("  " .. getText("UI_MSM_Import_BadgReimport"), nameX + iw, lineY,
                    TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.4, UIFont.Small)
            end
            panel:drawText(item.gmode, nameX, line2Y, TH.DIM_R, TH.DIM_G, TH.DIM_B, 0.7, UIFont.Small)
            if item.date ~= "" then
                local gmW = getTextManager():MeasureStringX(UIFont.Small, item.gmode)
                panel:drawText(item.date, nameX + gmW + 10, line2Y,
                    TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.45, UIFont.Small)
            end
        end,
        onSelect = function(item, _) item.checked = not item.checked end,
    })

    -- Footer buttons
    local btnY = H - BTNH - PAD

    ManualSave.makeButton(p, {
        x=PAD, y=btnY, w=80, h=BTNH, label=getText("UI_MSM_Common_BtnCancel"), style="normal",
        onClick = function() ManualSave.closeImportScreen() end,
    })
    ManualSave.makeButton(p, {
        x=PAD + 80 + TH.GAP, y=btnY, w=90, h=BTNH, label=getText("UI_MSM_Import_BtnSelectAll"), style="normal",
        onClick = function()
            if phase ~= "ready" then return end
            for _, e in ipairs(allItems) do e.checked = true end
        end,
    })
    ManualSave.makeButton(p, {
        x=PAD + 80 + TH.GAP + 90 + TH.GAP, y=btnY, w=106, h=BTNH, label=getText("UI_MSM_Import_BtnUnimported"), style="normal",
        onClick = function()
            if phase ~= "ready" then return end
            for _, e in ipairs(allItems) do e.checked = not e.imported end
        end,
    })

    ManualSave.makeButton(p, {
        x=W - PAD - 160 - TH.GAP - 28, y=btnY, w=28, h=BTNH, label="?", style="normal",
        onClick = function()
            if ManualSave.openHelpScreen then ManualSave.openHelpScreen("import") end
        end,
    })

    ManualSave.makeButton(p, {
        x=W - PAD - 160, y=btnY, w=160, h=BTNH, label=getText("UI_MSM_Import_BtnImport"), style="primary", enabled=false,
        update = function(self2)
            local n = ManualSave.ImportScreen.countChecked(allItems)
            self2:setTitle(n > 0 and getText("UI_MSM_Import_BtnImportN", tostring(n)) or getText("UI_MSM_Import_BtnImport"))
            self2:setEnable(phase == "ready" and n > 0)
        end,
        onClick = function()
            if phase ~= "ready" then return end
            local n = ManualSave.ImportScreen.countChecked(allItems)
            if n == 0 then return end
            if not ManualSave.ImportScreen.writeQueueFile(allItems) then
                phase = "error"; errMsg = getText("UI_MSM_Import_ErrQueueFile"); return
            end
            _importing = true; _screen = nil; d.close()
            ManualSave.SignalBus.send("IMPORT", nil, function(status)
                _importing = false
                if status == "OK" then
                    for _, e in ipairs(allItems) do
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

    -- Kick off scan
    ManualSave.SignalBus.send("SCAN_VANILLA", nil, function(status)
        if status ~= "OK" then phase = "error"; errMsg = getText("UI_MSM_Import_ErrScanFailed"); return end
        allItems = ManualSave.ImportScreen.readScanFile()
        list.setItems(allItems)
        phase = "ready"
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
