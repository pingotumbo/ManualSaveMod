-- UI/Screens/EditModsScreen.lua
-- Floating panel: browse and edit the mod list for a cloned save.
-- Pure assembler: all logic lives in sections/Mod*.lua and core/EditMods.lua.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, undefined-field

ManualSave              = ManualSave or {}
ManualSave.EditModsScreen = ManualSave.EditModsScreen or {}

-- opts: { save, onCreated }
function ManualSave.openEditModsScreen(opts)
    local TH   = ManualSave.Theme
    local W    = 720
    local H    = 600
    local PAD  = TH.PAD
    local GAP  = TH.GAP
    local FHS  = TH.FONT_HGT_SMALL
    local BUTH = TH.BUTTON_HGT

    local modData = ManualSave.EditMods.buildModList(opts.save)
    ManualSave.EditModsScreen._state = {
        save        = opts.save,
        allMods     = modData.allMods,
        allTags     = modData.allTags,
        filteredMods = {},
        sortMode    = "default",
        activeTag   = "all",
        lastSearch  = "",
        onCreated   = opts.onCreated,
    }

    local d
    d = ManualSave.makeFloatingPanel({
        w       = W,
        h       = H,
        title   = getText("UI_MSM_EditMods_Title") .. " - " .. (opts.save.slot or ""),
        onClose = function() if d then d.close() end end,
    })
    ManualSave.EditModsScreen._close = function() d.close() end
    local p      = d.panel
    local titleH = d.titleH

    -- Layout
    local errLH     = FHS + 2
    local footerH   = PAD + FHS + GAP + BUTH + GAP + errLH + GAP + BUTH + PAD
    local headerH   = titleH + PAD + FHS + GAP * 2
    local searchY   = headerH + GAP
    local ctrlY     = searchY + BUTH + GAP
    local listY     = ctrlY   + BUTH + GAP
    local listH     = H - listY - footerH
    local nameAreaY = H - footerH + PAD
    local nameTI_Y  = nameAreaY + FHS + GAP
    local errLY     = nameTI_Y  + BUTH + GAP
    local btnY      = errLY     + errLH + GAP

    ManualSave.makeModSearchControls(p, { W=W, PAD=PAD, GAP=GAP, BUTH=BUTH, searchY=searchY, ctrlY=ctrlY })
    ManualSave.makeModScrollList(p,    { x=PAD, y=listY, w=W-PAD*2, h=listH, rowH=FHS*2+12 })
    ManualSave.makeModCloneFooter(p,   { W=W, PAD=PAD, GAP=GAP, FHS=FHS, BUTH=BUTH,
                                         nameAreaY=nameAreaY, nameTI_Y=nameTI_Y,
                                         errLY=errLY, btnY=btnY,
                                         onCancel = function() d.close() end })

    -- Counter label
    ManualSave.makeLabel(p, {
        x=PAD, y=titleH+PAD, w=W-PAD*2, h=FHS,
        getText = function()
            local st = ManualSave.EditModsScreen._state
            if not st then return "" end
            local ins, miss, add, rem = 0, 0, 0, 0
            for _, m in ipairs(st.allMods) do
                if m.inSave              then ins  = ins  + 1 end
                if not m.installed       then miss = miss + 1 end
                if m.checked and not m.inSave  then add = add + 1 end
                if not m.checked and m.inSave  then rem = rem + 1 end
            end
            local s = tostring(ins) .. " " .. getText("UI_MSM_EditMods_CntInSave")
            if miss > 0 then s = s .. "   " .. tostring(miss) .. " " .. getText("UI_MSM_EditMods_CntMissing") end
            if add  > 0 then s = s .. "   +" .. tostring(add)  .. " " .. getText("UI_MSM_EditMods_CntToAdd") end
            if rem  > 0 then s = s .. "   -" .. tostring(rem)  .. " " .. getText("UI_MSM_EditMods_CntToRemove") end
            return s
        end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.85,
    })
    ManualSave.makeSeparatorLine(p, { x=0, y=headerH,   w=W, alpha=0.3 })
    ManualSave.makeSeparatorLine(p, { x=0, y=H-footerH, w=W, alpha=0.3 })

    ManualSave.EditModsScreen.applySort()
    ManualSave.EditModsScreen.refreshList()
    d.open()
    return d
end

print("[ManualSaveMod] UI/Screens/EditModsScreen.lua loaded.")
