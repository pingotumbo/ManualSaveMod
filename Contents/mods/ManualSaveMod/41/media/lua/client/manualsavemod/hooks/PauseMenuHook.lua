-- Hooks/PauseMenuHook.lua
-- Injects "SAVE GAME" and "LOAD GAME" into the in-game ESC pause menu.
-- Opens LoadPanel with fromMainMenu = false  (no IMPORT button).
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

local labelHgt       = getTextManager():getFontHeight(UIFont.Large) + 16
local labelSeparator = 16

-- Replace the original ToggleEscapeMenu event listener with a wrapper that
-- intercepts ESC for our remaining special cases. We must Remove+Add because
-- Events.OnKeyPressed holds the original function reference, not the global name.
--
-- LoadScreen is now a sub-screen of MainScreen (makeScreenPanel/subScreenOf) so
-- it handles ESC itself via Screen.lua's onKeyRelease — no wrapper code needed
-- for the generic close. We only keep:
--   - LoadScreen + inline rename in progress: ESC cancels the rename instead of
--     closing the whole screen.
--   - SaveScreen still uses the old fullscreen-overlay model (to be migrated):
--     ESC must close it before falling through to vanilla ToggleEscapeMenu, or
--     the pause menu would open behind it.
local _origToggleEsc = ToggleEscapeMenu
Events.OnKeyPressed.Remove(_origToggleEsc)
local function _escWrapper(key)
    local menuKey = getCore():getKey("Main Menu")
    local isEsc   = (menuKey ~= 0 and key == menuKey) or (menuKey == 0 and key == Keyboard.KEY_ESCAPE)
    if isEsc then
        -- Joypad B sets a short-lived suppression timestamp (InputNav.lua) so
        -- the synthetic ESC that some PZ paths emit alongside B doesn't fall
        -- through here and re-toggle the vanilla pause menu after our cancel
        -- already closed a sub-screen.
        if ManualSave.InputNav and ManualSave.InputNav._suppressEscUntil and getTimestampMs then
            local ok, t = pcall(getTimestampMs)
            local nowT = ok and tonumber(t) or 0
            print(string.format("[MSM-ESC] esc seen now=%s suppress=%s diff=%s",
                tostring(nowT), tostring(ManualSave.InputNav._suppressEscUntil),
                tostring(ManualSave.InputNav._suppressEscUntil - nowT)))
            if ok and nowT > 0 and nowT <= ManualSave.InputNav._suppressEscUntil then
                print("[MSM-ESC] suppressing")
                return
            end
        end
        if ManualSave.LoadScreen and ManualSave.LoadScreen._screen then
            local st = ManualSave.LoadScreen._state
            if st and st.renamingSlot then
                local fn = ManualSave.LoadScreen._commitRename
                if fn then fn(false) end
                return
            end
            -- Otherwise let Screen.lua's onKeyRelease close it (plays sound).
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

-- joypadData (4th arg) is passed by PZ when the click originates from a
-- gamepad A-press; nil for mouse clicks. The vanilla MainScreen->Settings
-- pattern keeps the pause menu open underneath (its bottomPanel is hidden by
-- makeScreenPanel/subScreenOf) and transfers joypad focus to our screen.
-- Note: openSaveScreen doesn't accept joypadData yet — SaveScreen will be
-- migrated to the subScreenOf pattern in a follow-up step. For now we still
-- close the pause menu before opening it (vanilla-incompatible interim state).
local function onSaveGameClick(_, _, _)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    -- Capture joypadData BEFORE ToggleEscapeMenu, since closing the pause menu
    -- nulls out getMainMenuJoypad(). SaveScreen's floating panel needs it to
    -- transfer joypad focus to itself.
    local joypadData = nil
    if JoypadState and JoypadState.getMainMenuJoypad then
        joypadData = JoypadState.getMainMenuJoypad()
    end
    ToggleEscapeMenu(getCore():getKey("Main Menu"))
    ManualSave.openSaveScreen(joypadData)
end

-- Vanilla pattern (same as MainScreen entries): the A-button dispatcher
-- doesn't propagate joypadData. The handler recovers it via
-- JoypadState.getMainMenuJoypad() so that LoadScreen.open() can transfer the
-- joypad focus to the sub-screen. Without this, the pad would continue
-- driving the pause menu underneath.
local function onLoadGameClick(_, _, _)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    local joypadData = nil
    if JoypadState and JoypadState.getMainMenuJoypad then
        joypadData = JoypadState.getMainMenuJoypad()
    end
    ManualSave.openLoadScreen(false, joypadData)
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
    -- Must call setWidth() (Java object), not assign self.width (Lua property only).
    local vanillaPrerender = MainScreen.prerenderBottomPanelLabel
    local saveTargetW = getTextManager():MeasureStringX(UIFont.Large, getText("UI_MSM_PauseMenu_BtnSave")) + 30
    ms.saveGameOption.prerender = function(self2)
        self2:setWidth(math.max(self2:getWidth(), saveTargetW))
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
        self2:setWidth(math.max(self2:getWidth(), loadTargetW))
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
    -- Seed maxMenuItemWidth so PZ's render-loop normalization doesn't shrink our labels.
    ms.maxMenuItemWidth = math.max(ms.maxMenuItemWidth or 0, maxW)

    print("[ManualSaveMod] Pause menu: SAVE GAME + LOAD GAME injected.")
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Joypad navigation integration (mirror of MainMenuHook).
--
-- The in-game pause menu is the same MainScreen vanilla with `inGame=true`, so
-- it uses the same `onGainJoypadFocus` to (re)build joypadButtonsY from a
-- hardcoded list and the same `onMenuItemMouseDownMainMenu` to dispatch on
-- A-press. We wrap both to make SAVE GAME / LOAD GAME selectable by D-pad and
-- activatable by A.
--
-- Important: the wrap is shared with MainMenuHook (it patches the same
-- functions). _pauseMenuJoypadInstalled guards a double install if this file
-- ever runs through OnGameStart twice in the same session.
-- ─────────────────────────────────────────────────────────────────────────────

local _pauseMenuJoypadInstalled = false

local function installPauseMenuJoypad()
    if _pauseMenuJoypadInstalled then return end
    if not MainScreen or not MainScreen.onGainJoypadFocus then return end
    if not MainScreen.onMenuItemMouseDownMainMenu then return end
    _pauseMenuJoypadInstalled = true

    local origGainFocus = MainScreen.onGainJoypadFocus
    function MainScreen:onGainJoypadFocus(joypadData)
        origGainFocus(self, joypadData)
        local rows = self.joypadButtonsY
        if not rows then return end
        -- Collect our two labels in visual order (SAVE then LOAD).
        local toInject = {}
        if self.saveGameOption and self.saveGameOption:isVisible() then
            table.insert(toInject, self.saveGameOption)
        end
        if self.loadGameOption and self.loadGameOption:isVisible() then
            table.insert(toInject, self.loadGameOption)
        end
        if #toInject == 0 then return end
        -- Skip any already present (defensive: re-entry).
        local present = {}
        for _, row in ipairs(rows) do
            if row and row[1] then present[row[1]] = true end
        end
        -- Locate insertion point: just above EXIT, fall back to append.
        local insertAt = #rows + 1
        for i, row in ipairs(rows) do
            local el = row and row[1]
            if el and el.internal == "EXIT" then insertAt = i; break end
        end
        for _, opt in ipairs(toInject) do
            if not present[opt] then
                table.insert(rows, insertAt, { opt })
                insertAt = insertAt + 1
            end
        end
    end

    local origMouseDown = MainScreen.onMenuItemMouseDownMainMenu
    function MainScreen.onMenuItemMouseDownMainMenu(item, x, y)
        if item then
            if item.internal == "MANUALSAVE_SAVE" then
                -- Vanilla dispatch path: getMainMenuJoypad() inside the click
                -- handler retrieves the joypadData independently — no need to
                -- propagate it as an argument.
                onSaveGameClick(item, x, y)
                return
            elseif item.internal == "MANUALSAVE_LOAD" then
                onLoadGameClick(item, x, y)
                return
            end
        end
        return origMouseDown(item, x, y)
    end

    print("[ManualSaveMod] Pause menu: joypad integration installed.")
end

Events.OnGameStart.Add(installPauseMenuJoypad)

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
