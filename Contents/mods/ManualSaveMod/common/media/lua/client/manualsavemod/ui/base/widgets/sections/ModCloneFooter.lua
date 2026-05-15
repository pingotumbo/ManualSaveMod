-- UI/Base/Widgets/Sections/ModCloneFooter.lua
-- Footer for EditModsScreen: name label + name input + error line + cancel/help/create buttons.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave              = ManualSave or {}
ManualSave.EditModsScreen = ManualSave.EditModsScreen or {}

-- opts: { W, PAD, GAP, FHS, BUTH, nameAreaY, nameTI_Y, errLY, btnY, onCancel }
function ManualSave.makeModCloneFooter(parent, opts)
    local TH       = ManualSave.Theme
    local W        = opts.W
    local PAD      = opts.PAD
    local GAP      = opts.GAP
    local FHS      = opts.FHS
    local BUTH     = opts.BUTH
    local st       = ManualSave.EditModsScreen._state
    local save     = st and st.save or {}
    local errTxt   = ""

    ManualSave.makeLabel(parent, {
        x = PAD, y = opts.nameAreaY, w = W - PAD * 2, h = FHS,
        text = getText("UI_MSM_EditMods_NameLabel"),
        r = TH.DIM_R, g = TH.DIM_G, b = TH.DIM_B, a = 0.75,
    })

    local nameTI = ManualSave.makeTextInput(parent, {
        x = PAD, y = opts.nameTI_Y, w = W - PAD * 2, h = BUTH,
        placeholder = getText("UI_MSM_EditMods_NameLabel"),
        value       = ManualSave.sanitize((save.slot or "") .. "_modded"),
        onChange = function(text)
            local st2 = ManualSave.EditModsScreen._state
            if not st2 then return end
            local name = ManualSave.sanitize(text)
            if name == "" then errTxt = ""; return end
            local ls = ManualSave.LoadScreen and ManualSave.LoadScreen._state
            if not (ls and ls.saves) then errTxt = ""; return end
            local gmode = st2.save.GMODE or st2.save.gameMode
            local world = st2.save.WORLD or st2.save.world
            for _, b in ipairs(ls.saves) do
                if b.slot == name and (b.GMODE or b.gameMode) == gmode and (b.WORLD or b.world) == world then
                    errTxt = getText("UI_MSM_ErrNameExists"); return
                end
            end
            errTxt = ""
        end,
    })

    ManualSave.makeLabel(parent, {
        x = PAD, y = opts.errLY, w = W - PAD * 2, h = FHS + 2,
        getText = function() return errTxt end,
        r = 0.90, g = 0.25, b = 0.22, a = 1,
    })

    local cancelW = ManualSave.textBtnW(getText("UI_MSM_Common_BtnCancel"), 70)
    ManualSave.makeButton(parent, {
        x = PAD, y = opts.btnY, w = cancelW, h = BUTH,
        label = getText("UI_MSM_Common_BtnCancel"), style = "normal",
        onClick = function()
            if opts.onCancel then opts.onCancel() end
        end,
    })
    ManualSave.makeButton(parent, {
        x = PAD + cancelW + GAP, y = opts.btnY, w = 26, h = BUTH,
        label = "?", style = "normal",
        onClick = function()
            if ManualSave.openHelpScreen then ManualSave.openHelpScreen("editmods") end
        end,
    })

    local createLbl = getText("UI_MSM_EditMods_BtnCreate")
    local createW   = math.max(180, ManualSave.textBtnW(createLbl, 160))
    ManualSave.EditModsScreen._createBtn = ManualSave.makeButton(parent, {
        x = W - PAD - createW, y = opts.btnY, w = createW, h = BUTH,
        label   = createLbl, style = "normal",
        enabled = false,
        onClick = function()
            local st2 = ManualSave.EditModsScreen._state
            if not st2 then return end
            local dirty = false
            for _, m in ipairs(st2.allMods) do
                if m.checked ~= m.inSave then dirty = true; break end
            end
            if not dirty then return end

            local newName = ManualSave.sanitize(nameTI.getValue())
            if newName == "" or newName == (st2.save.slot or "") then return end

            local ls = ManualSave.LoadScreen and ManualSave.LoadScreen._state
            if ls and ls.saves then
                local gmode = st2.save.GMODE or st2.save.gameMode
                local world = st2.save.WORLD or st2.save.world
                for _, b in ipairs(ls.saves) do
                    if b.slot == newName and (b.GMODE or b.gameMode) == gmode and (b.WORLD or b.world) == world then
                        errTxt = getText("UI_MSM_ErrNameExists"); return
                    end
                end
            end
            errTxt = ""

            local finalIds   = {}
            local finalNames = {}
            for _, m in ipairs(st2.allMods) do
                if m.checked then
                    table.insert(finalIds,   m.id)
                    table.insert(finalNames, m.name)
                end
            end
            local keptStr = table.concat(finalNames, ", ")

            if ManualSave.EditModsScreen._close then ManualSave.EditModsScreen._close() end
            ManualSave.SignalBus.send("CLONE_MODS",
                { GMODE    = st2.save.GMODE    or st2.save.gameMode,
                  WORLD    = st2.save.WORLD    or st2.save.world,
                  OLD_SLOT = st2.save.slot,
                  NEW_SLOT = newName,
                  MODS     = table.concat(finalIds, ",") },
                function(status)
                    if status ~= "OK" then return end
                    ManualSave.MetaCache.copy(
                        st2.save.GMODE or st2.save.gameMode,
                        st2.save.WORLD or st2.save.world,
                        st2.save.slot, newName, true, nil,
                        { MODS    = keptStr,
                          MOD_IDS = table.concat(finalIds, ", ") })
                    if st2.onCreated then
                        pcall(st2.onCreated, newName, keptStr, table.concat(finalIds, ", "))
                    end
                end)
        end,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/ModCloneFooter.lua loaded.")
