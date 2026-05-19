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
---@diagnostic disable: undefined-global, undefined-field, undefined-doc-name

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

-- Conditional widget registry (per-widget enableIf / visibleIf callbacks).
-- Used by widget factories (makeButton etc.) to auto-bind a widget's enabled
-- and visible state to a per-instance predicate, without the screen having to
-- do manual setEnabled/setVisible calls.
local _conditional = {}

---@param handle  table   widget wrapper exposing setEnabled / setVisible
---@param opts    { enableIf:fun():boolean?, visibleIf:fun():boolean? }
function ManualSave.UI.registerConditional(handle, opts)
    if not handle or not opts then return end
    if not opts.enableIf and not opts.visibleIf then return end
    table.insert(_conditional, {
        handle    = handle,
        enableIf  = opts.enableIf,
        visibleIf = opts.visibleIf,
    })
end

-- Evaluates all group conditions and applies enabled/disabled state to members,
-- then evaluates per-widget enableIf / visibleIf for conditionally-registered
-- widgets. Dead entries (where set calls fail) are pruned.
-- Called by SignalBus.poll() every ~2 s alongside the heartbeat check, and
-- manually by callers after state changes that need immediate refresh.
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

    local dead = {}
    for i, c in ipairs(_conditional) do
        local alive = true
        if c.enableIf and c.handle.setEnabled then
            local ok, v = pcall(c.enableIf)
            if ok then
                local ok2 = pcall(c.handle.setEnabled, v and true or false)
                if not ok2 then alive = false end
            end
        end
        if alive and c.visibleIf and c.handle.setVisible then
            local ok, v = pcall(c.visibleIf)
            if ok then
                local ok2 = pcall(c.handle.setVisible, v and true or false)
                if not ok2 then alive = false end
            end
        end
        if not alive then table.insert(dead, i) end
    end
    for i = #dead, 1, -1 do table.remove(_conditional, dead[i]) end
end

print("[ManualSaveMod] UI/Base/Config/Groups.lua loaded.")
