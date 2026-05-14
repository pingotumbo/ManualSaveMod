-- UI/Base/Widgets/Sections/SaveOps.lua
-- Save action buttons (rename, duplicate, world actions, strip mods) and recovery flags UI.
-- All logic is contained within these functions; screens pass no callbacks.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, missing-return-value

ManualSave = ManualSave or {}

local sanitize = ManualSave.sanitize

-- SAVE ACTIONS + WORLD ACTIONS button group.
-- opts: { y, w, save, st }
-- Returns: height consumed
function ManualSave.makeSaveActions(parent, opts)
    local TH       = ManualSave.Theme
    local FHS      = TH.FONT_HGT_SMALL
    local btnH     = TH.BUTTON_HGT
    local w        = opts.w
    local st       = opts.st
    local halfBtnW = math.floor((w - TH.GAP) / 2)
    local ry       = opts.y

    local function sectionLbl(y, text)
        ManualSave.makeLabel(parent, {
            x=0, y=y, w=w, h=FHS + 4,
            text=text, textY=2,
            r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=0.8,
        })
        return FHS + 4
    end

    -- SAVE ACTIONS
    ry = ry + sectionLbl(ry, getText("UI_MSM_Ops_HeaderSaveActions"))
    ManualSave.makeButton(parent, {
        x=0, y=ry, w=halfBtnW, h=btnH,
        label=getText("UI_MSM_Ops_BtnRename"), style="normal",
        groups={"bat_required"},
        onClick = function()
            if ManualSave.SignalBus.isBatAlive() == false then return end
            if not st.selected then return end
            ManualSave.openNameInputDialog({
                title       = getText("UI_MSM_Ops_RenameTitle"),
                value       = st.selected.slot,
                confirm     = getText("UI_MSM_Common_BtnRename"),
                helpSection = "rename",
                onConfirm = function(newName)
                    newName = sanitize(newName)
                    if newName == "" or newName == st.selected.slot then return end
                    local old = st.selected
                    ManualSave.SaveManager.rename(old.GMODE or old.gameMode,
                        old.WORLD or old.world, old.slot, newName,
                        function(status)
                            if status == "OK" then
                                old.slot = newName
                                ManualSave.LoadScreen.applyFilter()
                                ManualSave.closeMoreScreen()
                            end
                        end)
                end,
            })
        end,
    })
    ManualSave.makeButton(parent, {
        x=halfBtnW+TH.GAP, y=ry, w=halfBtnW, h=btnH,
        label=getText("UI_MSM_Ops_BtnDuplicate"), style="normal",
        groups={"bat_required"},
        onClick = function()
            if ManualSave.SignalBus.isBatAlive() == false then return end
            if not st.selected then return end
            ManualSave.openNameInputDialog({
                title       = getText("UI_MSM_Ops_DuplicateTitle"),
                value       = ManualSave.nextCopyName(st.selected.slot, st.saves),
                confirm     = getText("UI_MSM_Ops_BtnDuplicate"),
                helpSection = "duplicate",
                onConfirm = function(newName)
                    newName = sanitize(newName)
                    if newName == "" then return end
                    local old = st.selected
                    ManualSave.SaveManager.clone(old.GMODE or old.gameMode,
                        old.WORLD or old.world, old.slot, newName,
                        function(status)
                            if status == "OK" then
                                local copy = {}
                                for k, v in pairs(old) do copy[k] = v end
                                copy.slot = newName
                                table.insert(st.saves, copy)
                                ManualSave.LoadScreen.applyFilter()
                            end
                        end)
                end,
            })
        end,
    })
    ry = ry + btnH + TH.GAP

    -- WORLD ACTIONS
    ry = ry + sectionLbl(ry, getText("UI_MSM_Ops_HeaderWorldActions"))
    local infoSz  = 20
    local waInfoY = ry + math.floor((btnH - infoSz) / 2)

    ManualSave.makeButton(parent, {
        x=0, y=ry, w=halfBtnW, h=btnH,
        label=getText("UI_MSM_Ops_BtnRenameWorld"), style="normal",
        groups={"bat_required"},
        onClick = function()
            if ManualSave.SignalBus.isBatAlive() == false then return end
            if not st.selected then return end
            local old = st.selected
            ManualSave.openNameInputDialog({
                title       = getText("UI_MSM_Ops_RenameWorldTitle"),
                value       = old.world or old.WORLD or "",
                confirm     = getText("UI_MSM_Common_BtnRename"),
                helpSection = "renameworld",
                onConfirm = function(newWorld)
                    newWorld = sanitize(newWorld)
                    local gmode    = old.GMODE or old.gameMode
                    local oldWorld = old.WORLD or old.world
                    if newWorld == "" or newWorld == oldWorld then return end
                    ManualSave.SignalBus.send("RENAME_WORLD",
                        { GMODE=gmode, OLD_WORLD=oldWorld, NEW_WORLD=newWorld },
                        function(status)
                            if status ~= "OK" then return end
                            for _, b in ipairs(st.saves) do
                                if b.world == oldWorld and (b.GMODE or b.gameMode) == gmode then
                                    ManualSave.MetaCache.move(gmode, oldWorld, newWorld, b.slot)
                                    b.world = newWorld
                                end
                            end
                            ManualSave.LoadScreen.applyFilter()
                            ManualSave.closeMoreScreen()
                        end)
                end,
            })
        end,
    })
    ManualSave.makeInfoButton(parent, {
        x=halfBtnW-infoSz-3, y=waInfoY, sz=infoSz, popW=240,
        lines = {
            { getText("UI_MSM_Ops_RenameWorldInfo1"), "normal" },
            { getText("UI_MSM_Ops_RenameWorldInfo2"), "normal" },
            { getText("UI_MSM_Ops_RenameWorldInfo3"), "normal" },
            { "",                                              },
            { getText("UI_MSM_Ops_RenameWorldInfo4"), "dim"   },
        },
    })

    local wa2X = halfBtnW + TH.GAP
    ManualSave.makeButton(parent, {
        x=wa2X, y=ry, w=halfBtnW, h=btnH,
        label=getText("UI_MSM_Ops_BtnEditMods"), style="danger",
        groups={"bat_required"},
        onClick = function()
            if ManualSave.SignalBus.isBatAlive() == false then return end
            if not st.selected then return end
            ManualSave.openEditModsScreen({
                save = st.selected,
                onCreated = function(newName, keptMods, keptIds)
                    local old  = st.selected
                    local copy = {}
                    for k, v in pairs(old) do copy[k] = v end
                    copy.slot    = newName
                    copy.MODS    = keptMods or ""
                    copy.MOD_IDS = keptIds  or ""
                    table.insert(st.saves, copy)
                    ManualSave.LoadScreen.applyFilter()
                end,
            })
        end,
    })
    ManualSave.makeInfoButton(parent, {
        x=wa2X+halfBtnW-infoSz-3, y=waInfoY, sz=infoSz, popW=240, color="danger",
        lines = {
            { getText("UI_MSM_Ops_StripModsInfo1"), "normal" },
            { getText("UI_MSM_Ops_StripModsInfo2"), "normal" },
            { "",                                            },
            { getText("UI_MSM_Ops_StripModsInfo3"), "dim"   },
            { getText("UI_MSM_Ops_StripModsInfo4"), "dim"   },
            { getText("UI_MSM_Ops_StripModsInfo5"), "dim"   },
            { getText("UI_MSM_Ops_StripModsInfo6"), "dim"   },
        },
    })
    ry = ry + btnH

    return ry - opts.y
end

-- RECOVERY FLAGS section: header, flag cards, time preset row, LOAD WITH FLAGS button.
-- opts: { y, w, save, st }
function ManualSave.makeRecoveryFlags(parent, opts)
    local TH    = ManualSave.Theme
    local FHS   = TH.FONT_HGT_SMALL
    local btnH  = TH.BUTTON_HGT
    local w     = opts.w
    local m     = opts.save
    local st    = opts.st
    local flags = st.recoveryFlags
    local ry    = opts.y

    -- Header: danger-tinted bg + border, thin danger strip at top, two text labels
    local hdrH = FHS * 2 + 14
    local hdr = ManualSave.makePanel(parent, {
        x=0, y=ry, w=w, h=hdrH,
        bg    ={ r=TH.DANGER_R*0.12, g=TH.DANGER_G*0.06, b=TH.DANGER_B*0.06, a=1 },
        border={ r=TH.DANGER_R*0.6,  g=TH.DANGER_G*0.3,  b=TH.DANGER_B*0.3,  a=1 },
    })
    ManualSave.makePanel(hdr, {
        x=0, y=0, w=w, h=2,
        bg={ r=TH.DANGER_R*0.9, g=TH.DANGER_G*0.5, b=TH.DANGER_B*0.4, a=1 }, border=false,
    })
    ManualSave.makeLabel(hdr, {
        x=12, y=4, w=w-16, h=FHS,
        text=getText("UI_MSM_Ops_HeaderRecovery"),
        r=TH.DANGER_R, g=TH.DANGER_G+0.1, b=TH.DANGER_B+0.05,
    })
    ManualSave.makeLabel(hdr, {
        x=12, y=4+FHS+3, w=w-16, h=FHS,
        text=getText("UI_MSM_Ops_RecoveryWarning"),
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.75,
    })
    ManualSave.makeButton(hdr, {
        x=w-26-4, y=math.floor((hdrH - TH.BUTTON_HGT) / 2),
        w=26, h=TH.BUTTON_HGT,
        label="?", style="normal",
        onClick = function()
            if ManualSave.openHelpScreen then ManualSave.openHelpScreen("recovery") end
        end,
    })
    ry = ry + hdrH + 2

    -- Flag cards
    local flagDefs = {
        { key="wipeZombies",    label=getText("UI_MSM_Ops_FlagWipeZombies"),    desc=getText("UI_MSM_Ops_FlagWipeZombiesDesc"),
          info = { popW=240, lines = {
              { getText("UI_MSM_Ops_FlagWipeZombiesInfo1"), "normal" },
              { getText("UI_MSM_Ops_FlagWipeZombiesInfo2"), "normal" },
              { "",                                                   },
              { getText("UI_MSM_Ops_FlagWipeZombiesInfo3"), "dim"    },
              { getText("UI_MSM_Ops_FlagWipeZombiesInfo4"), "dim"    },
              { getText("UI_MSM_Ops_FlagWipeZombiesInfo5"), "dim"    },
              { "",                                                   },
              { getText("UI_MSM_Ops_FlagWipeZombiesInfo6"), "warn"   },
          }},
        },
        { key="healPlayer",     label=getText("UI_MSM_Ops_FlagHeal"),           desc=getText("UI_MSM_Ops_FlagHealDesc"),
          info = { popW=240, lines = {
              { getText("UI_MSM_Ops_FlagHealInfo1"), "normal" },
              { getText("UI_MSM_Ops_FlagHealInfo2"), "normal" },
              { getText("UI_MSM_Ops_FlagHealInfo3"), "normal" },
          }},
        },
        { key="resetWeather",   label=getText("UI_MSM_Ops_FlagResetWeather"),   desc=getText("UI_MSM_Ops_FlagResetWeatherDesc"),
          info = { popW=260, lines = {
              { getText("UI_MSM_Ops_FlagResetWeatherInfo1"), "normal" },
              { getText("UI_MSM_Ops_FlagResetWeatherInfo2"), "normal" },
              { getText("UI_MSM_Ops_FlagResetWeatherInfo3"), "dim"    },
          }},
        },
        { key="resetTime",      label=getText("UI_MSM_Ops_FlagResetTime"),      desc=getText("UI_MSM_Ops_FlagResetTimeDesc"),
          info = { popW=248, lines = {
              { getText("UI_MSM_Ops_FlagResetTimeInfo1"), "normal" },
              { getText("UI_MSM_Ops_FlagResetTimeInfo2"), "normal" },
              { "",                                                 },
              { getText("UI_MSM_Ops_FlagResetTimeInfo3"), "dim"    },
              { getText("UI_MSM_Ops_FlagResetTimeInfo4"), "dim"    },
          }},
        },
    }
    local infoSz    = 16
    local cardH     = FHS * 2 + 12
    local presetRow = nil

    for _, fd in ipairs(flagDefs) do
        local key, label, desc = fd.key, fd.label, fd.desc
        ManualSave.makeToggleCard(parent, {
            x=0, y=ry, w=w, h=cardH,
            label    = label,
            desc     = desc,
            getValue = function() return flags[key] end,
            onToggle = function()
                flags[key] = not flags[key]
                if key == "resetTime" and presetRow then
                    presetRow:setVisible(flags.resetTime)
                end
            end,
        })
        ManualSave.makeInfoButton(parent, {
            x = w - infoSz - 3,
            y = ry + math.floor((cardH - infoSz) / 2),
            sz = infoSz,
            popW = fd.info.popW,
            lines = fd.info.lines,
        })
        ry = ry + cardH + 2

        if key == "resetTime" then
            local rowH2 = btnH + 6
            presetRow = ManualSave.makePanel(parent, {
                x=0, y=ry, w=w, h=rowH2,
                bg    ={ r=0.05, g=0.04, b=0.04, a=1 },
                border={ r=TH.LINE_R*0.4, g=TH.LINE_G*0.4, b=TH.LINE_B*0.4, a=1 },
            })
            ManualSave.makeLabel(presetRow, {
                x=10, y=math.floor((rowH2 - TH.FONT_HGT_SMALL) / 2), w=w-10, h=TH.FONT_HGT_SMALL,
                text=getText("UI_MSM_Ops_SetTime"),
                r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=0.75,
            })
            local lblW  = getTextManager():MeasureStringX(UIFont.Small, getText("UI_MSM_Ops_SetTime") .. " ") + 12
            local pbY   = math.floor((rowH2 - btnH) / 2)
            local preset = st.recoveryTimePreset or "dawn"
            ManualSave.makeToolbar(presetRow, {
                x=lblW, y=pbY, w=w - lblW, h=btnH, gap=4,
                items = {
                    { id="dawn",     label=getText("UI_MSM_Ops_TimeDawn"),     kind="toggle", group="time", active=(preset=="dawn")     },
                    { id="midday",   label=getText("UI_MSM_Ops_TimeMidday"),   kind="toggle", group="time", active=(preset=="midday")   },
                    { id="dusk",     label=getText("UI_MSM_Ops_TimeDusk"),     kind="toggle", group="time", active=(preset=="dusk")     },
                    { id="midnight", label=getText("UI_MSM_Ops_TimeMidnight"), kind="toggle", group="time", active=(preset=="midnight") },
                },
                onToggle = function(id, _) st.recoveryTimePreset = id end,
            })
            presetRow:setVisible(flags.resetTime)
            ry = ry + rowH2 + 2
        end
    end

    -- LOAD WITH FLAGS button
    ManualSave.makeButton(parent, {
        x=0, y=ry, w=w, h=btnH,
        label = getText("UI_MSM_Ops_BtnLoadWithFlags"),
        groups={"bat_required"},
        onClick = function()
            if ManualSave.SignalBus.isBatAlive() == false then return end
            local anyActive = false
            for _, v in pairs(flags) do if v then anyActive = true; break end end
            if not anyActive then return end
            local times = { dawn="06:00", midday="12:00", dusk="18:00", midnight="00:00" }
            local lines = {}
            if flags.wipeZombies    then table.insert(lines, getText("UI_MSM_Ops_FlagWipeZombies"))  end
            if flags.healPlayer     then table.insert(lines, getText("UI_MSM_Ops_FlagHeal"))         end
            if flags.resetWeather   then table.insert(lines, getText("UI_MSM_Ops_FlagResetWeather")) end
            if flags.resetTime then
                local preset = st.recoveryTimePreset or "dawn"
                table.insert(lines, getText("UI_MSM_Ops_FlagsTimeFmt", times[preset] or preset))
            end
            ManualSave.openConfirmDialog({
                title       = getText("UI_MSM_Ops_ConfirmFlags"),
                body        = table.concat(lines, "\n") .. "\n\n" .. getText("UI_MSM_Ops_FlagsConfirmSuffix"),
                confirm     = getText("UI_MSM_Dialog_BtnLoadWithFlags"),
                danger      = true,
                helpSection = "recovery",
                onConfirm = function()
                    local safe = (m.slot or ""):gsub('[\\/:*?"<>|!]', "_"):gsub("%s+", "_")
                    local active = {}
                    if flags.wipeZombies    then table.insert(active, "WIPE_ZOMBIES")     end
                    if flags.healPlayer     then table.insert(active, "HEAL_PLAYER")      end
                    if flags.resetWeather   then table.insert(active, "RESET_WEATHER")    end
                    if flags.resetTime then
                        table.insert(active, "RESET_TIME="..(st.recoveryTimePreset or "dawn"))
                    end
                    local fw = getFileWriter("ManualSaves_Flags_"..safe..".txt", true, false)
                    if fw then
                        fw:write("SLOT="  .. (m.slot or "") .. "\r\n")
                        fw:write("FLAGS=" .. table.concat(active, ",") .. "\r\n")
                        fw:close()
                    end
                    for k in pairs(flags) do flags[k] = false end
                    ManualSave.closeLoadScreen()
                    ManualSave.SaveManager.load(m.GMODE or m.gameMode, m.WORLD or m.world, m.slot)
                end,
            })
        end,
        render = function(ab)
            local anyActive = false
            for _, v in pairs(flags) do if v then anyActive = true; break end end
            local over = false; pcall(function() over = ab:isMouseOver() end)
            if anyActive then
                local bgR = over and TH.DANGER_R*0.26 or TH.DANGER_R*0.14
                local bgG = over and TH.DANGER_G*0.15 or TH.DANGER_G*0.08
                local bgB = over and TH.DANGER_B*0.14 or TH.DANGER_B*0.08
                ab:drawRect(0,0,ab.width,ab.height,1,bgR,bgG,bgB)
                ab:drawRectBorder(0,0,ab.width,ab.height,1,
                    TH.DANGER_R*0.9, TH.DANGER_G*0.5, TH.DANGER_B*0.4)
            else
                ab:drawRectBorder(0,0,ab.width,ab.height,0.5, TH.MUTED_R, TH.MUTED_G, TH.MUTED_B)
            end
            local fh = getTextManager():getFontHeight(UIFont.Small)
            local btnTxt = getText("UI_MSM_Ops_BtnLoadWithFlags")
            local tw = getTextManager():MeasureStringX(UIFont.Small, btnTxt)
            local tr = anyActive and TH.DANGER_R       or TH.MUTED_R
            local tg = anyActive and TH.DANGER_G+0.12  or TH.MUTED_G
            local tb = anyActive and TH.DANGER_B+0.08  or TH.MUTED_B
            local ta = anyActive and 1.0 or 0.6
            ab:drawText(btnTxt,
                math.floor((ab.width-tw)/2), math.floor((ab.height-fh)/2),
                tr, tg, tb, ta, UIFont.Small)
        end,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SaveOps.lua loaded.")
