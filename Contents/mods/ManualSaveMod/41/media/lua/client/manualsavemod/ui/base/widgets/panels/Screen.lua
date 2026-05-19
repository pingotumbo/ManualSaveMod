-- UI/Base/Panels/Screen.lua
-- Fixed full-screen docked panel (like PZ's own settings screens).
-- No title bar, no drag, no X button. Closed via Back button or ESC.
-- The dark full-screen backdrop is internal — callers work with obj.panel (inner).
--
-- Sub-screen mode (opts.subScreenOf == "mainScreen"):
--   Replicates vanilla MainOptions transition: instead of a dark fullscreen
--   overlay, the panel hides MainScreen.instance.bottomPanel (the menu items)
--   and takes the joypad focus, so it looks like a native sub-screen of the
--   main / pause menu. Restored on close. Used by LoadScreen when opened from
--   the main menu or in-game ESC pause menu.
---@diagnostic disable: undefined-global, undefined-doc-name, need-check-nil, undefined-field, inject-field

ManualSave = ManualSave or {}

-- Creates a docked screen panel centred on screen.
--
-- opts:
--   w, h         number    dimensions of the inner content panel
--   x, y         number?   explicit position (overrides centering)
--   subScreenOf  string?   "mainScreen": vanilla-like sub-screen of MainScreen
--                          (no overlay, hides bottomPanel, transfers joypad focus)
--   onClose      fun()?    shorthand for obj.onClose(fn)
--   onFocus      fun(p, x, y)?
--   onLostFocus  fun(p, x, y)?
--   onKeyPressed fun(p, key)?
--   onKeyRelease fun(p, key)?
--   update       fun(p)?
--
---@param opts { w:number, h:number, x:number?, y:number?, subScreenOf:string?, onClose:fun()?, onKeyRelease:fun(p:any,key:number)?, onFocus:fun(p:any,x:number,y:number)?, onLostFocus:fun(p:any,x:number,y:number)?, onKeyPressed:fun(p:any,key:number)?, update:fun(p:any)? }
---@return { panel:ISPanel, titleH:number, open:fun(jp:any?), close:fun(), onClose:fun(fn:fun()) }
function ManualSave.makeScreenPanel(opts)
    local TH = ManualSave.Theme
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()

    local isSubOfMain = (opts.subScreenOf == "mainScreen")

    -- Full-screen backdrop — provides dark overlay and captures input.
    -- Skipped in sub-screen mode: the underlying MainScreen stays visible.
    local outer = nil
    if not isSubOfMain then
        outer = ISPanel:new(0, 0, sw, sh)
        outer.backgroundColor = { r=0, g=0, b=0, a=0.82 }
        outer.borderColor     = { r=0, g=0, b=0, a=0    }
        outer:initialise()
        outer:instantiate()
    end

    -- Inner content panel — this is what callers receive as obj.panel
    local cx = opts.x or math.floor((sw - opts.w) / 2)
    local cy = opts.y or math.floor((sh - opts.h) / 2)
    local inner = ISPanel:new(cx, cy, opts.w, opts.h)
    inner.backgroundColor = { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=0.98 }
    inner.borderColor     = { r=0, g=0, b=0, a=0 }  -- drawn after children via render override
    inner:initialise()
    inner:instantiate()
    -- ISPanel.render IS the full pipeline (bg + children). Call it first,
    -- then redraw the border on top so child panels cannot overdraw it.
    inner.render = function(self2)
        ISPanel.render(self2)
        self2:drawRectBorder(0, 0, self2.width, self2.height, 1,
            TH.LINE_R, TH.LINE_G, TH.LINE_B)
    end
    if outer then outer:addChild(inner) end

    local callbacks = {}
    local closing   = false

    -- Sub-screen mode state: remembered between open() and close() so we can
    -- restore the previous MainScreen visuals and joypad focus on close.
    local savedJoypadData     = nil
    local savedInMainMenuFlag = nil
    local hidBottomPanel      = false

    local obj = {
        panel  = inner,
        titleH = 0,
    }

    ---@param fn fun()
    function obj.onClose(fn)
        table.insert(callbacks, fn)
    end

    function obj.open(joypadData)
        if isSubOfMain then
            local ms = MainScreen and MainScreen.instance
            -- Hide the menu items (vanilla MainOptions pattern).
            if ms and ms.bottomPanel and ms.bottomPanel:isVisible() then
                ms.bottomPanel:setVisible(false)
                hidBottomPanel = true
            end
            -- Inner becomes a direct UI element on top of MainScreen.
            inner:addToUIManager()
            inner:setVisible(true)
            inner:bringToTop()
            -- Joypad focus transfer (vanilla ISPanelJoypad.setVisible pattern).
            -- Also clear joypadData.inMainMenu while we own the focus, otherwise
            -- MainScreen.update / JoypadState.reactivateJoypad re-steal it every
            -- frame and the D-pad ends up driving the main menu underneath.
            if joypadData then
                savedJoypadData     = joypadData
                savedInMainMenuFlag = joypadData.inMainMenu
                joypadData.inMainMenu = false
                joypadData.focus    = inner
                if updateJoypadFocus then updateJoypadFocus(joypadData) end
            end
            -- Without the fullscreen `outer` we cannot rely on inner having UI
            -- focus at all times — install a global key listener so opts.onKeyRelease
            -- (ESC, F2, RETURN, ...) keeps firing regardless of focus owner.
            if globalKeyListener then
                Events.OnKeyReleased.Add(globalKeyListener)
            end
        else
            outer:addToUIManager()
            outer:setVisible(true)
            outer:bringToTop()
        end
    end

    function obj.close()
        if closing then return end
        closing = true
        if isSubOfMain then
            -- Vanilla MainOptions plays this sound on ESC/Back return.
            pcall(function() getSoundManager():playUISound("UIPauseMenuExit") end)
            if globalKeyListener then
                Events.OnKeyReleased.Remove(globalKeyListener)
            end
            inner:setVisible(false)
            inner:removeFromUIManager()
            -- Restore the menu items we hid on open.
            if hidBottomPanel then
                local ms = MainScreen and MainScreen.instance
                if ms and ms.bottomPanel then ms.bottomPanel:setVisible(true) end
                hidBottomPanel = false
            end
            -- Hand the joypad focus back to MainScreen and restore the
            -- inMainMenu flag we cleared on open (true when opened from the
            -- main menu, false when opened from the in-game pause menu).
            if savedJoypadData then
                if savedInMainMenuFlag ~= nil then
                    savedJoypadData.inMainMenu = savedInMainMenuFlag
                end
                savedJoypadData.focus = MainScreen and MainScreen.instance or nil
                if updateJoypadFocus then updateJoypadFocus(savedJoypadData) end
                savedJoypadData     = nil
                savedInMainMenuFlag = nil
            end
        else
            outer:setVisible(false)
            outer:removeFromUIManager()
        end
        for _, fn in ipairs(callbacks) do pcall(fn) end
    end

    if opts.onFocus      then inner.onFocus      = opts.onFocus      end
    if opts.onLostFocus  then inner.onLostFocus  = opts.onLostFocus  end
    if opts.onKeyPressed then inner.onKeyPressed = opts.onKeyPressed end
    if opts.update       then inner.update       = opts.update       end

    -- opts.onKeyRelease runs first; ESC closes the screen by default after.
    --
    -- In sub-screen mode we don't have the fullscreen `outer` panel that used
    -- to catch every keyboard event by virtue of being on top of everything.
    -- `inner` only receives onKeyRelease when it currently has UI focus, which
    -- it may not after a mouse click on a child widget. We therefore register
    -- a global Events.OnKeyReleased listener for the lifetime of the screen,
    -- so screen-level keys (ESC, F2, RETURN, ...) always reach opts.onKeyRelease.
    local function keyHandler(_, key)
        if opts.onKeyRelease then opts.onKeyRelease(_, key) end
        if key == Keyboard.KEY_ESCAPE then obj.close() end
    end
    if outer then outer.onKeyRelease = keyHandler end
    inner.onKeyRelease = keyHandler

    local globalKeyListener = nil
    if isSubOfMain then
        globalKeyListener = function(key) keyHandler(nil, key) end
    end

    -- InputNav: auto-create a focus manager + group for this screen. Child
    -- widgets created via makeButton/makeToolbar/etc. with no explicit
    -- focusGroup will walk up the parent chain and register themselves here.
    if ManualSave.InputNav and ManualSave.InputNav.installPanelNav then
        ManualSave.InputNav.installPanelNav(inner, obj, { id="screen" })
    end

    if opts.onClose then obj.onClose(opts.onClose) end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Screen.lua loaded.")
