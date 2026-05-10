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
    -- PZ resets self.width after addChild, so setWidth() alone is not reliable.
    local targetW = getTextManager():MeasureStringX(UIFont.Large, getText("UI_MSM_MainMenu_BtnLoad")) + 30
    local vanillaPrerender = MainScreen.prerenderBottomPanelLabel
    ms.loadManualSaveOption.prerender = function(self2)
        self2.width = math.max(self2.width, targetW)
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

    print("[ManualSaveMod] Main menu: LOAD MANUAL SAVE injected.")
end)

print("[ManualSaveMod] Hooks/MainMenuHook.lua loaded.")
