-- UI/Base/InputNav/KeyBindings.lua
-- PZ global keybindings: register them in Options > Key Bindings, listen to
-- OnKeyPressed, and dispatch to registered action callbacks.
-- This is independent from the focus navigation in FocusManager — these are
-- global shortcuts that work anywhere in-game (Open Save, Quick Save, etc.).
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, duplicate-set-field

ManualSave = ManualSave or {}
ManualSave.KeyBindings = ManualSave.KeyBindings or {}

-- Bindings declared here register into PZ's global `keyBinding` table at boot.
-- defaultKey = 0 means no default binding (user must bind manually in Options).
local BINDINGS = {
    { id = "open_save",   name = "[Manual Save] Open Save Screen", defaultKey = Keyboard.KEY_F5 },
    { id = "open_load",   name = "[Manual Save] Open Load Screen", defaultKey = Keyboard.KEY_F9 },
    { id = "quick_save",  name = "[Manual Save] Quick Save",       defaultKey = Keyboard.KEY_F6 },
    { id = "toggle_hud",  name = "[Manual Save] Toggle HUD",       defaultKey = 0              },
}

-- Map of id -> callback. Populated by callers via KeyBindings.on(id, fn).
local actions = {}

-- Register a callback for a binding. Pass nil to unregister.
function ManualSave.KeyBindings.on(id, callback)
    actions[id] = callback
end

-- Lookup the current key code bound to a given action id.
function ManualSave.KeyBindings.getKey(id)
    for _, b in ipairs(BINDINGS) do
        if b.id == id then return getCore():getKey(b.name) end
    end
    return 0
end

-- Called once at game boot: insert our bindings into PZ's keyBinding table.
local function registerBindings()
    if not keyBinding then return end
    -- Category header (PZ convention: entries with no key act as section labels).
    table.insert(keyBinding, { value = "[Manual Save]" })
    for _, b in ipairs(BINDINGS) do
        table.insert(keyBinding, { value = b.name, key = b.defaultKey })
    end
end

-- Called on every key press: find which binding matches and dispatch.
local function onKeyPressed(key)
    if not key or key == 0 then return end
    for _, b in ipairs(BINDINGS) do
        local bound = getCore():getKey(b.name)
        if bound ~= 0 and key == bound then
            local cb = actions[b.id]
            if cb then pcall(cb) end
            return
        end
    end
end

Events.OnGameBoot.Add(registerBindings)
Events.OnKeyPressed.Add(onKeyPressed)

print("[ManualSaveMod] UI/Base/InputNav/KeyBindings.lua loaded.")
