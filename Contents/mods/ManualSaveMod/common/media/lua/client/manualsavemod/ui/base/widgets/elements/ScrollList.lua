-- UI/Base/ScrollList.lua
-- Virtualised scroll list. Renders only visible rows via a caller-supplied
-- drawRow function. Handles mouse wheel, drag scrollbar, and click selection.
-- Adds itself to parent automatically.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, unused-local

ManualSave = ManualSave or {}

-- Creates a scroll list and adds it to parent.
--
-- opts:
--   x, y        number
--   w, h        number
--   rowH        number            height of each row in pixels
--   items       table             initial item list (can be replaced via obj.setItems)
--   drawRow     fun(panel, item, x, y, w, h, selected:boolean, idx:number)
--               called for every visible row during prerender.
--               panel is the list's ISPanel — call panel:drawText / panel:drawRect etc.
--   onSelect      fun(item, idx)?    called on mouse single-click (side effects OK)
--   onNavigate    fun(item, idx)?    called on keyboard arrow navigation (silent)
--   onActivate    fun(item, idx)?    called on double-click OR Enter while focused
--   isSelectable  fun(item):boolean? if set, items where it returns false are
--                                    skipped by arrow nav AND ignored on mouse
--                                    click (used by HelpNav to skip category headers)
--   bg            {r,g,b}?           override panel background (default TH.BG)
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, rowH:number, items:table, drawRow:fun(panel:ISPanel,item:any,x:number,y:number,w:number,h:number,selected:boolean,idx:number), onSelect:fun(item:any,idx:number)?, onActivate:fun(item:any,idx:number)?, bg:{r:number,g:number,b:number}? }
---@return { panel:ISPanel, setItems:fun(t:table, keepScroll:boolean?), getSelected:fun():any, setSelected:fun(idx:number), clearSelection:fun(), scrollToIndex:fun(idx:number) }
function ManualSave.makeScrollList(parent, opts)
    local TH     = ManualSave.Theme
    local SCROLL = 12   -- scrollbar width

    local bgR = opts.bg and opts.bg.r or TH.BG_R
    local bgG = opts.bg and opts.bg.g or TH.BG_G
    local bgB = opts.bg and opts.bg.b or TH.BG_B

    local items    = opts.items or {}
    local scrollY  = 0
    local selected = 0   -- 1-based index; 0 = none
    local lastClickIdx = 0
    local lastClickTime = 0

    local p = ISPanel:new(opts.x, opts.y, opts.w, opts.h)
    p.backgroundColor = { r=bgR, g=bgG, b=bgB, a=1 }
    p.borderColor     = { r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 }
    p:initialise()
    p:instantiate()

    local function maxScroll()
        return math.max(0, #items * opts.rowH - opts.h)
    end

    local function clampScroll()
        scrollY = math.max(0, math.min(scrollY, maxScroll()))
    end

    local function visibleRows()
        return math.floor(opts.h / opts.rowH)
    end

    -- Scrollbar geometry
    local function sbThumb()
        local total = #items * opts.rowH
        if total <= opts.h then return 0, opts.h end  -- no scrollbar needed
        local ratio = opts.h / total
        local thumbH = math.max(20, math.floor(opts.h * ratio))
        local thumbY = math.floor((opts.h - thumbH) * (scrollY / maxScroll()))
        return thumbY, thumbH
    end

    local sbDragging = false
    local sbDragStartY = 0
    local sbDragStartScroll = 0

    p.prerender = function(self2)
        ISPanel.prerender(self2)

        local rowW     = opts.w - SCROLL - 1
        local firstRow = math.floor(scrollY / opts.rowH) + 1  -- 1-based
        local vis      = visibleRows() + 2

        local mx, my = -1, -1
        pcall(function() mx, my = self2:getMouseX(), self2:getMouseY() end)

        self2:setStencilRect(0, 0, self2.width, self2.height)
        for i = firstRow, math.min(firstRow + vis, #items) do
            local item = items[i]
            if not item then break end
            local ry = (i - 1) * opts.rowH - scrollY
            if ry + opts.rowH >= 0 and ry <= opts.h then
                if i ~= selected and mx >= 0 and mx < rowW and my >= ry and my < ry + opts.rowH then
                    self2:drawRect(0, ry, rowW, opts.rowH, 0.05, 1, 1, 1)
                end
                opts.drawRow(self2, item, 0, ry, rowW, opts.rowH, (i == selected), i)
            end
        end
        self2:clearStencilRect()

        -- Scrollbar track
        local total = #items * opts.rowH
        if total > opts.h then
            local sx = opts.w - SCROLL
            self2:drawRect(sx, 0, SCROLL, opts.h, 0.5, TH.LINE_R, TH.LINE_G, TH.LINE_B)
            local thumbY, thumbH = sbThumb()
            local hover = mx >= sx and my >= thumbY and my <= thumbY + thumbH
            local ta = hover and 0.7 or 0.45
            self2:drawRect(sx + 2, thumbY + 1, SCROLL - 4, thumbH - 2, ta,
                TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
        end

        -- InputNav focus ring: drawn last so it sits on top of all content.
        -- Only shown while keyboard / gamepad navigation mode is active.
        if self2.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
            for i = 0, TH.FOCUS_BW - 1 do
                self2:drawRectBorder(i, i, self2.width - i*2, self2.height - i*2, 1,
                    TH.FOCUS_R, TH.FOCUS_G, TH.FOCUS_B)
            end
        end
    end

    -- Mouse wheel
    p.onMouseWheel = function(self2, delta)
        scrollY = scrollY - delta * opts.rowH
        clampScroll()
        return true
    end

    -- Click: select row or drag scrollbar
    p.onMouseDown = function(self2, mx, my)
        local sx = opts.w - SCROLL
        if mx >= sx and #items * opts.rowH > opts.h then
            -- Scrollbar drag start
            sbDragging = true
            sbDragStartY = my
            sbDragStartScroll = scrollY
            return true
        end

        -- Row click
        local rowIdx = math.floor((my + scrollY) / opts.rowH) + 1
        if rowIdx >= 1 and rowIdx <= #items then
            -- Skip non-selectable rows (e.g. HelpNav category headers).
            if opts.isSelectable then
                local item = items[rowIdx]
                local ok, sel = pcall(opts.isSelectable, item)
                if ok and sel == false then return true end
            end
            local now = getTimestampMs and getTimestampMs() or 0
            local dbl = (rowIdx == lastClickIdx) and (now - lastClickTime < 400)
            lastClickIdx  = rowIdx
            lastClickTime = now
            selected = rowIdx
            if dbl and opts.onActivate then
                pcall(opts.onActivate, items[rowIdx], rowIdx)
            elseif opts.onSelect then
                pcall(opts.onSelect, items[rowIdx], rowIdx)
            end
        end
        return true
    end

    p.onMouseMove = function(self2, dx, dy)
        if sbDragging then
            if not isMouseButtonDown(0) then ---@diagnostic disable-line
                sbDragging = false
                return
            end
            local ms = maxScroll()
            if ms > 0 then
                local trackH = opts.h
                local _, thumbH = sbThumb()
                local ratio = ms / (trackH - thumbH)
                scrollY = sbDragStartScroll + (self2:getMouseY() - sbDragStartY) * ratio
                clampScroll()
            end
        end
    end

    p.onMouseUp = function(self2, mx, my)
        sbDragging = false
    end

    if parent then parent:addChild(p) end

    -- InputNav auto-register: the scroll list panel is a single navigable item
    -- in the parent screen's nav group. Up/Down arrows are handled internally
    -- via p.onArrow, and Enter activates the selected item via p.onActivate.
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then g:add(p) end
    end

    local obj = { panel = p }

    ---@param t table
    ---@param keepScroll boolean? preserve current scroll position (default false)
    function obj.setItems(t, keepScroll)
        items = t
        if keepScroll then clampScroll() else scrollY = 0 end
        selected = 0
    end

    ---@return any
    function obj.getSelected()
        if selected >= 1 and selected <= #items then return items[selected] end
        return nil
    end

    ---@param idx number
    function obj.setSelected(idx)
        selected = idx
    end

    function obj.clearSelection()
        selected = 0
    end

    ---@param idx number
    function obj.scrollToIndex(idx)
        local targetY = (idx - 1) * opts.rowH
        scrollY = targetY
        clampScroll()
    end

    -- Ensure the row at `idx` is visible (scrolls just enough if it is above/below).
    local function ensureVisible(idx)
        local top    = (idx - 1) * opts.rowH
        local bottom = top + opts.rowH
        if top < scrollY then scrollY = top
        elseif bottom > scrollY + opts.h then scrollY = bottom - opts.h
        end
        clampScroll()
    end

    -- Returns true if the row at `idx` should accept selection / activation.
    -- Honors opts.isSelectable (default: every row is selectable).
    local function isSelectable(idx)
        if not opts.isSelectable then return true end
        local item = items[idx]
        if not item then return false end
        local ok, sel = pcall(opts.isSelectable, item)
        return ok and (sel ~= false)
    end

    -- Move selection by `delta` with wrap-around at both ends, skipping
    -- non-selectable rows (e.g. category headers). Scrolls if needed and fires
    -- onNavigate. Mouse single-click fires onSelect via the onMouseDown handler.
    local function moveSelection(delta)
        if #items == 0 then return end
        local step = (delta > 0) and 1 or -1
        local start
        if selected == 0 then
            start = (delta > 0) and 1 or #items
        else
            start = selected + step
        end
        local newSel = start
        local safety = #items
        while safety > 0 do
            if newSel < 1 then newSel = #items
            elseif newSel > #items then newSel = 1
            end
            if isSelectable(newSel) then break end
            newSel = newSel + step
            safety = safety - 1
        end
        if safety <= 0 then return end       -- no selectable row anywhere
        if newSel == selected then return end
        selected = newSel
        ensureVisible(selected)
        if opts.onNavigate then pcall(opts.onNavigate, items[selected], selected) end
    end

    function obj.selectNext() moveSelection(1)  end
    function obj.selectPrev() moveSelection(-1) end

    function obj.activateSelected()
        if selected < 1 or selected > #items then return end
        if opts.onActivate then pcall(opts.onActivate, items[selected], selected) end
    end

    -- InputNav hooks: when the list panel is the focused widget in a FocusGroup,
    -- Up/Down move the internal selection (returning true keeps focus inside),
    -- Left/Right fall through so the group's onExit can hand off to a sibling.
    p.onArrow = function(_, direction)
        if direction == "up"   then moveSelection(-1); return true end
        if direction == "down" then moveSelection(1);  return true end
        return false
    end
    p.onActivate = obj.activateSelected

    -- Right-stick continuous scroll: called by AnalogStick every tick while
    -- this panel is the focused widget and the right stick is tilted past the
    -- deadzone. dy is in pixels (already scaled by stick magnitude and tick
    -- duration). Returns true to mark the scroll as consumed.
    p.onAnalogScroll = function(_, _, dy)
        if not dy or dy == 0 then return false end
        scrollY = scrollY + dy
        clampScroll()
        return true
    end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/ScrollList.lua loaded.")
