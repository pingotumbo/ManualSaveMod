-- UI/Screens/LoadScreen.lua
-- Full-screen save browser. Pure assembler — mounts base components.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, need-check-nil

ManualSave            = ManualSave or {}
ManualSave.LoadScreen = ManualSave.LoadScreen or {}

local LEFT_W = 440

function ManualSave.openLoadScreen(fromMainMenu)
    if ManualSave.LoadScreen._screen then return end

    local TH       = ManualSave.Theme
    local PW       = math.min(1100, getCore():getScreenWidth()  - 80)
    local PH       = math.min(720,  getCore():getScreenHeight() - 80)
    local titleH   = TH.FONT_HGT_LARGE + 22
    local footerH  = TH.BUTTON_HGT + TH.PAD * 2
    local contentY = titleH
    local contentH = PH - titleH - footerH
    local rightX   = LEFT_W + 1
    local rightW   = PW - rightX

    local d = ManualSave.makeScreenPanel({
        w=PW, h=PH,
        onKeyRelease = function(_, key)
            if key == Keyboard.KEY_RETURN then
                local st = ManualSave.LoadScreen._state
                if st and st.selected and not st.selected.CORRUPTED
                    and ManualSave.SignalBus.isBatAlive() ~= false then
                    local m = st.selected
                    ManualSave.closeLoadScreen()
                    ManualSave.SaveManager.load(m.GMODE or m.gameMode, m.WORLD or m.world, m.slot)
                end
            end
            if key == Keyboard.KEY_F2 then
                local st = ManualSave.LoadScreen._state
                if st and st.selected then
                    local fn = ManualSave.LoadScreen._beginRename
                    if fn then fn() end
                end
            end
        end,
    })
    ManualSave.LoadScreen._screen = d
    ManualSave.LoadScreen._p      = d.panel
    ManualSave.LoadScreen._state  = {
        saves={}, filtered={}, selected=nil, selectedThumb=nil, selectedMods={},
        sortMode="date", sortAsc=false, searchText="", fromMainMenu=fromMainMenu or false,
        fadealpha=0, renamingSlot=false,
        recoveryFlags      = { wipeZombies=false, resetPlayerPos=false,
                                healPlayer=false, resetWeather=false, resetTime=false },
        recoveryTimePreset = "dawn",
    }
    ManualSave.LoadScreen._dims = { w=PW, h=PH, titleH=titleH, footerH=footerH }

    ManualSave.UI.clearGroup("bat_required")
    ManualSave.UI.setGroupCondition("bat_required", function()
        return ManualSave.SignalBus.isBatAlive() ~= false
    end)

    local p = d.panel

    -- Title bar + Help button
    ManualSave.makeLoadHeader(p, { w=PW, h=titleH })

    -- Left column: sort toolbar + search + scrollable save list
    ManualSave.makeSaveList(p, { contentY=contentY, contentH=contentH, listW=LEFT_W })

    -- Right column: thumbnail + detail info + inline rename + action buttons
    ManualSave.makeSaveDetailPanel(p, {
        contentY=contentY, contentH=contentH,
        rightX=rightX, rightW=rightW,
        thumbH=260, actW=84,
    })

    -- Footer — all widths derived from translated text.
    local footerY = PH - TH.BUTTON_HGT - TH.PAD
    local backW   = ManualSave.textBtnW(getText("UI_MSM_Common_BtnBack"),  70)
    local importW = ManualSave.textBtnW(getText("UI_MSM_Load_BtnImport"),  80)
    local moreW   = ManualSave.textBtnW(getText("UI_MSM_Load_BtnMore"),    70)
    local loadW   = ManualSave.textBtnW(getText("UI_MSM_Load_BtnLoad"),   120)

    -- Left-side positions
    local backX   = TH.PAD
    local importX = backX + backW + TH.GAP
    -- Right-side positions
    local loadX   = PW - TH.PAD - loadW
    local moreX   = loadX - TH.GAP - moreW
    -- Info / warning zone between the two groups (uses import offset even when hidden)
    local infoX   = importX + importW + TH.GAP

    ManualSave.makeButton(p, {
        x=backX, y=footerY, w=backW, h=TH.BUTTON_HGT,
        label=getText("UI_MSM_Common_BtnBack"), style="normal",
        onClick = function() ManualSave.closeLoadScreen() end,
    })
    if fromMainMenu then
        ManualSave.makeButton(p, {
            x=importX, y=footerY, w=importW, h=TH.BUTTON_HGT,
            label=getText("UI_MSM_Load_BtnImport"), style="accent",
            groups={"bat_required"},
            onClick = function()
                if ManualSave.SignalBus.isBatAlive() == false then return end
                ManualSave.openImportScreen()
            end,
        })
    end
    ManualSave.LoadScreen._btnMore = ManualSave.makeButton(p, {
        x=moreX, y=footerY, w=moreW, h=TH.BUTTON_HGT,
        label=getText("UI_MSM_Load_BtnMore"), style="normal", enabled=false,
        onClick = function() ManualSave.openMoreScreen() end,
    })
    ManualSave.LoadScreen._btnLoad = ManualSave.makeButton(p, {
        x=loadX, y=footerY, w=loadW, h=TH.BUTTON_HGT,
        label=getText("UI_MSM_Load_BtnLoad"), style="primary", enabled=false,
        onClick = function()
            if ManualSave.SignalBus.isBatAlive() == false then return end
            local st = ManualSave.LoadScreen._state
            if not st or not st.selected or st.selected.CORRUPTED then return end
            local m = st.selected
            ManualSave.closeLoadScreen()
            ManualSave.SaveManager.load(m.GMODE or m.gameMode, m.WORLD or m.world, m.slot)
        end,
    })

    -- "?" tutorial-hook button: left of warning, shown when BAT offline
    local infoBtn = ManualSave.makeButton(p, {
        x=infoX, y=footerY, w=26, h=TH.BUTTON_HGT,
        label=getText("UI_MSM_Common_BtnHelp"), style="normal",
        onClick = function()
            if ManualSave.openHelpScreen then ManualSave.openHelpScreen("watcher") end
        end,
    })
    infoBtn.btn:setVisible(false)
    ManualSave.UI.registerElement("bat_required",
        { setEnabled = function(v) infoBtn.btn:setVisible(v) end }, true)

    -- Warning label (shown when BAT offline)
    local warnX     = infoX + 26 + TH.GAP
    local warnRight = moreX  -- left edge of More button
    local warnH     = TH.BUTTON_HGT
    local warnPanel = ManualSave.makeLabel(p, {
        x=warnX, y=footerY, w=warnRight - warnX - TH.GAP, h=warnH,
        text  = getText("UI_MSM_Common_WarnOffline"),
        textY = math.floor((warnH - TH.FONT_HGT_SMALL) / 2),
        r=TH.DANGER_R, g=TH.DANGER_G, b=TH.DANGER_B,
    })
    warnPanel:setVisible(false)
    ManualSave.UI.registerElement("bat_required",
        { setEnabled = function(v) warnPanel:setVisible(v) end }, true)

    -- Combined-condition refresh: re-evaluates More/Load/_actBtns using bat status + selection state
    ManualSave.UI.registerElement("bat_required", { setEnabled = function(v)
        local ls  = ManualSave.LoadScreen
        local st  = ls and ls._state
        local sel = st and st.selected
        if ls._btnLoad then ls._btnLoad.setEnabled(v and sel ~= nil and not sel.CORRUPTED) end
        if ls._btnMore then ls._btnMore.setEnabled(sel ~= nil) end
        if ls._actBtns then
            ls._actBtns.rename.setEnabled(v and sel ~= nil)
            ls._actBtns.clone.setEnabled(v and sel ~= nil)
            ls._actBtns.delete.setEnabled(v and sel ~= nil)
        end
    end })

    ManualSave.LoadScreen._state.saves = ManualSave.SaveManager.listSaves()
    ManualSave.LoadScreen.applyFilter()
    ManualSave.UI.evalConditions()
    if getPlayer() then setGameSpeed(0); setShowPausedMessage(false) end
    d.open()
end

function ManualSave.closeLoadScreen()
    local d = ManualSave.LoadScreen._screen
    if not d then return end
    ManualSave.UI.clearGroup("bat_required")
    local wasInGame = getPlayer() ~= nil
    ManualSave.closeMoreScreen()
    if ManualSave.closeImportScreen then ManualSave.closeImportScreen() end
    d.close()
    ManualSave.LoadScreen._screen = nil
    ManualSave.LoadScreen._state  = nil
    if wasInGame then
        setGameSpeed(1)
        setShowPausedMessage(true)
    end
end

print("[ManualSaveMod] UI/Screens/LoadScreen.lua loaded.")
