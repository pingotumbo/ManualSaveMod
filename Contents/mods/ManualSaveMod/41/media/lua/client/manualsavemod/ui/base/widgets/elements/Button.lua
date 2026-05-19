-- UI/Base/Elements/Button.lua
-- Styled button factory. Adds the button to parent automatically.
-- All buttons use a custom render for consistent look across the mod.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

-- Creates a styled button and adds it to parent.
--
-- opts:
--   x, y      number
--   w, h      number
--   label     string
--   style        "normal"|"danger"|"accent"|"primary"  (default "normal")
--                normal  — transparent bg, LINE border, TEXT text
--                danger  — transparent bg, DANGER border/text
--                accent  — transparent bg, ACCENT border/text (e.g. Import button)
--                primary — filled ACCENT bg, dark text        (e.g. Load Save button)
--   enabled      boolean?  initial enabled state (default true)
--   onClick      fun()?
--   render       fun(btn)?  fully overrides the default render (receives the ISButton)
--   onFocus      fun(btn, x, y)?
--   onLostFocus  fun(btn, x, y)?
--   onMouseDown  fun(btn, x, y)?
--   onMouseUp    fun(btn, x, y)?
--   onMouseMove  fun(btn, dx, dy)?
--   onMouseWheel fun(btn, delta)?
--   onKeyPressed fun(btn, key)?
--   onKeyRelease fun(btn, key)?
--   update       fun(btn)?
--   groups       string[]?  group names to register with ManualSave.UI (uses setEnabled)
--   groupInvert  boolean?   if true, element is enabled when group condition is FALSE
--   focusGroup   table?     InputNav FocusGroup; if set, button auto-registers for
--                           keyboard / gamepad navigation and renders a focus ring
--                           when `btn.isFocused == true`.
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, label:string, style:string?, enabled:boolean?, onClick:fun()?, groups:string[]?, groupInvert:boolean? }
---@return { btn:ISButton, setLabel:fun(text:string), setEnabled:fun(v:boolean) }
-- Helper: builds the obj wrapper and registers it with groups + conditional
-- predicates. Used by every makeButton code path so the obj contract (setLabel,
-- setEnabled, setVisible) and external bindings stay consistent.
local function finalizeButton(btn, opts)
    local obj = { btn = btn }
    function obj.setLabel(text) btn:setTitle(text) end
    function obj.setEnabled(v)  btn:setEnable(v)   end
    function obj.setVisible(v)  btn:setVisible(v)  end

    if opts.groups and ManualSave.UI then
        for _, g in ipairs(opts.groups) do
            ManualSave.UI.registerElement(g, obj, opts.groupInvert or false)
        end
    end
    if (opts.enableIf or opts.visibleIf) and ManualSave.UI and ManualSave.UI.registerConditional then
        ManualSave.UI.registerConditional(obj, {
            enableIf  = opts.enableIf,
            visibleIf = opts.visibleIf,
        })
        if opts.enableIf then
            local ok, v = pcall(opts.enableIf)
            if ok then btn:setEnable(v and true or false) end
        end
        if opts.visibleIf then
            local ok, v = pcall(opts.visibleIf)
            if ok then btn:setVisible(v and true or false) end
        end
    end
    return obj
end

function ManualSave.makeButton(parent, opts)
    local TH    = ManualSave.Theme
    local style = opts.style or "normal"

    -- Colours by style
    local bR, bG, bB   -- border / outline
    local tR, tG, tB   -- text
    local fR, fG, fB   -- fill (used when filled=true)
    local fA = 1       -- fill alpha
    local filled = false

    if style == "danger" then
        bR, bG, bB = TH.DANGER_R * 0.7, TH.DANGER_G * 0.7, TH.DANGER_B * 0.7
        tR, tG, tB = TH.DANGER_R, TH.DANGER_G, TH.DANGER_B
    elseif style == "danger-fill" then
        -- Subtle danger fill + full-strength border + text. Visually emphasises
        -- a destructive action that is ready to fire (e.g. Load With Flags when
        -- at least one flag is set). When the button is disabled (via enableIf
        -- or static enabled=false) the standard alpha-fade applies.
        bR, bG, bB = TH.DANGER_R * 0.9, TH.DANGER_G * 0.5, TH.DANGER_B * 0.4
        tR, tG, tB = TH.DANGER_R, TH.DANGER_G + 0.12, TH.DANGER_B + 0.08
        fR, fG, fB = TH.DANGER_R, TH.DANGER_G, TH.DANGER_B
        fA = 0.14
        filled = true
    elseif style == "accent" then
        bR, bG, bB = TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B
        tR, tG, tB = TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B
    elseif style == "primary" then
        bR, bG, bB = TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B
        tR, tG, tB = 0.10, 0.08, 0.06   -- dark text on accent background
        fR, fG, fB = TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B
        fA = 1
        filled = true
    elseif style == "info" then
        bR, bG, bB = TH.MUTED_R, TH.MUTED_G, TH.MUTED_B
        tR, tG, tB = TH.MUTED_R, TH.MUTED_G, TH.MUTED_B
    else -- "normal"
        bR, bG, bB = TH.LINE_R, TH.LINE_G, TH.LINE_B
        tR, tG, tB = TH.TEXT_R, TH.TEXT_G, TH.TEXT_B
    end

    local btn = ISButton:new(opts.x, opts.y, opts.w, opts.h, opts.label or "", parent, opts.onClick)
    btn:initialise()
    btn:instantiate()

    btn.backgroundColor          = { r=0, g=0, b=0, a=0 }
    btn.backgroundColorMouseOver = { r=1, g=1, b=1, a=0.05 }
    btn.borderColor = { r=bR, g=bG, b=bB, a=1 }
    btn.textColor   = { r=tR, g=tG, b=tB, a=1 }

    if opts.render then
        -- Wrap the caller's render so the InputNav focus ring is drawn on top
        -- automatically — custom-render buttons should not have to know about
        -- the focus system to participate in keyboard / gamepad navigation.
        local userRender = opts.render
        btn.render = function(self2)
            userRender(self2)
            if self2.isFocused and self2.enable
               and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
                for i = 0, TH.FOCUS_BW - 1 do
                    self2:drawRectBorder(i, i, self2.width - i*2, self2.height - i*2, 1,
                        TH.FOCUS_R, TH.FOCUS_G, TH.FOCUS_B)
                end
            end
        end
        if opts.enabled == false then btn:setEnable(false) end
        if parent then parent:addChild(btn) end
        btn.onActivate = opts.onClick
        -- InputNav auto-register: walk up parent chain for the nearest panel's
        -- _inputNavGroup. opts.focusGroup overrides (explicit group), false skips.
        if opts.focusGroup ~= false then
            local g = opts.focusGroup
            if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
                g = ManualSave.InputNav.findNavGroup(parent)
            end
            if g then g:add(btn) end
        end
        return finalizeButton(btn, opts)
    end

    if style == "tab" then
        -- Sidebar tab style: no border, left accent bar + tint when active,
        -- subtle white hover, left-aligned text. Active state is driven by
        -- opts.activeIf (callback returning true for the currently-selected tab).
        btn.borderColor              = { r=0, g=0, b=0, a=0 }
        btn.backgroundColor          = { r=0, g=0, b=0, a=0 }
        btn.backgroundColorMouseOver = { r=0, g=0, b=0, a=0 }
        local activeIf = opts.activeIf or function() return false end

        btn.render = function(self2)
            local isActive = false
            pcall(function() isActive = activeIf() and true or false end)
            local alpha = self2.enable and 1.0 or 0.28
            local over  = false
            pcall(function() over = self2:isMouseOver() end)

            if isActive then
                self2:drawRect(0, 0, self2.width, self2.height, 0.12,
                    TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
                self2:drawRect(0, 0, 3, self2.height, alpha,
                    TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
            elseif over and self2.enable then
                self2:drawRect(0, 0, self2.width, self2.height, 0.06, 1, 1, 1)
            end

            local showFocus = self2.isFocused and self2.enable
                and ManualSave.InputNav and ManualSave.InputNav.keyboardActive
            if showFocus then
                self2:drawRect(0, 0, self2.width, self2.height,
                    TH.FOCUS_BG_A, TH.FOCUS_BG_R, TH.FOCUS_BG_G, TH.FOCUS_BG_B)
                for i = 0, TH.FOCUS_BW - 1 do
                    self2:drawRectBorder(i, i, self2.width - i*2, self2.height - i*2, 1,
                        TH.FOCUS_R, TH.FOCUS_G, TH.FOCUS_B)
                end
            end

            local fh  = TH.FONT_HGT_SMALL
            local ty2 = math.floor((self2.height - fh) / 2)
            local trR = isActive and TH.TEXT_R or TH.MUTED_R
            local trG = isActive and TH.TEXT_G or TH.MUTED_G
            local trB = isActive and TH.TEXT_B or TH.MUTED_B
            self2:drawText(self2:getTitle(), 14, ty2, trR, trG, trB, alpha, UIFont.Small)
        end

        if opts.enabled == false then btn:setEnable(false) end
        if parent then parent:addChild(btn) end
        btn.onActivate = opts.onClick
        if opts.focusGroup ~= false then
            local g = opts.focusGroup
            if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
                g = ManualSave.InputNav.findNavGroup(parent)
            end
            if g then g:add(btn) end
        end
        return finalizeButton(btn, opts)
    end

    -- Primary uses dark text on bright orange fill; when disabled the fill fades
    -- and dark-on-dark becomes invisible, so swap to light text. Other filled
    -- styles (danger-fill) keep their text colour because they remain readable
    -- at low alpha on the dark panel background.
    local needsDisabledTextSwap = (style == "primary")
    local dtR = needsDisabledTextSwap and TH.TEXT_R or tR
    local dtG = needsDisabledTextSwap and TH.TEXT_G or tG
    local dtB = needsDisabledTextSwap and TH.TEXT_B or tB

    btn.render = function(self2)
        local alpha = self2.enable and 1.0 or 0.28
        if filled then
            local fillAlpha = (self2.enable and 1.0 or 0.28) * fA
            self2:drawRect(0, 0, self2.width, self2.height, fillAlpha, fR, fG, fB)
            if self2.enable then
                local over = false
                pcall(function() over = self2:isMouseOver() end)
                if over then
                    self2:drawRect(0, 0, self2.width, self2.height, 0.12, 1, 1, 1)
                end
            end
        else
            if self2.enable then
                local over = false
                pcall(function() over = self2:isMouseOver() end)
                if over then
                    self2:drawRect(0, 0, self2.width, self2.height, 0.06, 1, 1, 1)
                end
            end
        end
        -- Focus visuals only render while keyboard / gamepad navigation mode is
        -- active. The mode toggles off as soon as the user touches the mouse.
        local showFocus = self2.isFocused and self2.enable and style ~= "info"
            and ManualSave.InputNav and ManualSave.InputNav.keyboardActive
        if showFocus then
            self2:drawRect(0, 0, self2.width, self2.height,
                TH.FOCUS_BG_A, TH.FOCUS_BG_R, TH.FOCUS_BG_G, TH.FOCUS_BG_B)
        end
        -- Normal border
        if style == "info" then
            ManualSave.Draw.circleBorder(self2, 1, 1, self2.width - 2, self2.height - 2, alpha, bR, bG, bB)
        else
            self2:drawRectBorder(0, 0, self2.width, self2.height, alpha, bR, bG, bB)
        end
        -- Focus ring on top of the normal border (thicker, brighter).
        if showFocus then
            for i = 0, TH.FOCUS_BW - 1 do
                self2:drawRectBorder(i, i, self2.width - i*2, self2.height - i*2, 1,
                    TH.FOCUS_R, TH.FOCUS_G, TH.FOCUS_B)
            end
        end
        local fh = getTextManager():getFontHeight(UIFont.Small)
        local tw = getTextManager():MeasureStringX(UIFont.Small, self2:getTitle())
        self2:drawText(
            self2:getTitle(),
            math.floor((self2.width  - tw) / 2),
            math.floor((self2.height - fh) / 2),
            self2.enable and tR or dtR,
            self2.enable and tG or dtG,
            self2.enable and tB or dtB,
            alpha, UIFont.Small)
    end

    if opts.onFocus      then btn.onFocus      = opts.onFocus      end
    if opts.onLostFocus  then btn.onLostFocus  = opts.onLostFocus  end
    if opts.onMouseDown  then btn.onMouseDown  = opts.onMouseDown  end
    if opts.onMouseUp    then btn.onMouseUp    = opts.onMouseUp    end
    if opts.onMouseMove  then btn.onMouseMove  = opts.onMouseMove  end
    if opts.onMouseWheel then btn.onMouseWheel = opts.onMouseWheel end
    if opts.onKeyPressed then btn.onKeyPressed = opts.onKeyPressed end
    if opts.onKeyRelease then btn.onKeyRelease = opts.onKeyRelease end
    if opts.update       then btn.update       = opts.update       end

    if opts.enabled == false then btn:setEnable(false) end
    if parent then parent:addChild(btn) end

    -- InputNav: expose onActivate (live click) and auto-register into the closest
    -- panel's focus group. opts.focusGroup forces an explicit group; passing
    -- false suppresses registration entirely (for non-navigable buttons).
    btn.onActivate = opts.onClick
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then g:add(btn) end
    end

    return finalizeButton(btn, opts)
end

-- Small circular info button. Opens a popup tooltip on click.
--
-- opts:
--   x, y    number
--   sz      number?   side length in px (default 20)
--   popW    number?   popup width (default 280)
--   color   "danger"|nil  border/text colour; nil → MUTED
--   lines   { [1]:string, [2]:string? }[]
--           style: "normal"|"dim"|"warn"|"header"
--
---@param parent ISPanel
---@param opts { x:number, y:number, sz:number?, popW:number?, color:string?, lines:table }
---@return { btn:ISButton }
function ManualSave.makeInfoButton(parent, opts)
    local TH   = ManualSave.Theme
    local sz   = opts.sz   or 20
    local popW = opts.popW or 280
    local lh   = TH.FONT_HGT_SMALL + 3
    local lines = opts.lines or {}
    local popH = TH.PAD * 2 + #lines * lh

    local colR, colG, colB
    if opts.color == "danger" then
        colR, colG, colB = TH.DANGER_R, TH.DANGER_G, TH.DANGER_B
    else
        colR, colG, colB = TH.MUTED_R, TH.MUTED_G, TH.MUTED_B
    end

    local btn = ISButton:new(opts.x, opts.y, sz, sz, "", parent, nil)
    btn:initialise()
    btn:instantiate()
    btn.backgroundColor          = { r=0, g=0, b=0, a=0 }
    btn.backgroundColorMouseOver = { r=0, g=0, b=0, a=0 }
    btn.borderColor              = { r=0, g=0, b=0, a=0 }
    btn.textColor                = { r=colR, g=colG, b=colB, a=1 }

    btn.render = function(self2)
        local sz2   = self2.width
        local alpha = self2.enable and 1.0 or 0.28
        local over  = false
        if self2.enable then pcall(function() over = self2:isMouseOver() end) end
        if over then
            self2:drawRect(0, 0, sz2, sz2, 0.10, colR, colG, colB)
        end
        local c = math.floor(sz2 / 2)
        ManualSave.Draw.pixelCircle(self2, c, c, c - 2, alpha, colR, colG, colB)
        local fh = getTextManager():getFontHeight(UIFont.Small)
        local tw = getTextManager():MeasureStringX(UIFont.Small, "i")
        self2:drawText("i",
            math.floor((sz2 - tw) / 2),
            math.floor((sz2 - fh) / 2) + 1,
            colR, colG, colB, alpha, UIFont.Small)
    end

    local _activePopup = nil

    btn.onclick = function(_)
        if _activePopup then
            pcall(_activePopup.close)
            _activePopup = nil
            return
        end
        local dynW = popW
        for _, l in ipairs(lines) do
            if l[1] and l[1] ~= "" then
                local tw = getTextManager():MeasureStringX(UIFont.Small, l[1])
                if tw + TH.PAD * 2 > dynW then dynW = tw + TH.PAD * 2 end
            end
        end
        local ax = btn:getAbsoluteX() + sz + 4
        local ay = btn:getAbsoluteY()
        local popup = ManualSave.makePopupPanel({
            w=dynW, h=popH, anchorX=ax, anchorY=ay,
        })
        _activePopup = popup
        popup.onClose(function() _activePopup = nil end)
        local pp = popup.panel
        pp.prerender = function(self2)
            ISPanel.prerender(self2)
            local cy = TH.PAD
            for _, l in ipairs(lines) do
                if l[1] ~= "" then
                    local r, g, b
                    local sty = l[2] or "normal"
                    if     sty == "warn"   then r,g,b = TH.DANGER_R, TH.DANGER_G, TH.DANGER_B
                    elseif sty == "dim"    then r,g,b = TH.DIM_R,    TH.DIM_G,    TH.DIM_B
                    elseif sty == "header" then r,g,b = TH.TEXT_R,   TH.TEXT_G,   TH.TEXT_B
                    else                        r,g,b = TH.MUTED_R,  TH.MUTED_G,  TH.MUTED_B
                    end
                    self2:drawText(l[1], TH.PAD, cy, r, g, b, 1, UIFont.Small)
                end
                cy = cy + lh
            end
        end
        popup.open()
    end

    if parent then parent:addChild(btn) end
    return { btn = btn }
end

-- Checkbox-style toggle card. Background, border, checkbox glyph, label, and
-- description text are all rendered internally; callers pass no prerender.
--
-- opts:
--   x, y        number
--   w, h        number
--   label       string       main toggle label
--   desc        string       smaller description line below label
--   getValue    fun():bool   current toggle state
--   onToggle    fun()        called when the card is clicked
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, label:string, desc:string, getValue:fun():boolean, onToggle:fun() }
---@return ISPanel
function ManualSave.makeToggleCard(parent, opts)
    local TH    = ManualSave.Theme
    local FHS   = TH.FONT_HGT_SMALL
    local label = opts.label or ""
    local desc  = opts.desc  or ""
    local card = ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y or 0, w=opts.w, h=opts.h,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
        prerender = function(fc)
            local isOn = opts.getValue and opts.getValue()
            if isOn then
                fc:drawRect(0, 0, fc.width, fc.height, 1,
                    TH.DANGER_R*0.20, TH.DANGER_G*0.10, TH.DANGER_B*0.10)
                fc:drawRectBorder(0, 0, fc.width, fc.height, 1,
                    TH.DANGER_R*0.75, TH.DANGER_G*0.40, TH.DANGER_B*0.35)
            else
                fc:drawRect(0, 0, fc.width, fc.height, 1, 0.07, 0.05, 0.05)
                fc:drawRectBorder(0, 0, fc.width, fc.height, 1,
                    TH.LINE_R*0.6, TH.LINE_G*0.6, TH.LINE_B*0.6)
            end
            -- Focus ring shown only while keyboard / gamepad mode is active.
            if fc.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
                fc:drawRect(0, 0, fc.width, fc.height,
                    TH.FOCUS_BG_A, TH.FOCUS_BG_R, TH.FOCUS_BG_G, TH.FOCUS_BG_B)
                for i = 0, TH.FOCUS_BW - 1 do
                    fc:drawRectBorder(i, i, fc.width - i*2, fc.height - i*2, 1,
                        TH.FOCUS_R, TH.FOCUS_G, TH.FOCUS_B)
                end
            end
            local cbSz = 13
            local cbY2 = 4 + math.floor((FHS - cbSz) / 2)
            ManualSave.Draw.checkbox(fc, 10, cbY2, cbSz, isOn)
            local cbW = cbSz + 8
            fc:drawText(label, 10 + cbW, 4,
                isOn and TH.TEXT_R or TH.MUTED_R,
                isOn and TH.TEXT_G or TH.MUTED_G,
                isOn and TH.TEXT_B or TH.MUTED_B, 1, UIFont.Small)
            fc:drawText(desc, 10 + cbW, 4 + FHS + 2,
                TH.DIM_R, TH.DIM_G, TH.DIM_B, isOn and 0.9 or 0.55, UIFont.Small)
        end,
        onMouseDown = function()
            if opts.onToggle then opts.onToggle() end
            return true
        end,
    })
    card.onActivate = opts.onToggle
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then g:add(card) end
    end
    return card
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Button.lua loaded.")
