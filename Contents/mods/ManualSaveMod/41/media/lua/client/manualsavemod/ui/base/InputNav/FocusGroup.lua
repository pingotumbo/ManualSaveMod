-- UI/Base/InputNav/FocusGroup.lua
-- A navigable zone of focusable widgets sharing a layout (horizontal/vertical/grid).
-- Widgets register into the group; the group tracks current focus and exposes prev/next.
-- When navigation runs off the edge, an "exit" callback can hand off to another group.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, duplicate-set-field, duplicate-doc-field

ManualSave = ManualSave or {}
ManualSave.InputNav = ManualSave.InputNav or {}

---@class ManualSave.FocusGroup
---@field id        string
---@field layout    "horizontal"|"vertical"|"grid"
---@field items     table   -- ordered list of widgets
---@field index     number  -- 1-based current focus index, 0 = nothing focused
---@field onExit    fun(direction:string)?  -- "up"|"down"|"left"|"right" when nav runs off edge
---@field wrap      boolean -- whether navigation wraps around inside the group

local FocusGroup = {}
FocusGroup.__index = FocusGroup

-- Create a new focus group.
-- opts: { id, layout?, wrap?, onExit? }
--   layout: "vertical" (default) | "horizontal" | "grid"
--   wrap:   true to cycle inside the group when reaching the edge (default false)
--   onExit: called with direction string when nav exits the group; return true if handled
function ManualSave.InputNav.makeGroup(opts)
    opts = opts or {}
    local g = setmetatable({}, FocusGroup)
    g.id     = opts.id     or "group"
    g.layout = opts.layout or "vertical"
    g.items  = {}
    g.index  = 0
    g.wrap   = opts.wrap   or false
    g.onExit = opts.onExit
    return g
end

-- Add a widget to this group. Widgets gain `.isFocused` (set by group) and optional
-- `.onFocus()` / `.onBlur()` callbacks that the group will invoke on focus changes.
function FocusGroup:add(widget)
    if not widget then return end
    widget.isFocused = false
    widget._focusGroup = self
    table.insert(self.items, widget)
end

-- Remove a widget from this group (e.g. when destroyed).
function FocusGroup:remove(widget)
    for i, w in ipairs(self.items) do
        if w == widget then
            if self.index == i then self:blurCurrent() end
            table.remove(self.items, i)
            if self.index > i then self.index = self.index - 1 end
            widget._focusGroup = nil
            return
        end
    end
end

function FocusGroup:count() return #self.items end

function FocusGroup:current()
    return self.items[self.index]
end

-- Returns true if the widget is currently navigable.
-- Skips widgets that are explicitly opted out, disabled, OR hidden anywhere up
-- the parent chain (a widget inside a hidden container is effectively invisible
-- even if its own isVisible() reports true).
local function isWidgetVisibleInTree(widget)
    local w = widget
    local guard = 0
    while w and guard < 64 do
        if type(w.isVisible) == "function" then
            local ok, vis = pcall(w.isVisible, w)
            if ok and vis == false then return false end
        end
        w = w.parent
        guard = guard + 1
    end
    return true
end

local function isNavigable(widget)
    if not widget then return false end
    if widget.isFocusable == false then return false end
    if widget.enable     == false then return false end
    if widget.enabled    == false then return false end
    if not isWidgetVisibleInTree(widget) then return false end
    return true
end

-- Blur the currently focused widget (if any).
function FocusGroup:blurCurrent()
    local w = self.items[self.index]
    if w then
        w.isFocused = false
        if w.onBlur then pcall(w.onBlur, w) end
    end
end

-- Focus the widget at index `i` (1-based). Pass 0 to clear focus.
-- silent=true suppresses the navigation sound (used for initial / programmatic focus).
function FocusGroup:setIndex(i, silent)
    if i == self.index then return end
    self:blurCurrent()
    if i < 0 or i > #self.items then i = 0 end
    self.index = i
    local w = self.items[i]
    if w then
        w.isFocused = true
        if w.onFocus then pcall(w.onFocus, w) end
        if not silent and ManualSave.InputNav and ManualSave.InputNav.playNavSound then
            ManualSave.InputNav.playNavSound()
        end
    end
end

-- Focus a specific widget (must already be in this group).
function FocusGroup:setFocus(widget, silent)
    for i, w in ipairs(self.items) do
        if w == widget then self:setIndex(i, silent); return end
    end
end

-- Returns true if at least one widget in the group is currently navigable.
function FocusGroup:hasNavigable()
    for _, w in ipairs(self.items) do
        if isNavigable(w) then return true end
    end
    return false
end

-- Focus the first navigable widget (skips disabled). No-op if none are navigable.
function FocusGroup:focusFirst(silent)
    for i, w in ipairs(self.items) do
        if isNavigable(w) then self:setIndex(i, silent); return end
    end
end

-- Focus the last navigable widget (skips disabled). No-op if none are navigable.
function FocusGroup:focusLast(silent)
    for i = #self.items, 1, -1 do
        if isNavigable(self.items[i]) then self:setIndex(i, silent); return end
    end
end

-- Move focus by `delta` (positive or negative), skipping non-navigable widgets
-- (disabled buttons, etc.). Returns true if focus stayed inside the group,
-- false if it ran off the edge (caller may invoke onExit).
function FocusGroup:move(delta)
    if #self.items == 0 then return false end
    local step = (delta >= 0) and 1 or -1
    local newIndex = (self.index == 0) and (step > 0 and 1 or #self.items) or self.index + step

    -- Walk through indices in `step` direction skipping disabled widgets.
    -- Bail out if we run off the edge (unless wrap is enabled, in which case
    -- we cycle once; if a full cycle finds nothing navigable, give up).
    local safety = #self.items
    while safety > 0 do
        if newIndex < 1 then
            if self.wrap then newIndex = #self.items else return false end
        elseif newIndex > #self.items then
            if self.wrap then newIndex = 1 else return false end
        end
        if isNavigable(self.items[newIndex]) then
            self:setIndex(newIndex)
            return true
        end
        newIndex = newIndex + step
        safety = safety - 1
    end
    return false
end

-- Directional navigation. Returns true if handled inside the group.
-- Behaviour order:
--   1. Currently-focused widget may declare `onArrow(direction)` to handle the
--      key internally (e.g. a scroll list moving its own selection up/down).
--      If it returns truthy, navigation stops here.
--   2. Otherwise the group's layout determines movement:
--      - "vertical"   layout: up/down = prev/next, left/right exits.
--      - "horizontal" layout: left/right = prev/next, up/down exits.
--      - "grid"       layout: all four directions linear (TODO: 2D).
--   3. If movement runs off the edge, onExit is invoked (used by FocusManager
--      to hand focus to a linked sibling group).
function FocusGroup:navigate(direction)
    local current = self.items[self.index]
    if current and current.onArrow then
        local handled
        local ok = pcall(function() handled = current.onArrow(current, direction) end)
        if ok and handled then return true end
    end

    local inside = false
    if self.layout == "vertical" then
        if direction == "up"   then inside = self:move(-1)
        elseif direction == "down" then inside = self:move(1)
        end
    elseif self.layout == "horizontal" then
        if direction == "left"  then inside = self:move(-1)
        elseif direction == "right" then inside = self:move(1)
        end
    elseif self.layout == "grid" then
        if direction == "up" or direction == "left"   then inside = self:move(-1)
        elseif direction == "down" or direction == "right" then inside = self:move(1)
        end
    end

    if not inside and self.onExit then
        local handled = self.onExit(direction)
        return handled and true or false
    end
    return inside
end

-- Activate (Enter / A button) the currently focused widget.
-- Resolution order (live click handler wins):
--   1. widget.onclick(widget.target, widget)   — PZ ISButton's live mouse click
--      handler; callers may replace this after creation (e.g. MoreScreen swaps
--      the More button to act as Back). Using it guarantees keyboard Enter
--      always matches the current mouse-click behaviour.
--   2. widget.onActivate(widget)               — custom activate for non-buttons
--      (e.g. ScrollList panel uses this to fire its activateSelected helper).
-- Refuses to fire on widgets that became non-navigable (hidden / disabled) since
-- focus landed on them — prevents activating offscreen rename/clone/delete when
-- MoreScreen has covered them.
-- Plays the activation sound on success.
function FocusGroup:activate()
    local w = self.items[self.index]
    if not w then return false end
    if not isNavigable(w) then return false end
    local fired = false
    if type(w.onclick) == "function" then
        pcall(w.onclick, w.target or w, w)
        fired = true
    elseif type(w.onActivate) == "function" then
        pcall(w.onActivate, w)
        fired = true
    end
    if fired and ManualSave.InputNav and ManualSave.InputNav.playActivateSound then
        ManualSave.InputNav.playActivateSound()
    end
    return fired
end

print("[ManualSaveMod] UI/Base/InputNav/FocusGroup.lua loaded.")
