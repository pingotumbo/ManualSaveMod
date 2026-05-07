-- Hooks/PauseMenuHook.lua
-- Injects "SAVE GAME" and "LOAD GAME" into the in-game ESC pause menu.
-- Opens LoadPanel with fromMainMenu = false  (no IMPORT button).
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

local labelHgt       = getTextManager():getFontHeight(UIFont.Large) + 16
local labelSeparator = 16

local function onSaveGameClick(_, _, _)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    ToggleEscapeMenu(getCore():getKey("Main Menu"))
    ManualSave.openSaveScreen()
end

local function onLoadGameClick(_, _, _)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    ToggleEscapeMenu(getCore():getKey("Main Menu"))
    -- Defer by one frame so ToggleEscapeMenu fully settles before we add to UIManager
    local handler
    handler = function()
        Events.OnPreUIDraw.Remove(handler)
        ManualSave.openLoadScreen(false)   -- in-game: no IMPORT button
    end
    Events.OnPreUIDraw.Add(handler)
end

Events.OnGameStart.Add(function()
    local ms = MainScreen.instance
    if not ms then
        print("[ManualSaveMod] WARNING: MainScreen.instance not found")
        return
    end
    if ms.manualSaveInjected then return end
    ms.manualSaveInjected = true

    local bp     = ms.bottomPanel
    local labelX = ms.exitOption:getX()
    local exitY  = ms.exitOption:getY()
    local shift  = labelHgt + labelSeparator

    -- Shift EXIT and QUIT_TO_DESKTOP down by 2 labels
    ms.exitOption:setY(exitY + shift * 2)
    if ms.quitToDesktop then
        ms.quitToDesktop:setY(ms.exitOption:getBottom() + labelSeparator)
        bp:setHeight(ms.quitToDesktop:getBottom())
    else
        bp:setHeight(ms.exitOption:getBottom())
    end

    -- "SAVE GAME" at old exitY
    ms.saveGameOption = ISLabel:new(labelX, exitY, labelHgt, "SAVE GAME", 1, 1, 1, 1, UIFont.Large, true)
    ms.saveGameOption.internal    = "MANUALSAVE_SAVE"
    ms.saveGameOption:initialise()
    ms.saveGameOption.onMouseDown = onSaveGameClick
    ms.saveGameOption.fade        = UITransition.new()
    ms.saveGameOption.fade:setFadeIn(false)
    ms.saveGameOption.prerender   = MainScreen.prerenderBottomPanelLabel
    bp:addChild(ms.saveGameOption)

    -- "LOAD GAME" one step below
    ms.loadGameOption = ISLabel:new(labelX, exitY + shift, labelHgt, "LOAD GAME", 1, 1, 1, 1, UIFont.Large, true)
    ms.loadGameOption.internal    = "MANUALSAVE_LOAD"
    ms.loadGameOption:initialise()
    ms.loadGameOption.onMouseDown = onLoadGameClick
    ms.loadGameOption.fade        = UITransition.new()
    ms.loadGameOption.fade:setFadeIn(false)
    ms.loadGameOption.prerender   = MainScreen.prerenderBottomPanelLabel
    bp:addChild(ms.loadGameOption)

    -- Re-normalize all ISLabel widths to match vanilla
    local maxW = 0
    for _, child in pairs(bp:getChildren()) do
        if child.Type == "ISLabel" then maxW = math.max(maxW, child:getWidth()) end
    end
    for _, child in pairs(bp:getChildren()) do
        if child.Type == "ISLabel" then child:setWidth(maxW) end
    end
    bp:setWidth(maxW)

    print("[ManualSaveMod] Pause menu: SAVE GAME + LOAD GAME injected.")
end)

-- Close all open mod panels when the player changes screen resolution.
-- The panels are sized at construction time; a resolution change leaves them
-- stale. Closing them is instant and safe — the user simply reopens them.
Events.OnResolutionChange.Add(function()
    pcall(function() if ManualSave.closeMoreScreen   then ManualSave.closeMoreScreen()   end end)
    pcall(function() if ManualSave.closeImportScreen then ManualSave.closeImportScreen() end end)
    pcall(function() if ManualSave.closeHelpScreen   then ManualSave.closeHelpScreen()   end end)
    pcall(function() if ManualSave.closeLoadScreen   then ManualSave.closeLoadScreen()   end end)
    pcall(function() if ManualSave.closeSaveScreen   then ManualSave.closeSaveScreen()   end end)
end)

print("[ManualSaveMod] Hooks/PauseMenuHook.lua loaded.")
