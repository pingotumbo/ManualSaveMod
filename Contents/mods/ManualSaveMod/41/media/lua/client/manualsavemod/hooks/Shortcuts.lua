-- Hooks/Shortcuts.lua
-- Global keyboard shortcuts for the mod.
--
-- Each shortcut reads its key from the user's Config so the binding can be
-- changed from the Settings screen. The shortcut only fires when the player
-- is in-game (we don't want the main-menu navigation key to accidentally
-- open SaveScreen, and SaveScreen doesn't make sense outside of gameplay).
--
-- Active shortcuts:
--   SHORTCUT_QUICK_SAVE (default "K")  -> ManualSave.openSaveScreen()
--   SHORTCUT_QUICK_LOAD (default "F9") -> ManualSave.openLoadScreen(false)
--
-- The Config value is the string name of a Keyboard.KEY_* constant suffix
-- (e.g. "K", "F9", "TAB"). Empty string disables the shortcut.
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

-- Map "K" / "F9" / "TAB" / ... → numeric key code via Keyboard.KEY_* lookup.
-- Unknown / empty strings return nil so the shortcut is treated as disabled.
local function configToKeyCode(s)
    if not s or s == "" then return nil end
    local key = "KEY_" .. tostring(s):upper()
    local code = Keyboard and Keyboard[key]
    if type(code) == "number" then return code end
    return nil
end

-- Returns true when the player is actively in the world (not on the main menu
-- nor during initial load). We use getPlayer() as the canonical "in-game" test.
local function isInGame()
    local ok, p = pcall(getPlayer)
    return ok and p ~= nil
end

-- Returns true if any of OUR screens is already open. We don't want a shortcut
-- to re-trigger when the user is already inside the corresponding panel — that
-- would, for example, close-and-reopen the SaveScreen on every K press.
local function anyModScreenOpen()
    if ManualSave.LoadScreen and ManualSave.LoadScreen._screen   then return true end
    if ManualSave._saveScreenOpen and ManualSave._saveScreenOpen() then return true end
    return false
end

local function onKeyPressed(key)
    if not isInGame() then return end
    if anyModScreenOpen() then return end

    -- Skip while the player is typing into a text field (chat, custom UI etc.).
    -- ISChat exposes "focused" when the chat panel is in typing mode.
    if ISChat and ISChat.instance and ISChat.instance.focused then return end

    local quickSave = configToKeyCode(ManualSave.Config and ManualSave.Config.get("SHORTCUT_QUICK_SAVE"))
    local quickLoad = configToKeyCode(ManualSave.Config and ManualSave.Config.get("SHORTCUT_QUICK_LOAD"))

    if quickSave and key == quickSave then
        if ManualSave.openSaveScreen then ManualSave.openSaveScreen() end
        return
    end
    if quickLoad and key == quickLoad then
        if ManualSave.openLoadScreen then ManualSave.openLoadScreen(false) end
        return
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

print("[ManualSaveMod] Hooks/Shortcuts.lua loaded.")
