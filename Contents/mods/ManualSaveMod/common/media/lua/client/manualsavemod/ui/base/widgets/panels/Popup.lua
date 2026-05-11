-- UI/Base/Panels/Popup.lua
-- Non-blocking panel that closes when the user clicks outside it.
-- Used for: info tooltips, name-input dialogs, confirm dialogs (non-aggressive),
--           mod/map list popups.
-- No overlay colour — background stays fully visible behind the popup.
---@diagnostic disable: undefined-global, undefined-doc-name

ManualSave = ManualSave or {}

-- Creates a popup panel.
--
-- Positioning (pick one):
--   anchorX, anchorY  number?  coordinates of the trigger element (panel positions itself nearby)
--   x, y              number?  explicit position (overrides anchor; default: centred on screen)
--
-- opts:
--   w, h        number    dimensions
--   anchorX/Y   number?   anchor point for tooltip-style positioning
--   x, y        number?   explicit position
--   draggable   boolean?  if true the panel can be dragged (default false)
--   onClose     fun()?    shorthand for obj.onClose(fn)
--
---@param opts { w:number, h:number, anchorX:number?, anchorY:number?, x:number?, y:number?, draggable:boolean?, onClose:fun()? }
---@return { panel:ISPanel, titleH:number, open:fun(), close:fun(), onClose:fun(fn:fun()) }
function ManualSave.makePopupPanel(opts)
    local TH = ManualSave.Theme
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()

    -- Resolve position
    local px, py
    if opts.x and opts.y then
        px, py = opts.x, opts.y
    elseif opts.anchorX and opts.anchorY then
        -- Default: appear below the anchor, shift left if too close to right edge
        px = math.min(opts.anchorX, sw - opts.w - 4)
        py = opts.anchorY
        -- If not enough room below, appear above
        if py + opts.h > sh - 4 then
            py = opts.anchorY - opts.h - 4
        end
        px = math.max(4, px)
        py = math.max(4, py)
    else
        -- Centred on screen (dialog-style)
        px = math.floor((sw - opts.w) / 2)
        py = math.floor((sh - opts.h) / 2)
    end

    -- Full-screen transparent capture layer — click outside = close
    local overlay = ISPanel:new(0, 0, sw, sh)
    overlay.backgroundColor = { r=0, g=0, b=0, a=0 }
    overlay.borderColor     = { r=0, g=0, b=0, a=0 }
    overlay:initialise()
    overlay:instantiate()

    -- Content panel
    local p = ISPanel:new(px, py, opts.w, opts.h)
    p.backgroundColor = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }
    p.borderColor     = { r=TH.LINE_R,  g=TH.LINE_G,  b=TH.LINE_B,  a=1 }
    if opts.draggable then p.moveWithMouse = 1 end
    p:initialise()
    p:instantiate()
    overlay:addChild(p)

    local callbacks = {}
    local closing   = false

    local obj = {
        panel  = p,
        titleH = 0,
    }

    ---@param fn fun()
    function obj.onClose(fn)
        table.insert(callbacks, fn)
    end

    local function doClose()
        if closing then return end
        closing = true
        overlay:setVisible(false)
        overlay:removeFromUIManager()
        for _, fn in ipairs(callbacks) do pcall(fn) end
    end

    overlay.update = function(self2)
        ISPanel.update(self2)
        self2:bringToTop()
    end

    function obj.open()
        overlay:addToUIManager()
        overlay:setVisible(true)
        overlay:bringToTop()
    end

    function obj.close()
        doClose()
    end

    -- Click on overlay (outside content panel) closes the popup
    overlay.onMouseDown = function(_, mx, my)
        -- Check if click landed inside content panel — if so, do not close
        if mx >= p:getX() and mx <= p:getX() + p:getWidth()
        and my >= p:getY() and my <= p:getY() + p:getHeight() then
            return false
        end
        doClose()
        return true
    end

    -- ESC closes
    overlay.onKeyRelease = function(_, key)
        if key == Keyboard.KEY_ESCAPE then doClose() end
    end

    -- Clicks inside the content panel are consumed (don't bubble to overlay)
    local origDown = p.onMouseDown
    p.onMouseDown = function(self2, mx, my)
        if origDown then return origDown(self2, mx, my) end
        return true
    end

    if opts.onClose then obj.onClose(opts.onClose) end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Popup.lua loaded.")
