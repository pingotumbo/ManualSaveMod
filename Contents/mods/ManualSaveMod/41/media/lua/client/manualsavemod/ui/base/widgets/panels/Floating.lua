-- UI/Base/Panels/Floating.lua
-- Draggable window with title bar, subtitle, X button, and accent line.
-- Centred on screen by default; accepts explicit x,y to override.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

-- Creates a floating panel window.
--
-- opts:
--   w, h         number    dimensions
--   x, y         number?   explicit position (default: centred on screen)
--   title        string?   title bar text
--   subtitle     string?   small text shown next to the title
--   onClose      fun()?    shorthand for obj.onClose(fn)
--   onFocus      fun(p, x, y)?
--   onLostFocus  fun(p, x, y)?
--   onKeyPressed fun(p, key)?
--   onKeyRelease fun(p, key)?   called alongside the built-in ESC handler
--   update       fun(p)?
--
---@param opts { w:number, h:number, x:number?, y:number?, title:string?, subtitle:string?, onClose:fun()? }
---@return { panel:ISPanel, titleH:number, open:fun(), close:fun(), onClose:fun(fn:fun()) }
function ManualSave.makeFloatingPanel(opts)
    local TH  = ManualSave.Theme
    local sw  = getCore():getScreenWidth()
    local sh  = getCore():getScreenHeight()
    local px  = opts.x or math.floor((sw - opts.w) / 2)
    local py  = opts.y or math.floor((sh - opts.h) / 2)

    local titleH = TH.FONT_HGT_LARGE + 22

    local p = ISPanel:new(px, py, opts.w, opts.h)
    p.backgroundColor = { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }
    p.borderColor     = { r=0, g=0, b=0, a=0 }   -- drawn manually below
    p:initialise()
    p:instantiate()
    p.prerender = function(self2)
        ISPanel.prerender(self2)
    end

    p.render = function(self2)
        local TH2 = ManualSave.Theme
        if opts.borderStyle == "accent" then
            -- Solid 2-pixel accent border on all four edges (used by HelpScreen
            -- and any other floating panel that wants a stronger frame).
            local bw = 2
            self2:drawRect(0, 0, self2.width, bw, 1, TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            self2:drawRect(0, self2.height-bw, self2.width, bw, 1, TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            self2:drawRect(0, 0, bw, self2.height, 1, TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            self2:drawRect(self2.width-bw, 0, bw, self2.height, 1, TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
        else
            -- Default: 2-tone accent border (outer dim, inner faint glow)
            self2:drawRectBorder(0, 0, self2.width, self2.height, 0.85,
                TH2.ACCENT_R * 0.85, TH2.ACCENT_G * 0.60, TH2.ACCENT_B * 0.35)
            self2:drawRectBorder(1, 1, self2.width - 2, self2.height - 2, 0.22,
                TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
        end
    end

    -- Title bar background
    local titleBar = ISPanel:new(0, 0, opts.w, titleH)
    titleBar.backgroundColor = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }
    titleBar.borderColor     = { r=0, g=0, b=0, a=0 }
    titleBar:initialise()
    titleBar:instantiate()
    titleBar.prerender = function(tb)
        ISPanel.prerender(tb)
        -- bottom border
        tb:drawRect(0, tb.height - 1, tb.width, 1, 1, TH.LINE_R, TH.LINE_G, TH.LINE_B)
        -- accent line at very top
        ManualSave.Draw.accentBar(tb, 0, 0, tb.width)
        -- title text
        local ty = math.floor((tb.height - TH.FONT_HGT_LARGE) / 2)
        tb:drawText(opts.title or "", TH.PAD, ty,
            TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Large)
        if opts.subtitle and opts.subtitle ~= "" then
            local tx = TH.PAD + getTextManager():MeasureStringX(UIFont.Large, opts.title or "") + 12
            tb:drawText(opts.subtitle, tx, ty,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 1, UIFont.Large)
        end
    end
    -- Title bar enables dragging on the outer panel, then forwards the mousedown
    titleBar.onMouseDown = function(_, mx, my)
        p.moveWithMouse = true
        p:bringToTop()
        ISPanel.onMouseDown(p, mx, my)
    end
    p:addChild(titleBar)

    -- Drag is only active while the title bar is being held; reset on release
    p.onMouseDown = function(self2, mx, my)
        self2:bringToTop()
        return ISPanel.onMouseDown(self2, mx, my)
    end
    p.onMouseUp = function(self2, mx, my)
        self2.moveWithMouse = false
        if ISPanel.onMouseUp then ISPanel.onMouseUp(self2, mx, my) end
    end

    local callbacks = {}
    local closing   = false

    local obj = {
        panel     = p,
        titleH    = titleH,
        _titleBar = titleBar,
    }

    ---@param fn fun()
    function obj.onClose(fn)
        table.insert(callbacks, fn)
    end

    local function doClose()
        if closing then return end
        closing = true
        p:setVisible(false)
        p:removeFromUIManager()
        for _, fn in ipairs(callbacks) do pcall(fn) end
    end

    function obj.open()
        p:addToUIManager()
        p:setVisible(true)
        p:bringToTop()
    end

    function obj.close()
        doClose()
    end

    -- Update subtitle text at runtime (e.g. "3 saves found" → "5 saves found")
    ---@param text string
    function obj.setSubtitle(text)
        opts.subtitle = text
    end

    -- X button (square)
    local xW = 28
    local xBtn = ISButton:new(opts.w - xW - 6, math.floor((titleH - xW) / 2), xW, xW, "X", p, function(_) doClose() end)
    xBtn:initialise()
    xBtn:instantiate()
    xBtn.backgroundColor          = { r=0, g=0, b=0, a=0 }
    xBtn.backgroundColorMouseOver = { r=TH.DANGER_R, g=TH.DANGER_G, b=TH.DANGER_B, a=0.25 }
    xBtn.borderColor = { r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.5 }
    xBtn.textColor   = { r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=1 }
    p:addChild(xBtn)
    -- InputNav: expose onActivate so Enter on the focused X fires close.
    -- The render below adds the focus ring; actual nav registration happens
    -- after installPanelNav, deferred to obj.open so X sits at the END of
    -- the tab order (preserves content-first default focus).
    xBtn.onActivate = function() doClose() end

    -- Render the focus ring on the X button when keyboard mode is active.
    local xOrigRender = xBtn.render
    xBtn.render = function(self2)
        if xOrigRender then xOrigRender(self2) end
        if self2.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
            for i = 0, TH.FOCUS_BW - 1 do
                self2:drawRectBorder(i, i, self2.width - i*2, self2.height - i*2, 1,
                    TH.FOCUS_R, TH.FOCUS_G, TH.FOCUS_B)
            end
        end
    end

    -- ESC closes; opt callback runs alongside it
    p.onKeyRelease = function(self2, key)
        if key == Keyboard.KEY_ESCAPE then doClose() end
        if opts.onKeyRelease then opts.onKeyRelease(self2, key) end
    end

    if opts.onFocus      then p.onFocus      = opts.onFocus      end
    if opts.onLostFocus  then p.onLostFocus  = opts.onLostFocus  end
    if opts.onKeyPressed then p.onKeyPressed = opts.onKeyPressed end
    if opts.render then
        local _borderRender = p.render
        local _userRender   = opts.render
        p.render = function(self2) _borderRender(self2); _userRender(self2) end
    end

    -- Stay on top unless a modal is open; wrap opts.update if provided
    local _userUpdate = opts.update
    p.update = function(self2)
        ISPanel.update(self2)
        if (ManualSave._uiTopLock or 0) == 0 then
            self2:bringToTop()
        end
        if _userUpdate then _userUpdate(self2) end
    end
    if opts.noBorder then p.render = function() end end

    -- InputNav: auto-create a focus manager + group for this floating window.
    if ManualSave.InputNav and ManualSave.InputNav.installPanelNav then
        ManualSave.InputNav.installPanelNav(p, obj, { id="floating" })
        -- Defer X button registration so it sits at the END of the tab order
        -- (after all content widgets the caller will add later between makeFloatingPanel
        -- returning and d.open() being called). _inputNavRegisterAtEnd drains its
        -- queue inside the open() wrapper installed by installPanelNav.
        if p._inputNavRegisterAtEnd then p._inputNavRegisterAtEnd(xBtn) end
    end

    if opts.onClose then obj.onClose(opts.onClose) end

    return obj
end

-- Creates a lazily-instantiated singleton expand panel suitable for use as
-- a MiniList onExpand callback.
--
-- Returns { open: fun(), close: fun() }.
--   open()  — first call creates the floating panel and opens it.
--             subsequent calls bring the existing panel to the top.
--   close() — closes the panel if currently open.
--
-- opts:
--   title    string
--   w        number?   default 280
--   items    table     list items
--   rowH     number?   default TH.FONT_HGT_SMALL + 4
--   drawRow  fun(panel, item, x, y, w, h, sel, idx)
--
---@param opts table
---@return { open:fun(), close:fun() }
function ManualSave.makeExpandPanel(opts)
    local handle = nil   -- makeFloatingPanel result while panel is open
    local obj    = {}

    function obj.open()
        if handle then
            pcall(function()
                handle.panel:setVisible(true)
                handle.panel:bringToTop()
            end)
            return
        end
        local TH    = ManualSave.Theme
        local rh    = opts.rowH or (TH.FONT_HGT_SMALL + 4)
        local items = opts.items or {}
        local listH = math.min(300, math.max(80, #items * rh))
        local w     = opts.w or 280
        local d     = ManualSave.makeFloatingPanel({
            w=w, h=(TH.FONT_HGT_LARGE + 22) + listH,
            title = opts.title,
            x = opts.x,
            y = opts.y,
        })
        handle = d
        d.onClose(function() handle = nil end)
        ManualSave.makeScrollList(d.panel, {
            x=0, y=d.titleH, w=w, h=listH,
            rowH=rh, items=items, drawRow=opts.drawRow,
        })
        -- Stay on top of the parent screen when other panels are clicked.
        d.panel.update = function(self2)
            ISPanel.update(self2)
            if (ManualSave._uiTopLock or 0) == 0 then
                self2:bringToTop()
            end
        end
        d.open()
    end

    function obj.close()
        if handle then
            pcall(handle.close)
            handle = nil
        end
    end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Floating.lua loaded.")
