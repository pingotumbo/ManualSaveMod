-- UI/Screens/SaveScreen.lua
-- In-game save panel (ESC → SAVE GAME).
-- Replaces: UI/SavePanel.lua + UI/FullSaveConfirmPanel.lua + UI/ScreenshotModeWarning.lua
--
-- Full Save: exits to main menu for a complete save (optionally re-enters).
-- Quick Save: instant copy without exiting the game.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field

ManualSave = ManualSave or {}

local W       = 360
local _screen = nil  -- open instance; nil when closed

-- ── Public API ────────────────────────────────────────────────────────────────

function ManualSave._saveScreenOpen() return _screen ~= nil end

-- Opens the save screen. No-op if already open.
function ManualSave.openSaveScreen()
    if _screen then return end

    local TH = ManualSave.Theme

    -- Compute H to fit content at any font scale (avoids overlap at 1440p+)
    local H = (TH.FONT_HGT_LARGE + 22)       -- title bar
            + TH.PAD                           -- gap below title
            + TH.FONT_HGT_SMALL + TH.GAP      -- "Save name:" label
            + TH.BUTTON_HGT + TH.GAP          -- name input
            + TH.BUTTON_HGT + TH.GAP          -- toggle row
            + TH.FONT_HGT_SMALL + 4           -- status / warning label
            + TH.BUTTON_HGT + TH.PAD          -- buttons row + bottom padding

    local d = ManualSave.makeFloatingPanel({
        w=W, h=H,
        title   = getText("UI_MSM_Save_Title"),
        onClose = function() ManualSave.closeSaveScreen() end,
    })
    local p   = d.panel
    _screen   = d

    ManualSave.UI.clearGroup("bat_required")
    ManualSave.UI.setGroupCondition("bat_required", function()
        return ManualSave.SignalBus.isBatAlive() ~= false
    end)

    local y0        = d.titleH + TH.PAD
    local isQuick   = false
    local statusMsg = nil

    -- "Save name:" label
    ManualSave.makeLabel(p, {
        x=TH.PAD, y=y0, w=W - TH.PAD*2, h=TH.FONT_HGT_SMALL,
        text=getText("UI_MSM_Save_LabelName"),
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B,
    })

    -- Name input
    local nameInput = ManualSave.makeTextInput(p, {
        x           = TH.PAD,
        y           = y0 + TH.FONT_HGT_SMALL + TH.GAP,
        w           = W - TH.PAD * 2,
        h           = TH.BUTTON_HGT,
        placeholder = getText("UI_MSM_Save_Placeholder"),
    })

    -- Quick Save toggle + "?" info button
    local toggleY = y0 + TH.FONT_HGT_SMALL + TH.GAP + TH.BUTTON_HGT + TH.GAP
    ManualSave.makeToolbar(p, {
        x = TH.PAD, y = toggleY, w = 108, h = TH.BUTTON_HGT,
        items    = { { id="quick", label=getText("UI_MSM_Save_BtnQuickSave"), kind="toggle" } },
        onToggle = function(_, active) isQuick = active end,
    })

    -- Buttons row
    local btnY = H - TH.BUTTON_HGT - TH.PAD
    local btnW = 110

    ManualSave.makeButton(p, {
        x = TH.PAD, y = btnY, w = 26, h = TH.BUTTON_HGT,
        label = "?", style = "normal",
        onClick = function()
            if ManualSave.openHelpScreen then ManualSave.openHelpScreen("quicksave") end
        end,
    })

    ManualSave.makeButton(p, {
        x = W - TH.PAD - btnW * 2 - TH.GAP,
        y = btnY, w = 80, h = TH.BUTTON_HGT,
        label = getText("UI_MSM_Common_BtnBack"), style = "normal",
        onClick = function() ManualSave.closeSaveScreen() end,
    })

    -- Save button — label stays in sync with isQuick via update
    ManualSave.makeButton(p, {
        x = W - TH.PAD - btnW,
        y = btnY, w = btnW, h = TH.BUTTON_HGT,
        label = getText("UI_MSM_Save_BtnFullSave"), style = "primary",
        groups = {"bat_required"},
        update = function(self2) self2:setTitle(isQuick and getText("UI_MSM_Save_BtnQuickSave") or getText("UI_MSM_Save_BtnFullSave")) end,
        onClick = function()
            if ManualSave.SignalBus.isBatAlive() == false then return end
            local name = ManualSave.sanitize(nameInput.getValue())
            if name == "" then
                statusMsg = getText("UI_MSM_Save_ErrNoName")
                return
            end
            statusMsg = nil

            if isQuick then
                ManualSave.closeSaveScreen()
                ManualSave.SaveManager.quickSave(name)
            else
                ManualSave.openFullSaveDialog({
                    onExit   = function()
                        ManualSave.closeSaveScreen()
                        ManualSave.SaveManager.fullSave(name, false)
                    end,
                    onReturn = function()
                        ManualSave.closeSaveScreen()
                        ManualSave.SaveManager.fullSave(name, true)
                    end,
                })
            end
        end,
    })

    -- Warning handle: shown when bat_required group condition is false (BAT offline)
    local _batWarn = false
    ManualSave.UI.registerElement("bat_required",
        { setEnabled = function(v) _batWarn = v end }, true)

    -- Info button: Quick Save explanation
    local infoSz = 20
    local infoX  = TH.PAD + 108 + TH.GAP + 6
    local infoY  = toggleY + math.floor((TH.BUTTON_HGT - infoSz) / 2)
    ManualSave.makeInfoButton(p, {
        x = infoX, y = infoY, sz = infoSz, popW = 292,
        lines = {
            { getText("UI_MSM_Save_InfoLine1"),        "normal" },
            { getText("UI_MSM_Save_InfoLine2"),        "normal" },
            { "",                                               },
            { getText("UI_MSM_Save_InfoWhatSaved"),    "header" },
            { getText("UI_MSM_Save_InfoWhatSavedBody"),"dim"    },
            { "",                                               },
            { getText("UI_MSM_Save_InfoWhatNot"),      "warn"   },
            { getText("UI_MSM_Save_InfoZombies"),      "dim"    },
            { getText("UI_MSM_Save_InfoZombiesWarn1"), "warn"   },
            { getText("UI_MSM_Save_InfoZombiesWarn2"), "warn"   },
            { getText("UI_MSM_Save_InfoChunks"),       "dim"    },
            { getText("UI_MSM_Save_InfoWeather"),      "dim"    },
            { "",                                               },
            { getText("UI_MSM_Save_InfoUseFullSave"),  "normal" },
        },
    })

    -- Status message (validation error or bat-offline warning)
    ManualSave.makeLabel(p, {
        x=TH.PAD, y=btnY - TH.FONT_HGT_SMALL - 4, w=W - TH.PAD*2, h=TH.FONT_HGT_SMALL,
        getText = function()
            return statusMsg or (_batWarn and getText("UI_MSM_Save_WarnOffline")) or ""
        end,
        r=TH.DANGER_R, g=TH.DANGER_G, b=TH.DANGER_B,
    })

    ManualSave.UI.evalConditions()
    if getPlayer() then
        setGameSpeed(0)
        setShowPausedMessage(false)
    end

    d.open()
end

-- Closes the save screen if open and resumes the game.
function ManualSave.closeSaveScreen()
    if not _screen then return end
    ManualSave.UI.clearGroup("bat_required")
    local d = _screen
    _screen = nil
    d.close()
    if getPlayer() then
        setGameSpeed(1)
        setShowPausedMessage(true)
    end
end

print("[ManualSaveMod] UI/Screens/SaveScreen.lua loaded.")
