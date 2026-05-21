-- UI/Base/InputNav/FocusManager.lua
-- Per-panel focus manager: tracks multiple FocusGroups and their transitions.
-- Routes directional navigation to the current group; on group exit, hands focus
-- to the next group based on declared links.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, duplicate-set-field, duplicate-doc-field

ManualSave = ManualSave or {}
ManualSave.InputNav = ManualSave.InputNav or {}

if ManualSave.IS_B41 then return end

---@class ManualSave.FocusManager
---@field groups   table   -- list of FocusGroup
---@field links    table   -- { [groupA] = { up=groupB, down=groupC, ... } }
---@field current  table?  -- the FocusGroup currently receiving input
---@field onCancel fun()?  -- called when Esc/B pressed and not handled internally

local FocusManager = {}
FocusManager.__index = FocusManager

function ManualSave.InputNav.makeManager()
    local m = setmetatable({}, FocusManager)
    m.groups  = {}
    m.links   = {}
    m.current = nil
    return m
end

-- Register a group with this manager. The first group added becomes current by default.
function FocusManager:addGroup(group)
    table.insert(self.groups, group)
    if not self.current then self.current = group end

    -- Hook the group's onExit so it routes through this manager.
    local userExit = group.onExit
    group.onExit = function(direction)
        return self:handleExit(group, direction, userExit)
    end
end

-- Declare a link between groups: when `from` exits in direction `on`, focus moves to `to`.
-- links: { { from=g1, on="up", to=g2 }, { from=g2, on="down", to=g1 }, ... }
function FocusManager:linkGroups(links)
    for _, link in ipairs(links) do
        self.links[link.from] = self.links[link.from] or {}
        self.links[link.from][link.on] = link.to
    end
end

-- Set initial focused group (e.g. open with focus on the slot list).
-- The initial focus is silent (no nav sound) since the user did not navigate.
function FocusManager:setCurrent(group)
    if self.current == group then return end
    if self.current then self.current:blurCurrent() end
    self.current = group
    group:focusFirst(true)
end

-- Internal: called when a group's navigation runs off its edge.
function FocusManager:handleExit(group, direction, userCallback)
    -- Caller-supplied exit handler takes priority and can override.
    if userCallback then
        local handled = userCallback(direction)
        if handled then return true end
    end

    local nextGroup = self.links[group] and self.links[group][direction]
    if not nextGroup then return false end
    -- Abort the transition if the target group has nothing navigable right now
    -- (e.g. action bar disabled because no save is selected). Focus stays in the
    -- original group so the user is not stranded on an invisible cursor.
    if not nextGroup:hasNavigable() then return false end

    group:blurCurrent()
    self.current = nextGroup

    -- Pick a sensible entry index based on direction:
    -- Entering from "down"/"right" -> focus first navigable item.
    -- Entering from "up"/"left"    -> focus last navigable item.
    if direction == "down" or direction == "right" then
        nextGroup:focusFirst()
    else
        nextGroup:focusLast()
    end
    return true
end

-- Route a directional navigation event (up/down/left/right) to the current group.
function FocusManager:navigate(direction)
    if not self.current then return false end
    return self.current:navigate(direction)
end

-- Activate (Enter / A) the focused widget in the current group.
function FocusManager:activate()
    if not self.current then return false end
    return self.current:activate()
end

-- Cancel (Esc / B). Returns false if no handler attached.
--
-- Priority order:
--   1. The currently focused widget may declare `onCancel(widget)` (e.g. an
--      edit-mode widget that wants Esc to exit edit rather than close the
--      screen). If it returns truthy, the cancel is consumed there.
--   2. Otherwise the manager's own onCancel runs (typically close the panel).
function FocusManager:cancel()
    if self.current then
        local w = self.current.items and self.current.items[self.current.index]
        if w and type(w.onCancel) == "function" then
            local handled
            local ok = pcall(function() handled = w.onCancel(w) end)
            if ok and handled then
                if ManualSave.InputNav and ManualSave.InputNav.playCancelSound then
                    ManualSave.InputNav.playCancelSound()
                end
                return true
            end
        end
    end
    if not self.onCancel then return false end
    pcall(self.onCancel)
    if ManualSave.InputNav and ManualSave.InputNav.playCancelSound then
        ManualSave.InputNav.playCancelSound()
    end
    return true
end

-- Focus the first focusable widget in the first group (called on panel open).
function FocusManager:focusFirst()
    if not self.current then return end
    self.current:focusFirst()
end

print("[ManualSaveMod] UI/Base/InputNav/FocusManager.lua loaded.")
