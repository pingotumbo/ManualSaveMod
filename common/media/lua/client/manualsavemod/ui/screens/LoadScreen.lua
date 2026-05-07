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
            if key == Keyboard.KEY_ESCAPE then
                local st = ManualSave.LoadScreen._state
                if st and st.renamingSlot then
                    local fn = ManualSave.LoadScreen._commitRename
                    if fn then fn(false) end
                    return
                end
                ManualSave.closeLoadScreen()
            end
            if key == Keyboard.KEY_RETURN then
                local st = ManualSave.LoadScreen._state
                if st and st.selected and not st.selected.CORRUPTED
                    and ManualSave.SignalBus.isBatAlive() ~= false then
                    local m = st.selected
                    ManualSave.closeLoadScreen(true)
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

    -- Footer
    local footerY = PH - TH.BUTTON_HGT - TH.PAD
    ManualSave.makeButton(p, {
        x=TH.PAD, y=footerY, w=90, h=TH.BUTTON_HGT,
        label="Back", style="normal",
        onClick = function() ManualSave.closeLoadScreen() end,
    })
    if fromMainMenu then
        ManualSave.makeButton(p, {
            x=TH.PAD + 90 + TH.GAP, y=footerY, w=100, h=TH.BUTTON_HGT,
            label="Import", style="accent",
            groups={"bat_required"},
            onClick = function()
                if ManualSave.SignalBus.isBatAlive() == false then return end
                ManualSave.openImportScreen()
            end,
        })
    end
    ManualSave.LoadScreen._btnMore = ManualSave.makeButton(p, {
        x=PW - TH.PAD - 100 - TH.GAP - 160, y=footerY, w=100, h=TH.BUTTON_HGT,
        label="More", style="normal", enabled=false,
        onClick = function() ManualSave.openMoreScreen() end,
    })
    ManualSave.LoadScreen._btnLoad = ManualSave.makeButton(p, {
        x=PW - TH.PAD - 160, y=footerY, w=160, h=TH.BUTTON_HGT,
        label="LOAD SAVE", style="primary", enabled=false,
        onClick = function()
            if ManualSave.SignalBus.isBatAlive() == false then return end
            local st = ManualSave.LoadScreen._state
            if not st or not st.selected or st.selected.CORRUPTED then return end
            local m = st.selected
            ManualSave.closeLoadScreen(true)
            ManualSave.SaveManager.load(m.GMODE or m.gameMode, m.WORLD or m.world, m.slot)
        end,
    })

    -- "?" tutorial-hook button: left of warning, shown when BAT offline
    local infoX   = TH.PAD + 90 + TH.GAP + 100 + TH.GAP
    local infoBtn = ManualSave.makeButton(p, {
        x=infoX, y=footerY, w=26, h=TH.BUTTON_HGT,
        label="?", style="normal",
        onClick = function()
            if ManualSave.openHelpScreen then ManualSave.openHelpScreen("watcher") end
        end,
    })
    infoBtn.btn:setVisible(false)
    ManualSave.UI.registerElement("bat_required",
        { setEnabled = function(v) infoBtn.btn:setVisible(v) end }, true)

    -- Warning label (shown when BAT offline)
    local warnX     = infoX + 26 + TH.GAP
    local warnRight = PW - TH.PAD - 100 - TH.GAP - 160  -- left edge of More button
    local warnH     = TH.BUTTON_HGT
    local warnPanel = ManualSave.makeLabel(p, {
        x=warnX, y=footerY, w=warnRight - warnX - TH.GAP, h=warnH,
        text  = "Watcher offline - operations disabled.",
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

-- skipEscMenu: pass true when closing to perform a load (avoids reopening the ESC menu
-- which would stall the load until the user presses ESC again).
function ManualSave.closeLoadScreen(skipEscMenu)
    local d = ManualSave.LoadScreen._screen
    if not d then return end
    ManualSave.UI.clearGroup("bat_required")
    local wasInGame    = getPlayer() ~= nil
    local fromMainMenu = ManualSave.LoadScreen._state and ManualSave.LoadScreen._state.fromMainMenu
    ManualSave.closeMoreScreen()
    if ManualSave.closeImportScreen then ManualSave.closeImportScreen() end
    d.close()
    ManualSave.LoadScreen._screen = nil
    ManualSave.LoadScreen._state  = nil
    if wasInGame then
        setGameSpeed(1)
        setShowPausedMessage(true)
        if not fromMainMenu and not skipEscMenu then
            pcall(function() ToggleEscapeMenu(getCore():getKey("Main Menu")) end)
        end
    end
end

print("[ManualSaveMod] UI/Screens/LoadScreen.lua loaded.")
