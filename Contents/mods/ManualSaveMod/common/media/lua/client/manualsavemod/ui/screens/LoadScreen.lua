-- UI/Screens/LoadScreen.lua
-- Full-screen save browser. Pure assembler — mounts base components.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, need-check-nil

ManualSave            = ManualSave or {}
ManualSave.LoadScreen = ManualSave.LoadScreen or {}

local LEFT_W = 440

function ManualSave.openLoadScreen(fromMainMenu, joypadData)
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
        subScreenOf = "mainScreen",
        onKeyRelease = function(_, key)
            local ls = ManualSave.LoadScreen
            local st = ls and ls._state
            if not st or not st.selected then return end
            -- Selection-bound shortcuts. Only fire while LoadScreen is open
            -- (this handler is on the LoadScreen panel itself, so it never
            -- runs in normal gameplay) and while no inline edit / popup is
            -- consuming text input.
            if st.renamingSlot then return end
            local alive = ManualSave.SignalBus.isBatAlive() ~= false
            -- Enter: Load the selected save (only when launched from main menu;
            -- in-game Enter is reserved for vanilla chat / other PZ flows).
            if key == Keyboard.KEY_RETURN and st.fromMainMenu then
                if not st.selected.CORRUPTED and alive then
                    ls.confirmLoad(st.selected)
                end
                return
            end
            -- F2: rename inline.
            if key == Keyboard.KEY_F2 then
                if alive and ls._beginRename then ls._beginRename() end
                return
            end
            -- Delete: confirm delete.
            if key == Keyboard.KEY_DELETE then
                if alive and ls._doDelete then ls._doDelete() end
                return
            end
            -- Ctrl+D: duplicate.
            if key == Keyboard.KEY_D
                and (isKeyDown(Keyboard.KEY_LCONTROL) or isKeyDown(Keyboard.KEY_RCONTROL)) then
                if alive and ls._doClone then ls._doClone() end
                return
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
        return ManualSave.SignalBus.isBatAlive() ~= false and not ManualSave._progressActive
    end)

    local p = d.panel

    -- InputNav is created automatically by makeScreenPanel. Access the auto-built
    -- group via p._inputNavGroup; every makeButton / makeToolbar / makeScrollList /
    -- makeTextInput called below with `p` as the parent will walk up the parent
    -- chain and register itself into this group automatically.
    ManualSave.LoadScreen._mainGroup = p._inputNavGroup

    -- Title bar + Help button
    ManualSave.makeLoadHeader(p, { w=PW, h=titleH })

    -- Left column: sort toolbar + search + scrollable save list (all auto-register)
    ManualSave.makeSaveList(p, { contentY=contentY, contentH=contentH, listW=LEFT_W })

    -- Right column: thumbnail + detail info + inline rename + action buttons
    ManualSave.makeSaveDetailPanel(p, {
        contentY=contentY, contentH=contentH,
        rightX=rightX, rightW=rightW,
        thumbH=260, actW=84,
    })

    -- Footer — all widths derived from translated text.
    local footerY    = PH - TH.BUTTON_HGT - TH.PAD
    local backW      = ManualSave.textBtnW(getText("UI_MSM_Common_BtnBack"),     70)
    local importW    = ManualSave.textBtnW(getText("UI_MSM_Load_BtnImport"),     80)
    local settingsW  = ManualSave.textBtnW(getText("UI_MSM_Common_BtnSettings"), 60)
    local moreW      = ManualSave.textBtnW(getText("UI_MSM_Load_BtnMore"),       70)
    local loadW      = ManualSave.textBtnW(getText("UI_MSM_Load_BtnLoad"),      120)

    -- Left-side positions
    local backX     = TH.PAD
    local importX   = backX + backW + TH.GAP
    local settingsX = importX + (fromMainMenu and importW + TH.GAP or 0)
    -- Right-side positions
    local loadX     = PW - TH.PAD - loadW
    local moreX     = loadX - TH.GAP - moreW
    -- Info / warning zone between settings button and More button
    local infoX     = settingsX + settingsW + TH.GAP

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
    ManualSave.makeButton(p, {
        x=settingsX, y=footerY, w=settingsW, h=TH.BUTTON_HGT,
        label=getText("UI_MSM_Common_BtnSettings"), style="normal",
        onClick = function() ManualSave.openSettingsScreen() end,
    })
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
            ManualSave.LoadScreen.confirmLoad(st.selected)
        end,
    })

    -- "?" tutorial-hook button: shown only when the watcher is offline (with
    -- the warning surfaced) or while a save is in progress. visibleIf binds
    -- this to the live state automatically — no need for screen-side setVisible
    -- calls in updateWarnArea, and the button is skipped in keyboard nav while
    -- hidden (isNavigable checks isVisible).
    ManualSave.LoadScreen._infoBtn = ManualSave.makeButton(p, {
        x=infoX, y=footerY, w=26, h=TH.BUTTON_HGT,
        label=getText("UI_MSM_Common_BtnHelp"), style="normal",
        visibleIf = function()
            local busy       = ManualSave._progressActive == true
            local offline    = ManualSave.SignalBus.isBatAlive() == false
            local warnHidden = ManualSave.Config.get("SHOW_WATCHER_WARN") == "0"
            return busy or (offline and not warnHidden)
        end,
        onClick = function()
            if ManualSave.openHelpScreen then
                local section = ManualSave._progressActive and "savebusy" or "watcher"
                ManualSave.openHelpScreen(section)
            end
        end,
    })

    -- Warning label: text and visibility set by updateWarnArea()
    local warnX     = infoX + 26 + TH.GAP
    local warnRight = moreX
    local warnH     = TH.BUTTON_HGT
    ManualSave.LoadScreen._warnLabel = ManualSave.makeLabel(p, {
        x=warnX, y=footerY, w=warnRight - warnX - TH.GAP, h=warnH,
        textY = math.floor((warnH - TH.FONT_HGT_SMALL) / 2),
        r=TH.DANGER_R, g=TH.DANGER_G, b=TH.DANGER_B,
    })
    ManualSave.LoadScreen._warnLabel.setVisible(false)

    -- Unified handler: button states and warn area, all from one call
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
        ManualSave.LoadScreen.updateWarnArea()
    end })

    d.onClose(function()
        if not ManualSave.LoadScreen._screen then return end
        local wasInGame = getPlayer() ~= nil
        ManualSave.LoadScreen._screen    = nil
        ManualSave.LoadScreen._state     = nil
        ManualSave.LoadScreen._infoBtn   = nil
        ManualSave.LoadScreen._warnLabel = nil
        ManualSave.LoadScreen._mainGroup = nil
        ManualSave.UI.clearGroup("bat_required")
        ManualSave.closeMoreScreen()
        if ManualSave.closeImportScreen  then ManualSave.closeImportScreen()  end
        if ManualSave.closeHelpScreen    then ManualSave.closeHelpScreen()    end
        if ManualSave.closeSettingsScreen then ManualSave.closeSettingsScreen() end
        -- Only resume time if we're truly returning to gameplay. When LoadScreen
        -- was opened from the in-game pause menu, MainScreen (the vanilla pause
        -- UI) is still visible below us; closing LoadScreen should put us back
        -- on the pause menu, not unfreeze time. Vanilla MainScreen handles its
        -- own setGameSpeed(0) while it's visible.
        if wasInGame then
            local pauseMenuVisible = false
            pcall(function()
                pauseMenuVisible = MainScreen and MainScreen.instance
                    and MainScreen.instance:isVisible() and MainScreen.instance.inGame
            end)
            if not pauseMenuVisible then
                setGameSpeed(1)
                setShowPausedMessage(true)
            end
        end
    end)

    ManualSave.LoadScreen._state.saves = ManualSave.SaveManager.listSaves()
    ManualSave.LoadScreen.applyFilter()
    ManualSave.UI.evalConditions()
    if getPlayer() then setGameSpeed(0); setShowPausedMessage(false) end
    d.open(joypadData)

    -- "What's New" popup: only from the main menu, only until the user ticks
    -- "Don't show again" (Config SHOW_PATCH_NOTES). No-op in-game.
    if fromMainMenu and ManualSave.maybeShowPatchNotes then
        ManualSave.maybeShowPatchNotes()
    end
end

-- Updates the warning label state. The "?" button's visibility is handled
-- automatically by its visibleIf binding; here we only update the label's
-- visible state + text (no visibleIf since label rendering depends on text
-- which is itself driven by the same condition).
function ManualSave.LoadScreen.updateWarnArea()
    local ls = ManualSave.LoadScreen
    if not ls._screen or not ls._warnLabel then return end
    local offline    = ManualSave.SignalBus.isBatAlive() == false
    local busy       = ManualSave._progressActive == true
    -- v1.6.1: a signal is in flight (DELETE/CLONE/LOAD/...) but the HUD has
    -- already completed its Done flash and closed, so _progressActive is
    -- false; without this distinction the warning row flips to "Watcher
    -- offline" between the HUD closing and the watcher writing the index
    -- update, which is misleading and locks the user out of obvious actions.
    local pending    = ManualSave.SignalBus.isPending and ManualSave.SignalBus.isPending() == true
    local warnHidden = ManualSave.Config.get("SHOW_WATCHER_WARN") == "0"
    local show       = busy or pending or (offline and not warnHidden)
    ls._warnLabel.setVisible(show)
    local label
    if busy then
        label = "UI_MSM_Common_WarnBusy"
    elseif pending then
        label = "UI_MSM_Common_WarnProcessing"
    else
        label = "UI_MSM_Common_WarnOffline"
    end
    ls._warnLabel.setText(getText(label))
end

-- Shows a confirmation dialog before loading. Closes LoadScreen on confirm.
-- m must have GMODE/gameMode, WORLD/world, slot fields.
function ManualSave.LoadScreen.confirmLoad(m)
    local function doLoad()
        ManualSave.closeLoadScreen()
        ManualSave.SaveManager.load(m.GMODE or m.gameMode, m.WORLD or m.world, m.slot)
    end
    if ManualSave.Config.get("CONFIRM_LOAD") == "0" then
        doLoad()
        return
    end
    local fromMainMenu = ManualSave.LoadScreen._state and ManualSave.LoadScreen._state.fromMainMenu
    local bodyKey  = fromMainMenu and "UI_MSM_Load_ConfirmBodyMainMenu" or "UI_MSM_Load_ConfirmBodyInGame"
    local bodyText = getText(bodyKey)
    local body     = '"' .. ManualSave.slotDisplay(m.slot) .. '"'
    if bodyText ~= "" then body = body .. "\n" .. bodyText end
    ManualSave.openConfirmDialog({
        title   = getText("UI_MSM_Load_ConfirmTitle"),
        body    = body,
        confirm = getText("UI_MSM_Load_BtnLoad"),
        danger  = true,
        onConfirm = doLoad,
    })
end

function ManualSave.closeLoadScreen()
    local d = ManualSave.LoadScreen._screen
    if not d then return end
    d.close()
end

print("[ManualSaveMod] UI/Screens/LoadScreen.lua loaded.")
