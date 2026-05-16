-- UI/Base/Widgets/Elements/Dropdown.lua
-- Single-select dropdown. Trigger button opens a floating list below (or above).
-- Click-outside closes via a transparent full-screen backdrop panel.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

-- Creates a styled dropdown and adds it to parent.
--
-- opts:
--   x, y, w, h    number
--   items         {id:string, label:string}[]
--   value         string?   initial selected id  (default: first item's id)
--   placeholder   string?   label when nothing is selected
--   onChange      fun(id:string, label:string)?
--
-- returns: { getValue:fun():string, setValue:fun(id:string), setItems:fun(items:table) }
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, items:table, value:string?, placeholder:string?, onChange:fun(id:string,label:string)? }
---@return { getValue:fun():string, setValue:fun(id:string), setItems:fun(items:table) }
function ManualSave.makeDropdown(parent, opts)
    local TH    = ManualSave.Theme
    local items = opts.items or {}
    local selId = opts.value or (items[1] and items[1].id or "")

    local _popup    = nil
    local _backdrop = nil

    local function getCurrentLabel()
        for _, it in ipairs(items) do
            if it.id == selId then return it.label end
        end
        return opts.placeholder or ""
    end

    local function closePopup()
        if _popup then
            pcall(function() _popup:setVisible(false); _popup:removeFromUIManager() end)
            _popup = nil
        end
        if _backdrop then
            pcall(function() _backdrop:setVisible(false); _backdrop:removeFromUIManager() end)
            _backdrop = nil
        end
    end

    -- Trigger panel renders current label + chevron and opens popup on click.
    ManualSave.makePanel(parent, {
        x = opts.x, y = opts.y, w = opts.w, h = opts.h,
        bg     = { r=0, g=0, b=0, a=0 },
        border = { r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 },
        prerender = function(tp)
            local over = false
            pcall(function() over = tp:isMouseOver() end)
            if over then tp:drawRect(0, 0, tp.width, tp.height, 0.06, 1, 1, 1) end
            local fh  = getTextManager():getFontHeight(UIFont.Small)
            local lbl = getCurrentLabel()
            local ty  = math.floor((tp.height - fh) / 2)
            tp:drawText(lbl, TH.PAD, ty, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Small)
            -- Downward triangle chevron (4 rows: 8, 6, 4, 2 px wide)
            local tW = 8
            local tX = tp.width - TH.PAD - tW
            local tY = math.floor((tp.height - 4) / 2)
            for i = 0, 3 do
                local rw = tW - i * 2
                tp:drawRect(tX + i, tY + i, rw, 1, 0.65, TH.MUTED_R, TH.MUTED_G, TH.MUTED_B)
            end
        end,
        onMouseDown = function(tp, _, _)
            if _popup then closePopup(); return end

            local sw   = getCore():getScreenWidth()
            local sh   = getCore():getScreenHeight()
            local rh   = TH.FONT_HGT_SMALL + 10
            local popH = math.min(280, #items * rh + 2)
            local ax   = tp:getAbsoluteX()
            local ay   = tp:getAbsoluteY() + tp.height + 2
            if ay + popH > sh then ay = tp:getAbsoluteY() - popH - 2 end

            -- Full-screen transparent backdrop: click-outside closes popup
            local bd = ISPanel:new(0, 0, sw, sh)
            bd.backgroundColor = { r=0, g=0, b=0, a=0 }
            bd.borderColor     = { r=0, g=0, b=0, a=0 }
            bd:initialise(); bd:instantiate()
            bd.onMouseDown = function(_, _, _) closePopup() end
            bd:addToUIManager()
            bd:setVisible(true)
            _backdrop = bd

            -- Snapshot trigger position so we can detect parent panel drags.
            local snapX = tp:getAbsoluteX()
            local snapY = tp:getAbsoluteY()

            -- Popup container (no border — the scrollList fills it flush to avoid gaps)
            local pp = ISPanel:new(ax, ay, opts.w, popH)
            pp.backgroundColor = { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }
            pp.borderColor     = { r=0, g=0, b=0, a=0 }
            pp:initialise(); pp:instantiate()
            pp.update = function(self2)
                ISPanel.update(self2)
                self2:bringToTop()
                if tp:getAbsoluteX() ~= snapX or tp:getAbsoluteY() ~= snapY then
                    closePopup()
                end
            end

            local sl = ManualSave.makeScrollList(pp, {
                x=0, y=0, w=opts.w, h=popH,
                rowH  = rh,
                items = items,
                bg    = { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B },
                drawRow = function(panel, item, x, y, w, h, _, _)
                    local isSel = item.id == selId
                    if isSel then
                        panel:drawRect(x, y, w, h, 0.15, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
                    end
                    local fh = getTextManager():getFontHeight(UIFont.Small)
                    local tr = isSel and TH.ACCENT_R or TH.TEXT_R
                    local tg = isSel and TH.ACCENT_G or TH.TEXT_G
                    local tb = isSel and TH.ACCENT_B or TH.TEXT_B
                    panel:drawText(item.label, x + TH.PAD, y + math.floor((h - fh) / 2),
                        tr, tg, tb, 1, UIFont.Small)
                    ManualSave.Draw.separator(panel, x, y + h - 1, w, 0.12)
                end,
                onSelect = function(item, _)
                    selId = item.id
                    if opts.onChange then opts.onChange(selId, item.label) end
                    closePopup()
                end,
            })
            sl.panel.borderColor = { r=0, g=0, b=0, a=0 }

            pp:addToUIManager()
            pp:setVisible(true)
            pp:bringToTop()
            _popup = pp
        end,
    })

    local obj = {}

    function obj.getValue() return selId end

    function obj.setValue(id)
        for _, it in ipairs(items) do
            if it.id == id then selId = id; return end
        end
    end

    -- Replaces the item list; resets selection to first item if current id no longer exists.
    function obj.setItems(newItems)
        items = newItems
        local found = false
        for _, it in ipairs(items) do
            if it.id == selId then found = true; break end
        end
        if not found and items[1] then
            selId = items[1].id
            if opts.onChange then opts.onChange(selId, items[1].label) end
        end
        if _popup then closePopup() end
    end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Dropdown.lua loaded.")
