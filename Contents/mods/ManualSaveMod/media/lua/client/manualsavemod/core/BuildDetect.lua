-- Core/BuildDetect.lua
-- Detects whether the mod is running on PZ Build 41 or Build 42.
-- This file is loaded very early (alphabetically before most others) so that
-- downstream modules can read ManualSave.IS_B41 / ManualSave.IS_B42 to decide
-- whether to install B42-only features (gamepad navigation, monkey-patches,
-- crash recovery popup, ...).
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

-- Default: assume B42. We flip to B41 below only if we can confirm it.
ManualSave.IS_B41 = false
ManualSave.IS_B42 = true

pcall(function()
    local core = getCore()
    if not core or not core.getGameVersion then return end
    local v = core:getGameVersion()
    if not v then return end
    local s = tostring(v)
    -- Game version strings look like "41.78.16" / "42.18.0" / ...
    local major = s:match("^(%d+)%.")
    if major == "41" then
        ManualSave.IS_B41 = true
        ManualSave.IS_B42 = false
    end
end)

print(string.format("[ManualSaveMod] BuildDetect: IS_B41=%s IS_B42=%s",
    tostring(ManualSave.IS_B41), tostring(ManualSave.IS_B42)))

-- B41 fallback stubs for ManualSave.InputNav: widget factories across the mod
-- call register / findNavGroup / findNavManager unconditionally. The real
-- InputNav module is gamepad/keyboard-focus heavy and depends on B42 panel
-- behaviour, so on B41 we install no-op stubs here BEFORE InputNav.lua is
-- loaded. The actual InputNav files then early-return on IS_B41 and leave
-- these stubs in place. Result: every register() call across the mod becomes
-- a no-op, mouse/keyboard input falls back to vanilla PZ behaviour, and the
-- mod runs without any of the focus-ring / gamepad-nav machinery.
if ManualSave.IS_B41 then
    ManualSave.InputNav = ManualSave.InputNav or {}
    local IN = ManualSave.InputNav
    IN.keyboardActive  = false
    IN.register        = function() end
    IN.findNavGroup    = function() return nil end
    IN.findNavManager  = function() return nil end
    IN.installPanelNav = function() end
    IN.makeManager     = function() return { addGroup=function() end, onCancel=nil } end
    IN.makeGroup       = function() return { add=function() end, setFocus=function() end, focusFirst=function() end } end
    IN.pushActive      = function() end
    IN.popActive       = function() end
    IN.activeManager   = function() return nil end
    IN.handleKey       = function() end
    IN.buildManager    = function() end
    -- Plus any helper consumed by sub-modules; safe to add more as we hit them.
    print("[ManualSaveMod] BuildDetect: InputNav stubs installed (B41 mode).")
end
