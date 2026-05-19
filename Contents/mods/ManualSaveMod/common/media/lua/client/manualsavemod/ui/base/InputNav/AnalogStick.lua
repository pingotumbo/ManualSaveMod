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

local DEADZONE     = 0.20   -- matches vanilla "stick is moving" threshold
local PX_PER_FRAME = 20     -- scrolled when stick is fully tilted, per ~33ms frame

-- Find the active joypadData. We use JoypadState.joypads (the per-physical-
-- controller list, populated for every connected pad regardless of in-game /
-- main-menu state). The first slot with id >= 0 is the active controller.
local function activeJoypad()
    if not JoypadState or not JoypadState.joypads then return nil end
    for i = 1, 4 do
        local jp = JoypadState.joypads[i]
        if jp and tonumber(jp.id) and jp.id >= 0 then return jp end
    end
    return nil
end

-- Find the scroll target. Priority:
--   1. The currently focused widget if it implements onAnalogScroll.
--   2. The first visible widget in the active group that implements
--      onAnalogScroll (so the right stick still scrolls the save list when
--      keyboard focus is on a nearby button).
local function findScrollTarget()
    local IN = ManualSave.InputNav
    if not IN or not IN.activeManager then return nil end
    local mgr = IN.activeManager()
    if not mgr then return nil end
    local group = mgr.currentGroup or (mgr.groups and mgr.groups[1])
    if not group or not group.items then return nil end

    local cur = group.items[group.index]
    if cur and type(cur.onAnalogScroll) == "function" then return cur end
    for _, w in ipairs(group.items) do
        if type(w.onAnalogScroll) == "function" then
            local vis = true
            if type(w.isVisible) == "function" then
                local ok, v = pcall(w.isVisible, w); if ok then vis = v end
            end
            if vis then return w end
        end
    end
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

    local target = findScrollTarget()
    if not target then return end

    -- Same frame-rate-normalised step vanilla ISRichTextPanel uses.
    local dt = 33.3
    if UIManager and UIManager.getMillisSinceLastRender then
        local ok, v = pcall(UIManager.getMillisSinceLastRender, UIManager)
        if ok then dt = tonumber(v) or 33.3 end
    end
    local scale = dt / 33.3
    local dx = rx * PX_PER_FRAME * scale
    local dy = ry * PX_PER_FRAME * scale
    pcall(target.onAnalogScroll, target, dx, dy)
end

-- OnRenderTick fires every drawn frame regardless of pause state — same hook
-- vanilla JoyPadSetup uses for joypad polling.
Events.OnRenderTick.Add(onTick)

print("[ManualSaveMod] UI/Base/InputNav/AnalogStick.lua loaded.")
