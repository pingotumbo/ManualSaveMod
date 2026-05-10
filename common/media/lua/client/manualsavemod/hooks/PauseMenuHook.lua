-- Hooks/PauseMenuHook.lua
-- Injects "SAVE GAME" and "LOAD GAME" into the in-game ESC pause menu.
-- Opens LoadPanel with fromMainMenu = false  (no IMPORT button).
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

local labelHgt       = getTextManager():getFontHeight(UIFont.Large) + 16
local labelSeparator = 16

-- Replace the original ToggleEscapeMenu event listener with a wrapper that
-- intercepts ESC while our panels are open. We must Remove+Add because
-- Events.OnKeyPressed holds the original function reference, not the global name.
local _origToggleEsc = ToggleEscapeMenu
Events.OnKeyPressed.Remove(_origToggleEsc)
local function _escWrapper(key)
    local menuKey = getCore():getKey("Main Menu")
    local isEsc   = (menuKey ~= 0 and key == menuKey) or (menuKey == 0 and key == Keyboard.KEY_ESCAPE)
    if isEsc then
        if ManualSave.LoadScreen and ManualSave.LoadScreen._screen then
            local st = ManualSave.LoadScreen._state
            if st and st.renamingSlot then
                local fn = ManualSave.LoadScreen._commitRename
                if fn then fn(false) end
            else
                ManualSave.closeLoadScreen()
            end
            return
        end
        if ManualSave._saveScreenOpen and ManualSave._saveScreenOpen() then
            ManualSave.closeSaveScreen()
            return
        end
    end
    _origToggleEsc(key)
end
ToggleEscapeMenu = _escWrapper
Events.OnKeyPressed.Add(_escWrapper)

local function onSaveGameClick(_, _, _)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    ToggleEscapeMenu(getCore():getKey("Main Menu"))
    ManualSave.openSaveScreen()
end

local function onLoadGameClick(_, _, _)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    ToggleEscapeMenu(getCore():getKey("Main Menu"))
    ManualSave.openLoadScreen(false)
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
    ms.saveGameOption = ISLabel:new(labelX, exitY, labelHgt, getText("UI_MSM_PauseMenu_BtnSave"), 1, 1, 1, 1, UIFont.Large, true)
    ms.saveGameOption.internal    = "MANUALSAVE_SAVE"
    ms.saveGameOption:initialise()
    ms.saveGameOption.onMouseDown = onSaveGameClick
    ms.saveGameOption.fade        = UITransition.new()
    ms.saveGameOption.fade:setFadeIn(false)
    -- Override prerender: enforce correct width every frame before vanilla draws the hover rect.
    local vanillaPrerender = MainScreen.prerenderBottomPanelLabel
    local saveTargetW = getTextManager():MeasureStringX(UIFont.Large, getText("UI_MSM_PauseMenu_BtnSave")) + 30
    ms.saveGameOption.prerender = function(self2)
        self2.width = math.max(self2.width, saveTargetW)
        vanillaPrerender(self2)
    end
    bp:addChild(ms.saveGameOption)

    -- "LOAD GAME" one step below
    ms.loadGameOption = ISLabel:new(labelX, exitY + shift, labelHgt, getText("UI_MSM_PauseMenu_BtnLoad"), 1, 1, 1, 1, UIFont.Large, true)
    ms.loadGameOption.internal    = "MANUALSAVE_LOAD"
    ms.loadGameOption:initialise()
    ms.loadGameOption.onMouseDown = onLoadGameClick
    ms.loadGameOption.fade        = UITransition.new()
    ms.loadGameOption.fade:setFadeIn(false)
    local loadTargetW = getTextManager():MeasureStringX(UIFont.Large, getText("UI_MSM_PauseMenu_BtnLoad")) + 30
    ms.loadGameOption.prerender = function(self2)
        self2.width = math.max(self2.width, loadTargetW)
        vanillaPrerender(self2)
    end
    bp:addChild(ms.loadGameOption)

    -- Re-normalize all ISLabel widths to match vanilla (our labels self-correct via prerender)
    local ourW = math.max(saveTargetW, loadTargetW)
    local maxW = ourW
    for _, child in pairs(bp:getChildren()) do
        if child.Type == "ISLabel" then maxW = math.max(maxW, child:getWidth()) end
    end
    for _, child in pairs(bp:getChildren()) do
        if child.Type == "ISLabel" then child:setWidth(maxW) end
    end
    bp:setWidth(maxW)

    print("[ManualSaveMod] Pause menu: SAVE GAME + LOAD GAME injected.")
end)

-- Patch vanilla CreditsScreen.onResolutionChange: self.richText is nil when
-- the Credits screen was never opened (PZ B42 bug — missing nil guard).
local _origCreditsORC = CreditsScreen.onResolutionChange
CreditsScreen.onResolutionChange = function(self)
    if self.richText then _origCreditsORC(self) end
end

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

print("[ManualSaveMod] Hooks/PauseMenuHook.lua loaded. ESC wrapper installed.")
