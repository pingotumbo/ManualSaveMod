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

    local _popup     = nil
    local _backdrop  = nil
    local _popupNav  = nil   -- temporary FocusManager pushed while popup is open
    local triggerPanel        -- forward declaration

    local function getCurrentLabel()
        for _, it in ipairs(items) do
            if it.id == selId then return it.label end
        end
        return opts.placeholder or ""
    end

    local function closePopup()
        if _popupNav and ManualSave.InputNav and ManualSave.InputNav.popActive then
            ManualSave.InputNav.popActive(_popupNav)
            _popupNav = nil
        end
        if _popup then
            pcall(function() _popup:setVisible(false); _popup:removeFromUIManager() end)
            _popup = nil
        end
        if _backdrop then
            pcall(function() _backdrop:setVisible(false); _backdrop:removeFromUIManager() end)
            _backdrop = nil
        end
    end

    local function openPopup()
        if _popup then closePopup(); return end
        if not triggerPanel then return end

        local sw   = getCore():getScreenWidth()
        local sh   = getCore():getScreenHeight()
        local rh   = TH.FONT_HGT_SMALL + 10
        local popH = math.min(280, #items * rh + 2)
        local ax   = triggerPanel:getAbsoluteX()
        local ay   = triggerPanel:getAbsoluteY() + triggerPanel.height + 2
        if ay + popH > sh then ay = triggerPanel:getAbsoluteY() - popH - 2 end

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
        local snapX = triggerPanel:getAbsoluteX()
        local snapY = triggerPanel:getAbsoluteY()

        local pp = ISPanel:new(ax, ay, opts.w, popH)
        pp.backgroundColor = { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }
        pp.borderColor     = { r=0, g=0, b=0, a=0 }
        pp:initialise(); pp:instantiate()
        pp.update = function(self2)
            ISPanel.update(self2)
            self2:bringToTop()
            if triggerPanel:getAbsoluteX() ~= snapX or triggerPanel:getAbsoluteY() ~= snapY then
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
            onActivate = function(item, _)
                selId = item.id
                if opts.onChange then opts.onChange(selId, item.label) end
                closePopup()
            end,
            focusGroup = false,   -- registered manually into popup-private group
        })
        sl.panel.borderColor = { r=0, g=0, b=0, a=0 }

        pp:addToUIManager()
        pp:setVisible(true)
        pp:bringToTop()
        _popup = pp

        -- Pre-position the internal cursor on the currently selected id so
        -- Up/Down feels natural starting from the right place.
        for i, it in ipairs(items) do
            if it.id == selId then
                if sl.setSelected then sl.setSelected(i) end
                if sl.scrollToIndex then sl.scrollToIndex(i) end
                break
            end
        end

        -- Build a private FocusManager + group for the popup so the surrounding
        -- screen's nav doesn't fight us. The scroll list is the only navigable
        -- item; Up/Down inside it cycles options (ScrollList.onArrow handles
        -- it), Enter activates, Esc/B closes.
        if ManualSave.InputNav and ManualSave.InputNav.buildManager then
            local mgr, groups = ManualSave.InputNav.buildManager({
                { id="dropdownPopup", layout="vertical", wrap=true },
            }, {})
            groups[1]:add(sl.panel)
            mgr.onCancel = function() closePopup() end
            ManualSave.InputNav.pushActive(mgr)
            -- Focus the scroll list panel so its onArrow receives Up/Down.
            -- Silent so we don't play the nav sound just for opening.
            groups[1]:focusFirst(true)
            _popupNav = mgr
        end
    end

    -- Trigger panel renders current label + chevron and opens popup on
    -- click / Enter / A. Registers itself in the surrounding panel's focus
    -- group so keyboard / joypad nav can reach it.
    triggerPanel = ManualSave.makePanel(parent, {
        x = opts.x, y = opts.y, w = opts.w, h = opts.h,
        bg     = { r=0, g=0, b=0, a=0 },
        border = { r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 },
        prerender = function(tp)
            local TH2 = ManualSave.Theme
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
            -- Focus ring (drawn last; only while keyboard / gamepad mode is active)
            if tp.isFocused and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
                for i = 0, TH2.FOCUS_BW - 1 do
                    tp:drawRectBorder(i, i, tp.width - i*2, tp.height - i*2, 1,
                        TH2.FOCUS_R, TH2.FOCUS_G, TH2.FOCUS_B)
                end
            end
        end,
        onMouseDown = function(_, _, _) openPopup() end,
    })
    -- Keyboard / joypad: Enter or A opens the popup.
    triggerPanel.onActivate = openPopup

    -- Auto-register into the parent's nav group (walk-up). opts.focusGroup=false
    -- skips registration; an explicit FocusGroup overrides walk-up.
    if opts.focusGroup ~= false then
        local g = opts.focusGroup
        if not g and ManualSave.InputNav and ManualSave.InputNav.findNavGroup then
            g = ManualSave.InputNav.findNavGroup(parent)
        end
        if g then g:add(triggerPanel) end
    end

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
