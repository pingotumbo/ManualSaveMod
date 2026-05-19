-- Hooks/MainMenuHook.lua
-- Injects "LOAD MANUAL SAVE" into the main menu.
-- Opens LoadPanel with fromMainMenu = true  (shows IMPORT button).
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

local labelHgt       = getTextManager():getFontHeight(UIFont.Large) + 16
local labelSeparator = 16

local function onLoadManualSaveClick(_, _, _)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    ManualSave.openLoadScreen(true)    -- main menu: show IMPORT button
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

-- Joypad / controller navigation integration.
-- PZ MainScreen builds its keyboard/joypad nav list (self.joypadButtonsY) from
-- a hardcoded set of options inside MainScreen:onGainJoypadFocus. Our injected
-- option is not in that list, so it would be skipped when navigating with the
-- controller. We monkey-patch the method to append our entry to the list right
-- before the EXIT row, so it sits in the same spot as it is rendered visually.
local _origOnGainJoypadFocus = nil
Events.OnMainMenuEnter.Add(function()
    if _origOnGainJoypadFocus then return end
    if not MainScreen or not MainScreen.onGainJoypadFocus then return end
    _origOnGainJoypadFocus = MainScreen.onGainJoypadFocus
    function MainScreen:onGainJoypadFocus(joypadData)
        _origOnGainJoypadFocus(self, joypadData)
        local opt = self.loadManualSaveOption
        if not opt then return end
        local visible = true
        pcall(function() visible = opt:isVisible() end)
        if not visible then return end
        pcall(function() opt:setJoypadFocused(false) end)
        -- Insert before EXIT so the visual order matches the nav order.
        for i, v in ipairs(self.joypadButtonsY or {}) do
            if v[1] == self.exitOption then
                table.insert(self.joypadButtonsY, i, { opt })
                return
            end
        end
        -- Fallback: append at the end if EXIT could not be found.
        table.insert(self.joypadButtonsY, { opt })
    end
end)

print("[ManualSaveMod] Hooks/MainMenuHook.lua loaded.")
