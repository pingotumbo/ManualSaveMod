-- UI/Base/InputNav/InputRouter.lua
-- Pure mapping from keyboard / joypad events to navigation actions.
-- Stateless utility: panel factories wire their key/joypad handlers to call
-- InputRouter.dispatch(manager, action, arg).
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, duplicate-set-field

ManualSave = ManualSave or {}
ManualSave.InputNav = ManualSave.InputNav or {}

local InputRouter = {}
ManualSave.InputNav.InputRouter = InputRouter

-- Translate a keyboard key code into a navigation direction, or nil.
local function keyToDirection(key)
    if key == Keyboard.KEY_UP    then return "up"    end
    if key == Keyboard.KEY_DOWN  then return "down"  end
    if key == Keyboard.KEY_LEFT  then return "left"  end
    if key == Keyboard.KEY_RIGHT then return "right" end
    return nil
end

-- Translate a joypad D-pad button into a navigation direction, or nil.
-- Joypad constants are defined globally by PZ; protected for safety.
local function joyToDirection(button)
    if not Joypad then return nil end
    if button == Joypad.DPadUp    then return "up"    end
    if button == Joypad.DPadDown  then return "down"  end
    if button == Joypad.DPadLeft  then return "left"  end
    if button == Joypad.DPadRight then return "right" end
    return nil
end

-- Resolve a keyboard key into an action tuple.
-- Returns (action, arg) where action ∈ "navigate" / "activate" / "cancel", or nil.
function InputRouter.keyAction(key)
    local dir = keyToDirection(key)
    if dir then return "navigate", dir end
    if key == Keyboard.KEY_RETURN or key == Keyboard.KEY_NUMPADENTER then return "activate" end
    if key == Keyboard.KEY_ESCAPE then return "cancel"   end
    if key == Keyboard.KEY_TAB    then return "navigate", "down" end
    return nil
end

-- Resolve a joypad button into an action tuple. Same return shape as keyAction.
function InputRouter.joyAction(button)
    local dir = joyToDirection(button)
    if dir then return "navigate", dir end
    if Joypad and button == Joypad.AButton then return "activate" end
    if Joypad and button == Joypad.BButton then return "cancel"   end
    return nil
end

-- Dispatch a resolved action against a FocusManager. Returns true if handled.
function InputRouter.dispatch(manager, action, arg)
    if not manager or not action then return false end
    if action == "navigate" then return manager:navigate(arg)        end
    if action == "activate" then return manager:activate()           end
    if action == "cancel"   then return manager:cancel()             end
    return false
end

-- Convenience: route a raw keyboard key through resolution + dispatch.
function InputRouter.handleKey(manager, key)
    local action, arg = InputRouter.keyAction(key)
    if not action then return false end
    return InputRouter.dispatch(manager, action, arg)
end

-- Convenience: route a raw joypad button through resolution + dispatch.
function InputRouter.handleJoy(manager, button)
    local action, arg = InputRouter.joyAction(button)
    if not action then return false end
    return InputRouter.dispatch(manager, action, arg)
end

print("[ManualSaveMod] UI/Base/InputNav/InputRouter.lua loaded.")
