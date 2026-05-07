-- UI/Base/Panels/Screen.lua
-- Fixed full-screen docked panel (like PZ's own settings screens).
-- No title bar, no drag, no X button. Closed via Back button or ESC.
-- The dark full-screen backdrop is internal — callers work with obj.panel (inner).
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

-- Creates a docked screen panel centred on screen.
--
-- opts:
--   w, h         number    dimensions of the inner content panel
--   x, y         number?   explicit position (overrides centering)
--   onClose      fun()?    shorthand for obj.onClose(fn)
--   onFocus      fun(p, x, y)?
--   onLostFocus  fun(p, x, y)?
--   onKeyPressed fun(p, key)?
--   onKeyRelease fun(p, key)?
--   update       fun(p)?
--
---@param opts { w:number, h:number, x:number?, y:number?, onClose:fun()? }
---@return { panel:ISPanel, titleH:number, open:fun(), close:fun(), onClose:fun(fn:fun()) }
function ManualSave.makeScreenPanel(opts)
    local TH = ManualSave.Theme
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()

    -- Full-screen backdrop — provides dark overlay and captures input
    local outer = ISPanel:new(0, 0, sw, sh)
    outer.backgroundColor = { r=0, g=0, b=0, a=0.82 }
    outer.borderColor     = { r=0, g=0, b=0, a=0    }
    outer:initialise()
    outer:instantiate()

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
    outer:addChild(inner)

    local callbacks = {}

    local obj = {
        panel  = inner,
        titleH = 0,
    }

    ---@param fn fun()
    function obj.onClose(fn)
        table.insert(callbacks, fn)
    end

    function obj.open()
        outer:addToUIManager()
        outer:setVisible(true)
        outer:bringToTop()
    end

    function obj.close()
        outer:setVisible(false)
        outer:removeFromUIManager()
        for _, fn in ipairs(callbacks) do pcall(fn) end
    end

    if opts.onFocus      then inner.onFocus      = opts.onFocus      end
    if opts.onLostFocus  then inner.onLostFocus  = opts.onLostFocus  end
    if opts.onKeyPressed then inner.onKeyPressed = opts.onKeyPressed end
    if opts.onKeyRelease then inner.onKeyRelease = opts.onKeyRelease end
    if opts.update       then inner.update       = opts.update       end

    if opts.onClose then obj.onClose(opts.onClose) end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Screen.lua loaded.")
