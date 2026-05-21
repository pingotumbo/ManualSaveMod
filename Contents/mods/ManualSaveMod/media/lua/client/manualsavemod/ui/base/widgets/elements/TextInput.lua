-- UI/Base/Elements/TextInput.lua
-- Single-line text input with optional search icon and placeholder text.
-- Adds the input to parent automatically.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field, redundant-parameter

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

        -- InputNav focus ring: keyboard navigation arrived here but the user has
        -- not started typing yet. Shows the same orange focus accent as buttons.
        if self2.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
            self2:drawRect(0, 0, self2.width, self2.height,
                TH.FOCUS_BG_A, TH.FOCUS_BG_R, TH.FOCUS_BG_G, TH.FOCUS_BG_B)
            for i = 0, TH.FOCUS_BW - 1 do
                self2:drawRectBorder(i, i, self2.width - i*2, self2.height - i*2, 1,
                    TH.FOCUS_R, TH.FOCUS_G, TH.FOCUS_B)
            end
        end

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

    -- InputNav integration with PZ's ISTextEntryBox key model.
    --
    -- PZ does NOT fire a generic onKeyPressed on text entries; instead it routes
    -- specific keys to dedicated callbacks:
    --   onPressUp / onPressDown  — Up / Down arrow keys
    --   onOtherKey(key)          — everything else (Esc, Tab, Left/Right, letters)
    --   onCommandEntered         — Enter
    --   onLostFocus              — fires when focus is released (programmatically or by click)
    --
    -- Hooking the wrong callback was the reason Esc / arrows did not release
    -- typing focus in earlier versions.
    local capturedByInputNav = false
    local function navBeginCapture()
        if capturedByInputNav then return end
        capturedByInputNav = true
        if ManualSave.InputNav and ManualSave.InputNav.beginTextCapture then
            ManualSave.InputNav.beginTextCapture(function()
                pcall(function() innerEntry:unfocus() end)
            end)
        end
        -- Visual: while typing we are conceptually in "mouse mode" — hide all
        -- focus rings so the cursor / typing field is the only highlight on screen.
        if ManualSave.InputNav and ManualSave.InputNav.setKeyboardActive then
            ManualSave.InputNav.setKeyboardActive(false)
        end
    end
    local function navEndCapture()
        if not capturedByInputNav then return end
        capturedByInputNav = false
        if ManualSave.InputNav and ManualSave.InputNav.endTextCapture then
            ManualSave.InputNav.endTextCapture()
        end
    end

    -- Re-enter keyboard mode and dispatch the released key to nav so focus
    -- moves to the next/previous widget in one keystroke.
    local function releaseAndDispatch(key)
        pcall(function() innerEntry:unfocus() end)
        if ManualSave.InputNav then
            ManualSave.InputNav.setKeyboardActive(true)
            if key then
                local mgr = ManualSave.InputNav.activeManager()
                if mgr and ManualSave.InputNav.InputRouter then
                    ManualSave.InputNav.InputRouter.handleKey(mgr, key)
                end
            end
        end
    end

    local userOnFocus       = opts.onFocus
    local userOnLostFocus   = opts.onLostFocus
    local userOnPressDown   = opts.onPressDown
    local userOnPressUp     = opts.onPressUp
    local userOnOtherKey    = opts.onOtherKey

    innerEntry.onFocus = function(self2, x, y)
        navBeginCapture()
        if userOnFocus then userOnFocus(self2, x, y) end
    end
    -- Mouse click on the text entry: PZ focuses it automatically, but the
    -- onFocus callback is not guaranteed to fire. Hook onClick to make sure
    -- typing-mode side effects (keyboardActive=false, text-capture flag) run.
    local userOnClick = innerEntry.onClick
    innerEntry.onClick = function(self2, x, y)
        navBeginCapture()
        if userOnClick then userOnClick(self2, x, y) end
    end
    innerEntry.onLostFocus = function(self2, x, y)
        navEndCapture()
        if userOnLostFocus then userOnLostFocus(self2, x, y) end
    end
    -- Down arrow released-while-typing → release typing + nav forward.
    innerEntry.onPressDown = function(self2)
        releaseAndDispatch(Keyboard.KEY_DOWN)
        if userOnPressDown then userOnPressDown(self2) end
    end
    innerEntry.onPressUp = function(self2)
        releaseAndDispatch(Keyboard.KEY_UP)
        if userOnPressUp then userOnPressUp(self2) end
    end
    -- onOtherKey catches everything else PZ routes here, including Esc and Tab.
    -- Esc releases typing without moving nav; Tab releases and advances nav.
    -- Letters / cursor keys fall through to PZ for normal typing.
    innerEntry.onOtherKey = function(self2, key)
        if key == Keyboard.KEY_ESCAPE then
            releaseAndDispatch(nil)
        elseif key == Keyboard.KEY_TAB then
            releaseAndDispatch(Keyboard.KEY_TAB)
        elseif userOnOtherKey then
            userOnOtherKey(self2, key)
        end
    end
    if opts.onCommandEntered then innerEntry.onCommandEntered = opts.onCommandEntered end
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

    -- InputNav auto-register: text inputs are navigable items in the parent
    -- screen's nav group. Tab/arrow keys move focus to them; once focused they
    -- begin a text-capture (see beginTextCapture above) so arrow keys move the
    -- cursor rather than navigating away.
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then
            -- Enter on a nav-focused TextInput puts it in typing mode (PZ
            -- keyboard focus on the ISTextEntryBox). We call navBeginCapture
            -- ourselves rather than waiting for innerEntry.onFocus to fire —
            -- PZ does not reliably propagate focus() to the onFocus callback,
            -- so this guarantees keyboardActive flips off and the focus ring
            -- disappears the instant typing starts.
            wrap.onActivate = function()
                pcall(function() innerEntry:focus() end)
                navBeginCapture()
            end
            g:add(wrap)
        end
    end

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
    obj.wrap  = wrap   -- outer panel; useful for cover-panel hideTargets

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/TextInput.lua loaded.")
