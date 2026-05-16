-- UI/Base/Elements/MiniList.lua
-- Compact scrollable list with a header label.
-- Used in MoreScreen for MAP and MODS columns.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- Creates a scrollable mini-list and adds it to parent.
--
-- opts:
--   x, y, w      number
--   maxRows      number          visible rows before scrolling
--   label        string          header text (e.g. "MODS (3)")
--   items        table           array of values passed to drawRow
--   drawRow      fun(panel, item, x, y, maxW)
--   onExpand     fun()?          called when user clicks the header area
--
---@param parent ISPanel
---@param opts table
---@return ISPanel
function ManualSave.makeMiniList(parent, opts)
    local TH    = ManualSave.Theme
    local FHS   = TH.FONT_HGT_SMALL
    local rowH  = FHS + 4
    local hdrH  = FHS + 8
    local items = opts.items
    local nRows = opts.maxRows
    local boxH  = hdrH + rowH * nRows + 6

    local p = ISPanel:new(opts.x or 0, opts.y or 0, opts.w, boxH)
    p.backgroundColor = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }
    p.borderColor     = { r=TH.LINE_R,  g=TH.LINE_G,  b=TH.LINE_B,  a=1 }
    p:initialise(); p:instantiate()
    p.scrollIdx = 0

    p.prerender = function(pb)
        ISPanel.prerender(pb)
        ManualSave.Draw.accentBar(pb, 0, 0, pb.width, 2, true)
        pb:drawText(opts.label, 8, 4, TH.DIM_R, TH.DIM_G, TH.DIM_B, 0.8, UIFont.Small)
        if opts.onExpand then
            local iconSize = 9
            local over = false
            pcall(function()
                local mx, my = pb:getMouseX(), pb:getMouseY()
                over = mx >= 0 and mx < pb.width and my >= 0 and my < pb.height
            end)
            local ix = pb.width - iconSize - math.floor((hdrH - iconSize) / 2) - 6
            local iy = math.floor((hdrH - iconSize) / 2)
            ManualSave.Draw.expandIcon(pb, ix, iy, iconSize, over and 0.85 or 0.4,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B)
        end
        local iy = hdrH
        for i = 1, nRows do
            local idx = pb.scrollIdx + i
            if idx > #items then break end
            opts.drawRow(pb, items[idx], 8, iy, opts.w - 20)
            iy = iy + rowH
        end
        if #items > nRows then
            local ms   = #items - nRows
            local trkH = pb.height - 8
            local thH  = math.max(math.floor(trkH * nRows / #items), 12)
            local thY  = 4 + math.floor((trkH - thH) * pb.scrollIdx / ms)
            local sbX  = pb.width - 6
            pb:drawRect(sbX, 4,   6, trkH, 0.18, TH.MUTED_R, TH.MUTED_G, TH.MUTED_B)
            pb:drawRect(sbX, thY, 6, thH,  0.65, TH.MUTED_R, TH.MUTED_G, TH.MUTED_B)
        end
    end

    local dragging = false
    local dragStart, dragY = 0, 0

    p.onMouseDown = function(pb, mx, my)
        if #items > nRows and mx >= pb.width - 10 then
            dragging = true; dragY = my; dragStart = pb.scrollIdx
            return true
        end
        if opts.onExpand then
            pcall(opts.onExpand)
            return true
        end
    end

    if #items > nRows then
        p.onMouseWheel = function(pb, del)
            pb.scrollIdx = math.max(0, math.min(#items - nRows, pb.scrollIdx - del))
            return true
        end
        p.onMouseMove = function(pb)
            if dragging and isMouseButtonDown(0) then ---@diagnostic disable-line
                local ms = #items - nRows
                pb.scrollIdx = math.max(0, math.min(ms,
                    math.floor(dragStart + (pb:getMouseY() - dragY) * ms / (pb.height - 8))))
            end
        end
        p.onMouseUp = function() dragging = false end
    end

    if parent then parent:addChild(p) end
    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/MiniList.lua loaded.")
