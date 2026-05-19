-- Hooks/MainMenuHook.lua
-- Injects "LOAD MANUAL SAVE" into the main menu.
-- Opens LoadPanel with fromMainMenu = true  (shows IMPORT button).
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

local labelHgt       = getTextManager():getFontHeight(UIFont.Large) + 16
local labelSeparator = 16

-- Vanilla pattern: A-button on a main menu entry invokes
-- onMenuItemMouseDownMainMenu(item, 0, 0) WITHOUT passing joypadData. The
-- handler then retrieves it independently via JoypadState.getMainMenuJoypad()
-- and forwards it to setVisible(true, joypadData). We mirror that here so the
-- gamepad focus is transferred to LoadScreen on A-press from the main menu.
local function onLoadManualSaveClick(_, _, _)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    local joypadData = nil
    if JoypadState and JoypadState.getMainMenuJoypad then
        joypadData = JoypadState.getMainMenuJoypad()
    end
    ManualSave.openLoadScreen(true, joypadData)
end

Events.OnMainMenuEnter.Add(function()
    ManualSave.SaveManager.checkReenter()
end)

Events.OnMainMenuEnter.Add(function()
    local ms = MainScreen.instance
    if not ms then return end
    if ms.loadManualSaveInjected then return end
    ms.loadManualSaveInjected = true

    local bp = ms.bottomPanel
    if not bp then return end

    local labelX = ms.exitOption:getX()
    local exitY  = ms.exitOption:getY()
    local shift  = labelHgt + labelSeparator

    -- Shift EXIT and QUIT_TO_DESKTOP down by 1 label
    ms.exitOption:setY(exitY + shift)
    if ms.quitToDesktop then
        ms.quitToDesktop:setY(ms.exitOption:getBottom() + labelSeparator)
        bp:setHeight(ms.quitToDesktop:getBottom())
    else
        bp:setHeight(ms.exitOption:getBottom())
    end

    -- "LOAD MANUAL SAVE" at old exitY
    ms.loadManualSaveOption = ISLabel:new(labelX, exitY, labelHgt, getText("UI_MSM_MainMenu_BtnLoad"), 1, 1, 1, 1, UIFont.Large, true)
    ms.loadManualSaveOption.internal    = "MANUALSAVE_LOADMANUALSAVE"
    ms.loadManualSaveOption:initialise()
    ms.loadManualSaveOption.onMouseDown = onLoadManualSaveClick
    ms.loadManualSaveOption.fade        = UITransition.new()
    ms.loadManualSaveOption.fade:setFadeIn(false)
    -- Override prerender: enforce correct width every frame before vanilla draws the hover rect.
    -- Must call setWidth() (Java object), not assign self.width (Lua property only).
    local targetW = getTextManager():MeasureStringX(UIFont.Large, getText("UI_MSM_MainMenu_BtnLoad")) + 30
    local vanillaPrerender = MainScreen.prerenderBottomPanelLabel
    ms.loadManualSaveOption.prerender = function(self2)
        self2:setWidth(math.max(self2:getWidth(), targetW))
        vanillaPrerender(self2)
    end
    bp:addChild(ms.loadManualSaveOption)

    -- Re-normalize all ISLabel widths to match vanilla (our label self-corrects via prerender)
    local maxW = targetW
    for _, child in pairs(bp:getChildren()) do
        if child.Type == "ISLabel" then maxW = math.max(maxW, child:getWidth()) end
    end
    for _, child in pairs(bp:getChildren()) do
        if child.Type == "ISLabel" then child:setWidth(maxW) end
    end
    bp:setWidth(maxW)
    -- Seed maxMenuItemWidth so PZ's render-loop normalization doesn't shrink our label.
    ms.maxMenuItemWidth = math.max(ms.maxMenuItemWidth or 0, maxW)

    print("[ManualSaveMod] Main menu: LOAD MANUAL SAVE injected.")
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Joypad navigation integration
--
-- Vanilla MainScreen rebuilds self.joypadButtonsY from a hardcoded list every
-- time onGainJoypadFocus runs, so the label has to be re-injected on each call
-- rather than once at construction. The list is a list of single-element
-- TABLES — { { uiElement }, ... } — and PZ later indexes both rows and columns
-- (children[joypadIndex]). Previous attempts crashed by inserting the bare
-- element instead of a one-element row table.
--
-- Activation on A-button goes through MainScreen.onMenuItemMouseDownMainMenu,
-- which branches on item.internal. Unknown internals are a no-op there, so we
-- wrap that function too and handle our id before delegating to vanilla.
-- ─────────────────────────────────────────────────────────────────────────────

local _joypadIntegrationInstalled = false

local function installJoypadIntegration()
    if _joypadIntegrationInstalled then return end
    if not MainScreen or not MainScreen.onGainJoypadFocus then return end
    if not MainScreen.onMenuItemMouseDownMainMenu then return end
    _joypadIntegrationInstalled = true

    local origGainFocus = MainScreen.onGainJoypadFocus
    function MainScreen:onGainJoypadFocus(joypadData)
        origGainFocus(self, joypadData)
        local opt = self.loadManualSaveOption
        if not opt or not opt:isVisible() then return end
        local rows = self.joypadButtonsY
        if not rows then return end
        -- Skip if already present (defensive: re-entry, refocus, etc.).
        for _, row in ipairs(rows) do
            if row and row[1] == opt then return end
        end
        -- Find EXIT row and insert ours just above it. Falls back to append.
        local insertAt = #rows + 1
        for i, row in ipairs(rows) do
            local el = row and row[1]
            if el and el.internal == "EXIT" then
                insertAt = i
                break
            end
        end
        table.insert(rows, insertAt, { opt })
    end

    local origMouseDown = MainScreen.onMenuItemMouseDownMainMenu
    function MainScreen.onMenuItemMouseDownMainMenu(item, x, y)
        if item and item.internal == "MANUALSAVE_LOADMANUALSAVE" then
            -- Vanilla's handler pulls joypadData via JoypadState.getMainMenuJoypad()
            -- from inside the click body — we do the same in onLoadManualSaveClick.
            onLoadManualSaveClick(item, x, y)
            return
        end
        return origMouseDown(item, x, y)
    end

    print("[ManualSaveMod] Main menu: joypad integration installed.")
end

Events.OnMainMenuEnter.Add(installJoypadIntegration)

print("[ManualSaveMod] Hooks/MainMenuHook.lua loaded.")
