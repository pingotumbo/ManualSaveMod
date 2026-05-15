-- UI/Base/Elements/TextInput.lua
-- Single-line text input with optional search icon and placeholder text.
-- Adds the input to parent automatically.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

-- Creates a styled text input and adds it to parent.
--
-- opts:
--   x, y               number
--   w, h               number
--   placeholder        string?              greyed hint text shown when empty
--   icon               "search"?            draws a magnifier glyph on the left side
--   value              string?              initial value (default "")
--   font               UIFont?              font for the text entry (default UIFont.Small)
--   visible            boolean?             if false, starts hidden (default true)
--   onChange           fun(text:string)?    called on every keystroke
--   onCommandEntered   fun()?               called when Enter is pressed
--   onLostFocus        fun()?               called when the entry loses focus
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, placeholder:string?, icon:string?, value:string?, font:any?, visible:boolean?, onChange:fun(text:string)?, onCommandEntered:fun()?, onLostFocus:fun()? }
---@return { input:ISTextEntryBox, getValue:fun():string, setValue:fun(text:string), clear:fun(), setVisible:fun(v:boolean), setX:fun(x:number), setY:fun(y:number), setWidth:fun(w:number), focus:fun(), unfocus:fun() }
function ManualSave.makeTextInput(parent, opts)
    local TH = ManualSave.Theme

    local iconW  = (opts.icon == "search") and (TH.FONT_HGT_SMALL + 8) or 0
    local padL   = iconW + (iconW > 0 and 2 or 0)

    -- Wrapper panel so the icon and border are part of one unit
    local wrap = ISPanel:new(opts.x, opts.y, opts.w, opts.h)
    wrap.backgroundColor = { r=TH.BG_R,  g=TH.BG_G,  b=TH.BG_B,  a=1 }
    wrap.borderColor     = { r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 }
    wrap:initialise()
    wrap:instantiate()

    -- Entry lives inside wrapper, offset to make room for icon
    -- y=2 shifts text/cursor down 2px so it appears vertically centred in the wrapper
    local innerEntry = ISTextEntryBox:new(opts.value or "", padL + 2, 2, opts.w - padL - 4, opts.h - 2)
    innerEntry:initialise()
    innerEntry:instantiate()
    innerEntry:setFont(opts.font or UIFont.Small)
    innerEntry.backgroundColor          = { r=0, g=0, b=0, a=0 }
    innerEntry.backgroundColorSelected  = { r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.25 }
    innerEntry.borderColor              = { r=0, g=0, b=0, a=0 }
    innerEntry.textColor                = { r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1 }
    wrap:addChild(innerEntry)

    -- Placeholder + icon drawn in prerender
    local placeholder = opts.placeholder or ""
    wrap.prerender = function(self2)
        ISPanel.prerender(self2)
        -- Focused border highlight
        local focused = false
        pcall(function() focused = innerEntry:isFocused() end)
        local br = focused and TH.ACCENT_R or TH.LINE_R
        local bg = focused and TH.ACCENT_G or TH.LINE_G
        local bb = focused and TH.ACCENT_B or TH.LINE_B
        local ba = focused and 0.7 or 1
        self2:drawRectBorder(0, 0, self2.width, self2.height, ba, br, bg, bb)

        -- Search icon (drawn magnifier — no Unicode)
        if opts.icon == "search" then
            local r  = math.floor(math.min(self2.height * 0.28, 5))
            local cx = 5 + r
            local cy = math.floor(self2.height / 2)
            ManualSave.Draw.searchIcon(self2, cx, cy, r, 0.6, TH.MUTED_R, TH.MUTED_G, TH.MUTED_B)
        end

        -- Placeholder
        local text = innerEntry:getText() or ""
        if text == "" and placeholder ~= "" then
            local gy = math.floor((self2.height - TH.FONT_HGT_SMALL) / 2)
            self2:drawText(placeholder, padL + 4, gy,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.55, UIFont.Small)
        end
    end

    if opts.onFocus          then innerEntry.onFocus          = opts.onFocus          end
    if opts.onLostFocus      then innerEntry.onLostFocus      = opts.onLostFocus      end
    if opts.onCommandEntered then innerEntry.onCommandEntered = opts.onCommandEntered end
    if opts.onKeyPressed     then innerEntry.onKeyPressed     = opts.onKeyPressed     end
    if opts.onKeyRelease     then innerEntry.onKeyRelease     = opts.onKeyRelease     end

    -- onChange wired via the text entry's internal callback
    if opts.onChange then
        local lastText = opts.value or ""
        local origRender = innerEntry.render
        innerEntry.render = function(self2)
            if origRender then origRender(self2) end
            local cur = self2:getText() or ""
            if cur ~= lastText then
                lastText = cur
                pcall(opts.onChange, cur)
            end
        end
    end

    if parent then parent:addChild(wrap) end
    if opts.visible == false then wrap:setVisible(false) end

    local obj = {}

    ---@return string
    function obj.getValue()
        local ok, v = pcall(function() return innerEntry:getInternalText() end)
        return (ok and v) or innerEntry:getText() or ""
    end

    ---@param text string
    function obj.setValue(text) innerEntry:setText(text) end

    function obj.clear() innerEntry:setText("") end

    function obj.setVisible(v) wrap:setVisible(v) end
    function obj.setX(x) wrap:setX(x) end
    function obj.setY(y) wrap:setY(y) end
    function obj.setWidth(w) wrap:setWidth(w); innerEntry:setWidth(w - padL - 4) end
    function obj.focus()   pcall(function() innerEntry:focus() end) end
    function obj.unfocus() pcall(function() innerEntry:unfocus() end) end

    obj.input = innerEntry

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/TextInput.lua loaded.")
