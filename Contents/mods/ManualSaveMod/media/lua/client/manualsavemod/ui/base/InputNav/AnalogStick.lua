-- UI/Base/InputNav/AnalogStick.lua
-- Right-stick continuous scroll for the currently focused widget.
--
-- Once per rendered frame we read the right analog stick (the "aiming" stick
-- in PZ terminology) on the active joypad, apply a deadzone matching vanilla
-- patterns, scale by frame duration, and dispatch the resulting pixel delta
-- to the focused widget's onAnalogScroll(dx, dy) handler. Widgets without
-- that method (buttons, toggles, ...) are skipped.
--
-- Vanilla reference: ISRichTextPanel:doRightJoystickScrolling uses
-- getJoypadAimingAxisY/X(joypadData.id) and scales by
-- UIManager.getMillisSinceLastRender(). We follow the same recipe.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

if ManualSave.IS_B41 then
    print("[ManualSaveMod] AnalogStick: skipped (B41 build).")
    return
end

local DEADZONE     = 0.20   -- matches vanilla "stick is moving" threshold
local PX_PER_FRAME = 20     -- scrolled when stick is fully tilted, per ~33ms frame

-- Find the active joypadData. PZ leaves stale entries in JoypadState.joypads
-- after the controller is disconnected or the player switches back to keyboard
-- input. Calling getJoypadAimingAxisX(staleId) in that state throws a Java
-- NullPointerException (Controller.getGUID() inside JoypadManager.checkJoypad)
-- which pcall does NOT catch — it's an uncaught Java exception during the Lua
-- callJava bridge, not a Lua error.
--
-- A joypad is treated as "active" only when:
--   - JoypadState.players has it bound to a player (in-game), OR
--   - JoypadState.getMainMenuJoypad() returns it (main menu / sub-screens).
-- Neither path returns a stale entry, so we never feed a dead id to PZ.
local function activeJoypad()
    if not JoypadState or not JoypadState.joypads then return nil end

    local bound = {}
    if JoypadState.players then
        for _, jp in pairs(JoypadState.players) do
            if jp then bound[jp] = true end
        end
    end
    if JoypadState.getMainMenuJoypad then
        local ok, mmJp = pcall(JoypadState.getMainMenuJoypad)
        if ok and mmJp then bound[mmJp] = true end
    end

    for i = 1, 4 do
        local jp = JoypadState.joypads[i]
        if jp and tonumber(jp.id) and jp.id >= 0 and bound[jp] then
            return jp
        end
    end
    return nil
end

-- Find the scroll target. Priority:
--   1. The currently focused widget if it implements onAnalogScroll.
--   2. The first visible widget in the active group that implements
--      onAnalogScroll (so the right stick still scrolls the save list when
--      keyboard focus is on a nearby button).
-- Find the scroll target. Strict rule: only the widget the user is CURRENTLY
-- focused on (mgr.current.items[mgr.current.index]) is considered. Without
-- this we used to fall back to "any group widget that exposes onAnalogScroll",
-- which made the right stick always scroll the nav list of every multi-group
-- screen (Settings/Help/Import) and never drag the floating panel. Now the
-- stick only scrolls when you've explicitly parked the focus on a scrollable.
local function findScrollTarget()
    local IN = ManualSave.InputNav
    if not IN or not IN.activeManager then return nil end
    local mgr = IN.activeManager()
    if not mgr or not mgr.current or not mgr.current.items then return nil end
    local cur = mgr.current.items[mgr.current.index]
    if cur and type(cur.onAnalogScroll) == "function" then return cur end
    return nil
end

local function onTick()
    local jp = activeJoypad()
    if not jp then return end

    local rx, ry = 0, 0
    if getJoypadAimingAxisX then
        local ok, v = pcall(getJoypadAimingAxisX, jp.id); if ok then rx = tonumber(v) or 0 end
    end
    if getJoypadAimingAxisY then
        local ok, v = pcall(getJoypadAimingAxisY, jp.id); if ok then ry = tonumber(v) or 0 end
    end
    if rx > -DEADZONE and rx < DEADZONE then rx = 0 end
    if ry > -DEADZONE and ry < DEADZONE then ry = 0 end
    if rx == 0 and ry == 0 then return end

    -- Same frame-rate-normalised step vanilla ISRichTextPanel uses.
    local dt = 33.3
    if UIManager and UIManager.getMillisSinceLastRender then
        local ok, v = pcall(UIManager.getMillisSinceLastRender, UIManager)
        if ok then dt = tonumber(v) or 33.3 end
    end
    local scale = dt / 33.3
    local dx = rx * PX_PER_FRAME * scale
    local dy = ry * PX_PER_FRAME * scale

    -- Primary: scroll a widget that exposes onAnalogScroll. Fallback: drag the
    -- active floating panel (set by Floating.lua as `mgr._dragTarget`). This
    -- way the right stick scrolls a list/text when focused there, and drags
    -- the floating window when no scroll target is available.
    local target = findScrollTarget()
    if target then
        pcall(target.onAnalogScroll, target, dx, dy)
        return
    end
    local IN  = ManualSave.InputNav
    local mgr = IN and IN.activeManager and IN.activeManager()
    local dragTarget = mgr and mgr._dragTarget
    if dragTarget and type(dragTarget.onAnalogDrag) == "function" then
        pcall(dragTarget.onAnalogDrag, dragTarget, dx, dy)
    end
end

-- OnRenderTick fires every drawn frame regardless of pause state — same hook
-- vanilla JoyPadSetup uses for joypad polling.
Events.OnRenderTick.Add(onTick)

print("[ManualSaveMod] UI/Base/InputNav/AnalogStick.lua loaded.")
