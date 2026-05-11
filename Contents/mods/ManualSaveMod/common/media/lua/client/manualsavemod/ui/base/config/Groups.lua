-- UI/Base/Config/Groups.lua
-- Universal group registry for UI elements.
-- Elements register to named groups; a single setGroupCondition call drives
-- enable/disable for the whole group reactively (evaluated every ~2 s by SignalBus poll).
--
-- Usage:
--   ManualSave.UI.setGroupCondition("bat_required", fn)
--   ManualSave.UI.registerElement("bat_required", handle)           -- disabled when condition false
--   ManualSave.UI.registerElement("bat_required", handle, true)     -- enabled  when condition false (invert)
--   ManualSave.UI.clearGroup("bat_required")                        -- call when screen closes
--   ManualSave.UI.evalConditions()                                  -- called by SignalBus poll
---@diagnostic disable: undefined-global

ManualSave    = ManualSave or {}
ManualSave.UI = ManualSave.UI or {}

local _groups = {}  -- name → { condition:fun?(), members:{ handle, invert }[] }

-- Registers a UI element handle into a group.
-- handle must expose setEnabled(bool).
-- invert=true means the element is enabled when the group condition is FALSE.
---@param groupName string
---@param handle    { setEnabled: fun(v:boolean) }
---@param invert    boolean?
function ManualSave.UI.registerElement(groupName, handle, invert)
    if not _groups[groupName] then
        _groups[groupName] = { condition = nil, members = {} }
    end
    table.insert(_groups[groupName].members, { handle = handle, invert = invert or false })
end

-- Sets the condition function for a group.
-- condition() should return true (group enabled) or false (group disabled).
-- nil return is treated as true (unknown → optimistic).
---@param groupName  string
---@param conditionFn fun():boolean?
function ManualSave.UI.setGroupCondition(groupName, conditionFn)
    if not _groups[groupName] then
        _groups[groupName] = { condition = nil, members = {} }
    end
    _groups[groupName].condition = conditionFn
end

-- Removes all members and condition for a group.
-- Call this when the screen that owns the group closes.
---@param groupName string
function ManualSave.UI.clearGroup(groupName)
    _groups[groupName] = nil
end

-- Evaluates all group conditions and applies enabled/disabled state to members.
-- Called by SignalBus.poll() every ~2 s alongside the heartbeat check.
function ManualSave.UI.evalConditions()
    for _, group in pairs(_groups) do
        if group.condition then
            local result  = group.condition()
            local enabled = result ~= false  -- nil → true (optimistic / unknown)
            for _, m in ipairs(group.members) do
                if m.handle and m.handle.setEnabled then
                    pcall(m.handle.setEnabled, m.invert ~= enabled)
                end
            end
        end
    end
end

print("[ManualSaveMod] UI/Base/Config/Groups.lua loaded.")
