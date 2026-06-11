-- UI/Base/Widgets/Sections/SaveDetailPanel.lua
-- Right-column detail area for LoadScreen: thumbnail, save info, rename/clone/delete.
-- All logic is internal. Sets ManualSave.LoadScreen._detailPanel, _actBtns, _renameEntry,
-- _beginRename, _commitRename.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, need-check-nil, inject-field, param-type-mismatch

ManualSave = ManualSave or {}

local sanitize    = ManualSave.sanitize
local slotDisplay = ManualSave.slotDisplay

local function truncate(s, max)
    if #s <= max then return s end
    return s:sub(1, max - 3) .. "..."
end

-- opts: { contentY, contentH, rightX, rightW, thumbH, actW }
function ManualSave.makeSaveDetailPanel(parent, opts)
    local TH       = ManualSave.Theme
    local contentY = opts.contentY
    local contentH = opts.contentH
    local rightX   = opts.rightX
    local rightW   = opts.rightW
    local thumbH   = opts.thumbH
    local actW = math.max(opts.actW or 0,
        ManualSave.textBtnW(getText("UI_MSM_Detail_BtnRename"),    60),
        ManualSave.textBtnW(getText("UI_MSM_Detail_BtnDuplicate"), 60),
        ManualSave.textBtnW(getText("UI_MSM_Detail_BtnDelete"),    60))
    local detailY  = contentY + TH.PAD + thumbH + TH.PAD
    local detailH  = contentH - thumbH - TH.PAD * 3

    -- ── Logic ────────────────────────────────────────────────────────────────

    local entry  -- forward ref; set below

    local function beginRenameInline()
        local st = ManualSave.LoadScreen._state
        if not st or not st.selected or not entry then return end
        st.renamingSlot = true
        entry.setValue(slotDisplay(st.selected.slot))
        entry.setVisible(true)
        entry.focus()
    end

    local function commitRename(confirm)
        local st = ManualSave.LoadScreen._state
        if not st or not entry or not st.renamingSlot then return end
        st.renamingSlot = false
        entry.setVisible(false)
        if not confirm then return end
        local newName = sanitize(entry.getValue())
        if newName == "" or not st.selected or newName == st.selected.slot then return end
        local old = st.selected
        ManualSave.SaveManager.rename(old.GMODE or old.gameMode, old.WORLD or old.world, old.slot, newName,
            function(status)
                if status == "OK" then
                    old.slot = newName
                    ManualSave.LoadScreen.applyFilter()
                end
            end)
    end

    local function doDelete()
        local st = ManualSave.LoadScreen._state
        if not st or not st.selected then return end
        local m = st.selected
        local function execDelete()
            ManualSave.SaveManager.delete(m.GMODE or m.gameMode, m.WORLD or m.world, m.slot,
                    function(status)
                        if status ~= "OK" then return end
                        -- Match across both lowercase and UPPERCASE forms:
                        -- duplicated rows and self-healed meta entries can
                        -- end up with only one casing populated, and a strict
                        -- b.slot == m.slot AND b.world == m.world would miss
                        -- them — the row would then linger in the list until
                        -- the user closed and reopened the Load screen.
                        local mWorld = m.world or m.WORLD or ""
                        local mSlot  = m.slot  or m.SLOT  or ""
                        local mGmode = m.gameMode or m.GMODE or ""
                        local removed = false
                        for i, b in ipairs(st.saves) do
                            if (b.slot or b.SLOT or "") == mSlot
                               and (b.world or b.WORLD or "") == mWorld
                               and (b.gameMode or b.GMODE or "") == mGmode then
                                table.remove(st.saves, i)
                                removed = true
                                break
                            end
                        end
                        if not removed then
                            -- Belt-and-suspenders: rebuild the cache from the
                            -- on-disk index so the deleted row never lingers
                            -- regardless of which casing combination the
                            -- selected item happened to carry.
                            st.saves = ManualSave.SaveManager.listSaves()
                        end
                        st.selected = nil; st.selectedThumb = nil; st.selectedMods = {}
                        local ls = ManualSave.LoadScreen
                        if ls._btnLoad  then ls._btnLoad.setEnabled(false) end
                        if ls._btnMore  then ls._btnMore.setEnabled(false) end
                        if ls._actBtns  then
                            ls._actBtns.rename.setEnabled(false)
                            ls._actBtns.clone.setEnabled(false)
                            ls._actBtns.delete.setEnabled(false)
                        end
                        ManualSave.LoadScreen.applyFilter()
                    end)
        end
        if ManualSave.Config.get("CONFIRM_DELETE") == "0" then
            execDelete()
        else
            ManualSave.openConfirmDialog({
                title       = getText("UI_MSM_Detail_DeleteConfirm"),
                body        = getText("UI_MSM_Detail_DeleteBody", "\"" .. truncate(slotDisplay(m.slot or ""), 22) .. "\""),
                confirm     = getText("UI_MSM_Detail_BtnDelete"),
                danger      = true,
                helpSection = "delete",
                onConfirm   = execDelete,
            })
        end
    end

    local function doClone()
        local st = ManualSave.LoadScreen._state
        if not st or not st.selected then return end
        local old = st.selected
        ManualSave.openNameInputDialog({
            title       = getText("UI_MSM_Detail_DuplicateAs"),
            value       = ManualSave.nextCopyName(old.slot, st.saves),
            confirm     = getText("UI_MSM_Detail_BtnDuplicate"),
            helpSection = "duplicate",
            names = (function()
                local st2 = ManualSave.LoadScreen._state
                if not st2 then return {} end
                local gmode = old.GMODE or old.gameMode
                local world = old.WORLD or old.world
                local ns = {}
                for _, b in ipairs(st2.saves) do
                    if (b.GMODE or b.gameMode) == gmode and (b.WORLD or b.world) == world then
                        table.insert(ns, b.slot)
                    end
                end
                return ns
            end)(),
            onConfirm = function(newName)
                newName = sanitize(newName)
                if newName == "" then return end
                ManualSave.SaveManager.clone(old.GMODE or old.gameMode, old.WORLD or old.world, old.slot, newName,
                    function(status, result)
                        if status ~= "OK" then return end
                        local copy = {}
                        for k, v in pairs(old) do copy[k] = v end
                        -- See SaveOps.lua: keep both casings of the slot id
                        -- in sync so the duplicate's metadata renders with
                        -- its own name, not the original's.
                        copy.slot = newName
                        copy.SLOT = newName
                        copy.DATE = (result and result.DATE) or os.date("%d %b %Y %H:%M")
                        table.insert(st.saves, copy)
                        ManualSave.LoadScreen.applyFilter()
                    end)
            end,
        })
    end

    -- ── UI ───────────────────────────────────────────────────────────────────

    ManualSave.makeThumbnail(parent, {
        x=rightX + TH.PAD, y=contentY + TH.PAD,
        w=rightW - TH.PAD * 2, h=thumbH,
        getTexture = function()
            local st = ManualSave.LoadScreen._state; return st and st.selectedThumb
        end,
        hasContent = function()
            local st = ManualSave.LoadScreen._state; return st and st.selected ~= nil
        end,
        zoomable = true,
        zoomCaption = function()
            local st = ManualSave.LoadScreen._state
            local sel = st and st.selected
            if not sel then return "" end
            -- st.selected is the slot record (a table); pick a printable label.
            if type(sel) == "table" then
                return sel.slot or sel.name or sel.title or ""
            end
            return tostring(sel)
        end,
    })

    ManualSave.LoadScreen._detailPanel = ManualSave.makeSaveDetailView(parent, {
        x=rightX + TH.PAD, y=detailY, w=rightW - TH.PAD * 2, h=detailH,
        onMouseUp = function(dp, mx, my)
            local st = ManualSave.LoadScreen._state
            if not st or not st.selected then return end
            if my >= 0 and my <= TH.FONT_HGT_LARGE + 8 and mx < dp.width - actW * 3 - 18 then
                beginRenameInline()
            else
                commitRename(false)
            end
        end,
    })

    ManualSave.LoadScreen._actBtns        = {}
    ManualSave.LoadScreen._actBtns.rename = ManualSave.makeButton(parent, {
        x=rightX + rightW - TH.PAD - actW * 3 - TH.GAP * 2, y=detailY,
        w=actW, h=TH.BUTTON_HGT - 2, label=getText("UI_MSM_Detail_BtnRename"), style="normal", enabled=false,
        onClick = function() beginRenameInline() end,
    })
    ManualSave.LoadScreen._actBtns.clone  = ManualSave.makeButton(parent, {
        x=rightX + rightW - TH.PAD - actW * 2 - TH.GAP, y=detailY,
        w=actW, h=TH.BUTTON_HGT - 2, label=getText("UI_MSM_Detail_BtnDuplicate"), style="normal", enabled=false,
        onClick = function() doClone() end,
    })
    ManualSave.LoadScreen._actBtns.delete = ManualSave.makeButton(parent, {
        x=rightX + rightW - TH.PAD - actW, y=detailY,
        w=actW, h=TH.BUTTON_HGT - 2, label=getText("UI_MSM_Detail_BtnDelete"), style="danger", enabled=false,
        onClick = function() doDelete() end,
    })

    entry = ManualSave.makeTextInput(parent, {
        x=rightX + TH.PAD, y=detailY,
        w=rightW - TH.PAD * 2 - actW * 3 - 18, h=TH.FONT_HGT_LARGE + 4,
        font=UIFont.Large, visible=false,
        onCommandEntered = function()    commitRename(true)  end,
        onLostFocus      = function()    commitRename(false) end,
        onKeyRelease     = function(_, key)
            if key == Keyboard.KEY_ESCAPE then commitRename(false) end
        end,
    })
    ManualSave.LoadScreen._renameEntry = entry

    ManualSave.LoadScreen._beginRename  = beginRenameInline
    ManualSave.LoadScreen._commitRename = commitRename
    ManualSave.LoadScreen._doDelete     = doDelete
    ManualSave.LoadScreen._doClone      = doClone
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SaveDetailPanel.lua loaded.")
