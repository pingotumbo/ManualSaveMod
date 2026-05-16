-- UI/Base/Panels/_Base.lua
-- Internal builder shared by all panel types.
-- NOT part of the public API — call makeFloatingPanel / makeModalPanel / etc. instead.
---@diagnostic disable: undefined-global, undefined-doc-name

ManualSave = ManualSave or {}

-- Builds a base panel object with shared open/close/onClose mechanics.
-- All public panel factories call this first, then add their own behaviour on top.
--
-- opts:
--   x, y        number?   position (default 0,0 — subtypes reposition as needed)
--   w, h        number    dimensions (required)
--
---@param opts { x:number?, y:number?, w:number, h:number }
---@return { panel:ISPanel, titleH:number, open:fun(), close:fun(), onClose:fun(fn:fun()) }
function ManualSave._buildBasePanel(opts)
    local TH = ManualSave.Theme

    local p = ISPanel:new(opts.x or 0, opts.y or 0, opts.w, opts.h)
    p.backgroundColor = { r=TH.BG_R,   g=TH.BG_G,   b=TH.BG_B,   a=1 }
    p.borderColor     = { r=TH.LINE_R,  g=TH.LINE_G,  b=TH.LINE_B,  a=1 }
    p:initialise()
    p:instantiate()

    local callbacks = {}

    local obj = {
        panel  = p,
        titleH = 0,
    }

    -- Registers a function to be called when this panel closes.
    ---@param fn fun()
    function obj.onClose(fn)
        table.insert(callbacks, fn)
    end

    -- Shows the panel on screen.
    function obj.open()
        p:addToUIManager()
        p:setVisible(true)
        p:bringToTop()
    end

    -- Hides the panel and fires all onClose callbacks.
    function obj.close()
        p:setVisible(false)
        p:removeFromUIManager()
        for _, fn in ipairs(callbacks) do
            pcall(fn)
        end
    end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/_Base.lua loaded.")
