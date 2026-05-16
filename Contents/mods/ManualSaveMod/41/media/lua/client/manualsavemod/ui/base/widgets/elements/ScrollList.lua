-- UI/Base/ScrollList.lua
-- Virtualised scroll list. Renders only visible rows via a caller-supplied
-- drawRow function. Handles mouse wheel, drag scrollbar, and click selection.
-- Adds itself to parent automatically.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

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
--   onSelect    fun(item, idx)?   called when user clicks a row
--   onActivate  fun(item, idx)?   called on double-click
--   bg          {r,g,b}?          override panel background (default TH.BG)
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

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/ScrollList.lua loaded.")
