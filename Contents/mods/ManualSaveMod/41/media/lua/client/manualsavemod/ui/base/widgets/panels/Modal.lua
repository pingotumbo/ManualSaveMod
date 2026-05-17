-- UI/Base/Panels/Modal.lua
-- Blocking modal panel: dark full-screen overlay that does NOT close on click.
-- Closed only by ESC or by the buttons inside (confirm/cancel).
-- Used for destructive actions that require deliberate confirmation.
---@diagnostic disable: undefined-global, undefined-doc-name

ManualSave = ManualSave or {}

-- Creates a blocking modal panel centred on screen.
--
-- opts:
--   w, h      number    dimensions of the content panel
--   x, y      number?   explicit position (overrides centering)
--   onClose   fun()?    shorthand for obj.onClose(fn)
--
---@param opts { w:number, h:number, x:number?, y:number?, onClose:fun()? }
---@return { panel:ISPanel, titleH:number, open:fun(), close:fun(), onClose:fun(fn:fun()) }
function ManualSave.makeModalPanel(opts)
    local TH = ManualSave.Theme
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()

    -- Full-screen dark overlay — blocks all interaction with panels behind
    local overlay = ISPanel:new(0, 0, sw, sh)
    overlay.backgroundColor = { r=0, g=0, b=0, a=TH.OVERLAY_A }
    overlay.borderColor     = { r=0, g=0, b=0, a=0 }
    overlay:initialise()
    overlay:instantiate()
    -- Consume all clicks on the overlay (blocking — does not close on click)
    overlay.onMouseDown = function() return true end

    -- Content panel
    local cx = opts.x or math.floor((sw - opts.w) / 2)
    local cy = opts.y or math.floor((sh - opts.h) / 2)
    local p = ISPanel:new(cx, cy, opts.w, opts.h)
    p.backgroundColor = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }
    p.borderColor     = { r=TH.LINE_R,  g=TH.LINE_G,  b=TH.LINE_B,  a=1 }
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
        ManualSave._uiTopLock = math.max(0, (ManualSave._uiTopLock or 0) - 1)
        overlay:setVisible(false)
        overlay:removeFromUIManager()
        for _, fn in ipairs(callbacks) do pcall(fn) end
    end

    function obj.open()
        ManualSave._uiTopLock = (ManualSave._uiTopLock or 0) + 1
        overlay:addToUIManager()
        overlay:setVisible(true)
        overlay:bringToTop()
    end

    function obj.close()
        doClose()
    end

    -- ESC closes
    overlay.onKeyRelease = function(_, key)
        if key == Keyboard.KEY_ESCAPE then doClose() end
    end

    if opts.onClose then obj.onClose(opts.onClose) end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Modal.lua loaded.")
