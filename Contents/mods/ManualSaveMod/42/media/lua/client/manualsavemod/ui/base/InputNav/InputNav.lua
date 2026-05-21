-- UI/Base/InputNav/InputNav.lua
-- Public facade for the focus / input-navigation system.
-- Sub-modules (FocusGroup, FocusManager, InputRouter) attach themselves to
-- ManualSave.InputNav directly. This file adds high-level convenience helpers
-- that screens and panel factories use, and a `register` shortcut for widgets.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, duplicate-set-field

ManualSave = ManualSave or {}
ManualSave.InputNav = ManualSave.InputNav or {}

-- B41: BuildDetect.lua has already installed no-op stubs for everything
-- this module would have defined. Don't override them with the real
-- gamepad/keyboard-focus implementation; the rest of the mod just sees
-- inert register/findNavGroup/... calls and falls back to mouse-only PZ
-- behaviour.
if ManualSave.IS_B41 then
    print("[ManualSaveMod] InputNav: skipped (B41 build).")
    return
end

-- Register a widget into a focus group. No-op if either argument is missing
-- (so widget factories can safely call this with an optional opts.focusGroup).
function ManualSave.InputNav.register(widget, group)
    if not widget or not group then return end
    group:add(widget)
end

-- Walk up an ISUIElement's parent chain looking for a panel that owns an
-- _inputNavGroup. Returns the nearest group, or nil if none found.
-- Used by widget factories to auto-register themselves into the closest panel's
-- navigation list without the caller having to pass focusGroup explicitly.
function ManualSave.InputNav.findNavGroup(elem)
    local guard = 0
    while elem and guard < 64 do
        if elem._inputNavGroup then return elem._inputNavGroup end
        elem = elem.parent
        guard = guard + 1
    end
    return nil
end

-- Walk up the parent chain looking for an _inputNav (FocusManager). Used by
-- cover panels that want to override the surrounding screen's onCancel while
-- still letting their child widgets register into the screen's nav group.
function ManualSave.InputNav.findNavManager(elem)
    local guard = 0
    while elem and guard < 64 do
        if elem._inputNav then return elem._inputNav end
        elem = elem.parent
        guard = guard + 1
    end
    return nil
end

-- Install a default FocusManager + horizontal mainGroup on a panel object
-- returned by makeScreenPanel / makeModalPanel / makeFloatingPanel / makePopupPanel.
-- The nav is pushed onto the active stack when obj.open() runs and popped from
-- the first onClose handler. The inner panel stores `_inputNavGroup` so child
-- widgets created later can auto-discover and register into it.
--
-- opts: { id?, layout?, wrap? }   - forwarded to makeGroup
function ManualSave.InputNav.installPanelNav(innerPanel, obj, opts)
    if not innerPanel or not obj then return end
    opts = opts or {}
    local nav   = ManualSave.InputNav.makeManager()
    local group = ManualSave.InputNav.makeGroup({
        id     = opts.id     or "panelNav",
        layout = opts.layout or "horizontal",
        wrap   = (opts.wrap ~= false),
    })
    nav:addGroup(group)
    nav.onCancel = function() obj.close() end

    innerPanel._inputNav      = nav
    innerPanel._inputNavGroup = group

    local origOpen = obj.open
    obj.open = function(...)
        -- Drain any deferred registrations (widgets that must sit at the END of
        -- the tab order, e.g. floating panels' X button). They are added at open
        -- time so they land after all content widgets created by the caller.
        if innerPanel._inputNavDeferred then
            for _, w in ipairs(innerPanel._inputNavDeferred) do group:add(w) end
            innerPanel._inputNavDeferred = nil
        end
        ManualSave.InputNav.pushActive(nav)
        -- Forward all caller-supplied args (e.g. joypadData for sub-screens).
        if origOpen then origOpen(...) end
    end

    -- Helper exposed on the inner panel so callers (panel factories) can request
    -- a "tail" registration without knowing about the deferred list shape.
    innerPanel._inputNavRegisterAtEnd = function(widget)
        if not widget then return end
        innerPanel._inputNavDeferred = innerPanel._inputNavDeferred or {}
        table.insert(innerPanel._inputNavDeferred, widget)
    end

    -- Gamepad routing: ISUIElement-derived panels receive joypad events via
    -- onJoypadDir*/onJoypadDown methods. We install handlers that forward to
    -- handleKey with the equivalent keyboard code so the rest of the system
    -- works unchanged. Requires PZ to consider this panel the joypad-focus
    -- target (joypadFocused flag set below).
    innerPanel.joypadFocused = true
    innerPanel.onJoypadDirUp    = function() ManualSave.InputNav.handleKey(Keyboard.KEY_UP)    end
    innerPanel.onJoypadDirDown  = function() ManualSave.InputNav.handleKey(Keyboard.KEY_DOWN)  end
    innerPanel.onJoypadDirLeft  = function() ManualSave.InputNav.handleKey(Keyboard.KEY_LEFT)  end
    innerPanel.onJoypadDirRight = function() ManualSave.InputNav.handleKey(Keyboard.KEY_RIGHT) end
    innerPanel.onJoypadDown = function(_, button)
        if not Joypad then return end
        if button == Joypad.AButton then
            ManualSave.InputNav.handleKey(Keyboard.KEY_RETURN)
        elseif button == Joypad.BButton then
            -- Joypad B is mapped to "cancel" by us. Some PZ contexts ALSO
            -- forward joypad B as a synthetic OnKeyPressed(ESC) that would
            -- then reach PauseMenuHook's _escWrapper and re-toggle the
            -- vanilla pause menu. Stamp a guard so the wrapper can ignore
            -- the next ESC for a short window.
            if getTimestampMs then
                local ok, t = pcall(getTimestampMs)
                if ok then ManualSave.InputNav._suppressEscUntil = (tonumber(t) or 0) + 200 end
            end
            ManualSave.InputNav.handleKey(Keyboard.KEY_ESCAPE)
        -- L1/R1 floating rotator: shelved until we hit a use case with
        -- multiple floating panels open at the same time, and until the
        -- bumper events actually reach this handler (PZ may not forward L/R
        -- bumpers to non-ISPanelJoypad receivers — to verify).
        end
    end

    -- Pop is registered as an onClose callback so it fires alongside (and before)
    -- any caller-supplied onClose handlers.
    obj.onClose(function() ManualSave.InputNav.popActive(nav) end)

    return nav, group
end

-- Build a FocusManager with multiple groups and their cross-group links in one call.
-- groupDefs: list of group constructor opts { { id="...", layout="...", wrap=?, onExit=? }, ... }
-- links:     list of { from=<groupIndex>, on=<"up"|"down"|"left"|"right">, to=<groupIndex> }
-- Returns the manager and the ordered list of groups.
function ManualSave.InputNav.buildManager(groupDefs, links)
    local manager = ManualSave.InputNav.makeManager()
    local groups  = {}
    for _, def in ipairs(groupDefs or {}) do
        local g = ManualSave.InputNav.makeGroup(def)
        manager:addGroup(g)
        table.insert(groups, g)
    end
    local resolvedLinks = {}
    for _, link in ipairs(links or {}) do
        local f = groups[link.from]
        local t = groups[link.to]
        if f and t then
            table.insert(resolvedLinks, { from = f, on = link.on, to = t })
        end
    end
    manager:linkGroups(resolvedLinks)
    return manager, groups
end

-- Active manager stack. The topmost manager receives keyboard / joypad events.
-- Screens push their manager on open, pop on close. Nested modals push their own
-- manager on top, automatically isolating input from the underlying screen.
local activeStack = {}

function ManualSave.InputNav.pushActive(manager)
    if not manager then return end
    table.insert(activeStack, manager)
end

function ManualSave.InputNav.popActive(manager)
    for i = #activeStack, 1, -1 do
        if activeStack[i] == manager then
            table.remove(activeStack, i)
            return
        end
    end
end

function ManualSave.InputNav.activeManager()
    return activeStack[#activeStack]
end

-- Rotate the activeStack so a different floating-panel manager becomes the
-- top. direction = +1 brings the NEXT floating manager to the top (wrap
-- around), direction = -1 brings the PREVIOUS one. Non-floating screens
-- (sub-screens of MainScreen, in-game screens without _isFloating) stay in
-- place and are skipped during rotation. Called by L1/R1 bumpers.
function ManualSave.InputNav.rotateFloatingFocus(direction)
    -- Build the indices of floating managers in stack order.
    local floats = {}
    for i, m in ipairs(activeStack) do
        if m._isFloating then table.insert(floats, i) end
    end
    if #floats < 2 then return end          -- nothing to rotate

    -- The "current" floating is the highest-indexed floating in the stack.
    -- If a non-floating screen sits on top of it that's fine — rotation only
    -- reorders floats among themselves and bringToTop handles the visual order.
    local topIdx = floats[#floats]
    local n      = #floats
    local curPos
    for pos, si in ipairs(floats) do
        if si == topIdx then curPos = pos; break end
    end
    if not curPos then return end

    local newPos = ((curPos - 1 + direction) % n) + 1
    local newTopStackIdx = floats[newPos]
    if newTopStackIdx == #activeStack then return end  -- same one

    -- Move the chosen floating manager to the top of the stack. Preserve the
    -- order of non-floating screens in between.
    local mgrToTop = activeStack[newTopStackIdx]
    table.remove(activeStack, newTopStackIdx)
    table.insert(activeStack, mgrToTop)

    -- Bring the panel visually to the top too if we can find it.
    if mgrToTop._dragTarget and mgrToTop._dragTarget.bringToTop then
        pcall(function() mgrToTop._dragTarget:bringToTop() end)
    end

    ManualSave.InputNav.setKeyboardActive(true)
    if ManualSave.InputNav.playNavSound then
        pcall(ManualSave.InputNav.playNavSound)
    end
end

-- ── Keyboard / mouse mode ─────────────────────────────────────────────────────
-- Focus rings are only drawn when keyboardActive == true. The mode starts off,
-- flips ON when a navigation key (arrows / Enter / Esc / Tab) is pressed, and
-- flips OFF when the user touches the mouse (click or movement past a small
-- threshold). Widgets check ManualSave.InputNav.keyboardActive in their render.
ManualSave.InputNav.keyboardActive = false

local mouseSnapshotX, mouseSnapshotY = 0, 0
local lastMouseDown                  = false

local function snapshotMouse()
    pcall(function()
        mouseSnapshotX = tonumber(getMouseX()) or 0
        mouseSnapshotY = tonumber(getMouseY()) or 0
    end)
end

function ManualSave.InputNav.setKeyboardActive(active)
    ManualSave.InputNav.keyboardActive = active and true or false
    if active then snapshotMouse() end
end

-- Per-frame poll: deactivate keyboard mode on mouse click or movement > 5px.
local function pollMouseActivity()
    if not ManualSave.InputNav.keyboardActive then return end
    local mx, my = 0, 0
    pcall(function()
        mx = tonumber(getMouseX()) or 0
        my = tonumber(getMouseY()) or 0
    end)
    local sx = tonumber(mouseSnapshotX) or 0
    local sy = tonumber(mouseSnapshotY) or 0
    local dx = math.abs(mx - sx)
    local dy = math.abs(my - sy)
    if dx > 5 or dy > 5 then
        ManualSave.InputNav.keyboardActive = false
        return
    end
    local down = false
    pcall(function() down = isMouseButtonDown(0) or isMouseButtonDown(1) end)
    local justPressed = down and not lastMouseDown
    lastMouseDown = down
    if justPressed then ManualSave.InputNav.keyboardActive = false end
end

Events.OnPostUIDraw.Add(pollMouseActivity)

-- ── Sounds ────────────────────────────────────────────────────────────────────
-- Use sound IDs known to exist in PZ; "UIActivateMainMenuItem" is already used by
-- this mod (PauseMenuHook) and is guaranteed to play.
function ManualSave.InputNav.playNavSound()
    pcall(function() getSoundManager():playUISound("UIActivateMainMenuItem") end)
end

function ManualSave.InputNav.playActivateSound()
    pcall(function() getSoundManager():playUISound("UIActivateButton") end)
end

function ManualSave.InputNav.playCancelSound()
    pcall(function() getSoundManager():playUISound("UIActivateMainMenuItem") end)
end

-- ── Text input capture ────────────────────────────────────────────────────────
-- TextInputs increment this counter when they take typing focus and decrement
-- when they lose it. While > 0, the global key handler:
--   - lets arrow keys / letter keys reach the text input (cursor + typing)
--   - lets Enter reach the text input only (no double-fire to nav)
--   - intercepts Esc to release typing focus WITHOUT closing the screen
--   - intercepts Tab to release typing focus AND move nav forward
ManualSave.InputNav._textCaptureCount   = 0
ManualSave.InputNav._currentTextRelease = nil  -- fn called by Esc/Tab to unfocus

function ManualSave.InputNav.beginTextCapture(releaseFn)
    ManualSave.InputNav._textCaptureCount = ManualSave.InputNav._textCaptureCount + 1
    if releaseFn then ManualSave.InputNav._currentTextRelease = releaseFn end
end

function ManualSave.InputNav.endTextCapture()
    local n = ManualSave.InputNav._textCaptureCount - 1
    if n < 0 then n = 0 end
    ManualSave.InputNav._textCaptureCount = n
    if n == 0 then ManualSave.InputNav._currentTextRelease = nil end
end

-- ── Global key dispatch ───────────────────────────────────────────────────────
-- Routes navigation key presses to the topmost active manager. Only navigation
-- keys (arrows / Enter / Esc / Tab) activate keyboard mode; typing letters in a
-- text input does not flip the mode.
--
-- When a TextInput is currently capturing typing input, arrow keys are passed
-- through (so the text cursor can move) and only Tab / Enter / Esc still go to
-- the navigation manager.
--
-- Exposed on the namespace so other modules (e.g. KeyRepeat) can re-fire the
-- same dispatch path for held-key auto-repeat.
function ManualSave.InputNav.handleKey(key)
    local IR = ManualSave.InputNav.InputRouter
    local action, arg = IR.keyAction(key)
    if not action then return end

    if ManualSave.InputNav._textCaptureCount > 0 then
        local release = ManualSave.InputNav._currentTextRelease
        if key == Keyboard.KEY_ESCAPE then
            if release then pcall(release) end
            return
        end
        if key == Keyboard.KEY_UP or key == Keyboard.KEY_DOWN then
            if release then pcall(release) end
        elseif key == Keyboard.KEY_TAB then
            if release then pcall(release) end
        elseif key == Keyboard.KEY_RETURN or key == Keyboard.KEY_NUMPADENTER then
            return
        else
            return
        end
    end

    ManualSave.InputNav.setKeyboardActive(true)
    local manager = activeStack[#activeStack]
    if not manager then return end
    IR.dispatch(manager, action, arg)
end

Events.OnKeyPressed.Add(function(key) ManualSave.InputNav.handleKey(key) end)

print("[ManualSaveMod] UI/Base/InputNav/InputNav.lua loaded.")
