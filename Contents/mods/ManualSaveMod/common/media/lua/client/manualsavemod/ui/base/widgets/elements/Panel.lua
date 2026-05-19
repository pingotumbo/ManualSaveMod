-- UI/Base/Elements/Panel.lua
-- Generic panel factory. Eliminates the ISPanel:new() boilerplate
-- that repeats across every screen.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, undefined-field, need-check-nil

ManualSave = ManualSave or {}

-- Creates a styled ISPanel, wires optional callbacks, adds it to parent,
-- and returns the raw ISPanel.
--
-- opts:
--   x, y, w, h     number
--   bg             {r,g,b,a}?  default: Theme BG (a=1)
--   border         {r,g,b,a}?  default: Theme LINE; pass false for no border
--   prerender      fun(p)?     called AFTER ISPanel.prerender — no need to call it manually
--   onMouseDown    fun(p, mx, my)?
--   onMouseUp      fun(p, mx, my)?
--   onMouseMove    fun(p, dx, dy)?
--   onMouseWheel   fun(p, delta)?
--   onFocus        fun(p, x, y)?
--   onLostFocus    fun(p, x, y)?
--   onKeyPressed   fun(p, key)?
--   onKeyRelease   fun(p, key)?
--   update         fun(p)?
--
---@param parent ISPanel?
---@param opts table
---@return ISPanel
function ManualSave.makePanel(parent, opts)
    local TH = ManualSave.Theme

    local bg = opts.bg or { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }
    local bd
    if opts.border == false then
        bd = { r=0, g=0, b=0, a=0 }
    else
        bd = opts.border or { r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 }
    end

    local p = ISPanel:new(opts.x or 0, opts.y or 0, opts.w, opts.h)
    p.backgroundColor = bg
    p.borderColor     = bd
    p:initialise()
    p:instantiate()

    if opts.prerender then
        local fn = opts.prerender
        p.prerender = function(self2)
            ISPanel.prerender(self2)
            fn(self2)
        end
    end

    if opts.onMouseDown  then p.onMouseDown  = opts.onMouseDown  end
    if opts.onMouseUp    then p.onMouseUp    = opts.onMouseUp    end
    if opts.onMouseMove  then p.onMouseMove  = opts.onMouseMove  end
    if opts.onMouseWheel then p.onMouseWheel = opts.onMouseWheel end
    if opts.onFocus      then p.onFocus      = opts.onFocus      end
    if opts.onLostFocus  then p.onLostFocus  = opts.onLostFocus  end
    if opts.onKeyPressed then p.onKeyPressed = opts.onKeyPressed end
    if opts.onKeyRelease then p.onKeyRelease = opts.onKeyRelease end
    if opts.update       then p.update       = opts.update       end

    if parent then parent:addChild(p) end
    return p
end

-- Creates a panel that immediately hides a set of target elements and
-- restores them when destroy() is called.  Used to implement cover panels
-- (e.g. MoreScreen overlaying LoadScreen detail area) without scattering
-- setVisible calls across screen files.
--
-- opts: all makePanel opts plus:
--   hideTargets  ISPanel|ISButton[]?   elements to hide/restore
--
---@param parent ISPanel?
---@param opts table
---@return { panel:ISPanel, destroy:fun() }
function ManualSave.makeCoverPanel(parent, opts)
    local targets    = opts.hideTargets or {}
    local prevVis    = {}

    -- Snapshot visibility and hide each target
    for i, t in ipairs(targets) do
        if t then
            local ok, v = pcall(function() return t:isVisible() end)
            prevVis[i] = ok and v or true
            if prevVis[i] then pcall(function() t:setVisible(false) end) end
        end
    end

    local panel = ManualSave.makePanel(parent, opts)

    local obj = { panel = panel }

    -- InputNav integration: cover panels SHARE the surrounding screen's nav
    -- group rather than isolating, so widgets that remain visible under the
    -- cover (e.g. the LoadScreen footer buttons that MoreScreen keeps showing)
    -- stay reachable by keyboard alongside the cover's own widgets.
    --
    -- Three pieces:
    --   1. Expose the parent group on the cover so child widgets walking up
    --      via findNavGroup land here and register into the parent group.
    --   2. Snapshot the parent group size; on destroy, remove every widget
    --      added during the cover's lifetime (avoids stale references after
    --      the cover sub-tree is gone).
    --   3. Temporarily override the parent manager's onCancel so Esc closes
    --      the cover rather than the surrounding screen; restored on destroy.
    local IN           = ManualSave.InputNav
    local parentGroup  = IN and IN.findNavGroup(parent)   or nil
    local parentMgr    = IN and IN.findNavManager(parent) or nil
    local initialCount = parentGroup and #parentGroup.items or 0
    panel._inputNavGroup = parentGroup
    panel._inputNav      = parentMgr

    local prevOnCancel = nil
    if parentMgr then
        prevOnCancel = parentMgr.onCancel
        parentMgr.onCancel = function() obj.destroy() end
    end

    -- Spatial auto-hide: hide every nav-registered widget that overlaps the
    -- cover's bounding box. Avoids hardcoding "hideTargets" lists in callers —
    -- the cover panel just claims its rectangle and any pre-existing navigable
    -- widget under it is hidden automatically. Widgets OUTSIDE the cover area
    -- (e.g. footer buttons below it) can still be hidden via opts.hideTargets.
    local autoPrev = {}
    if parentGroup then
        local cx = tonumber(opts.x) or 0
        local cy = tonumber(opts.y) or 0
        local cw = tonumber(opts.w) or 0
        local ch = tonumber(opts.h) or 0
        for _, w in ipairs(parentGroup.items) do
            local inCover = false
            pcall(function()
                local wx = tonumber(w:getX())     or 0
                local wy = tonumber(w:getY())     or 0
                local ww = tonumber(w:getWidth()) or 0
                local wh = tonumber(w:getHeight()) or 0
                inCover = wx < cx + cw and wx + ww > cx
                      and wy < cy + ch and wy + wh > cy
            end)
            if inCover then
                local ok, v = pcall(function() return w:isVisible() end)
                if ok and v then
                    autoPrev[w] = true
                    pcall(function() w:setVisible(false) end)
                end
            end
        end
    end

    function obj.destroy()
        if parentMgr then parentMgr.onCancel = prevOnCancel end
        if parentGroup then
            while #parentGroup.items > initialCount do
                local last = parentGroup.items[#parentGroup.items]
                parentGroup:remove(last)
            end
        end
        if parent then pcall(function() parent:removeChild(panel) end) end
        for i, t in ipairs(targets) do
            if t and prevVis[i] then pcall(function() t:setVisible(true) end) end
        end
        -- Restore spatially auto-hidden widgets
        for w, _ in pairs(autoPrev) do
            pcall(function() w:setVisible(true) end)
        end
    end

    return obj
end

-- Creates a transparent panel that draws a single text string. Prerender is hidden
-- internally; callers receive a plain ISPanel with no rendering responsibilities.
--
-- opts:
--   x, y       number
--   w          number
--   h          number?    default TH.FONT_HGT_SMALL + 2
--   text       string?    static text
--   getText    fun():string?  dynamic text (nil or "" → nothing drawn)
--   font       UIFont?    default UIFont.Small
--   textX      number?    x offset of text inside panel  (default 0)
--   textY      number?    y offset of text inside panel  (default 0)
--   vCenter    bool?      compute textY to vertically centre UIFont.Small in h
--   r, g, b    number?    text colour  (default TH.TEXT_R/G/B)
--   a          number?    text alpha   (default 1)
--   getR/G/B   fun():number?  dynamic colour channels
--   getA       fun():number?  dynamic alpha
--   bg         {r,g,b,a}?  background (default transparent)
--
---@param parent ISPanel?
---@param opts table
---@return ISPanel
-- Returns { panel, setText, setVisible, setColor }.
-- setText / setColor drive the display for explicit updates.
-- opts.getText / opts.getR/G/B/A callbacks are also supported for per-frame dynamic labels.
function ManualSave.makeLabel(parent, opts)
    local TH   = ManualSave.Theme
    local font = opts.font or UIFont.Small
    local h    = opts.h or (TH.FONT_HGT_SMALL + 2)
    local txY  = opts.textY or 0
    if opts.vCenter then txY = math.floor((h - TH.FONT_HGT_SMALL) / 2) end

    local _text = opts.text or ""
    local _r    = opts.r or TH.TEXT_R
    local _g    = opts.g or TH.TEXT_G
    local _b    = opts.b or TH.TEXT_B
    local _a    = opts.a or 1

    local panel = ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y or 0, w=opts.w, h=h,
        bg=opts.bg or { r=0, g=0, b=0, a=0 }, border=false,
        prerender = function(lp)
            local txt = opts.getText and opts.getText() or _text
            if not txt or txt == "" then return end
            local r = opts.getR and opts.getR() or _r
            local g = opts.getG and opts.getG() or _g
            local b = opts.getB and opts.getB() or _b
            local a = opts.getA and opts.getA() or _a
            lp:drawText(txt, opts.textX or 0, txY, r, g, b, a, font)
        end,
    })

    return {
        panel      = panel,
        setText    = function(txt)          _text = txt or ""          end,
        setVisible = function(v)            panel:setVisible(v)        end,
        setColor   = function(r, g, b, a)   _r,_g,_b,_a = r,g,b,a    end,
    }
end

-- Creates a panel with a top accent bar drawn internally via prerender.
-- Callers add child labels and panels; no prerender needed from callers.
--
-- opts:
--   x, y, w, h   number
--   bg           {r,g,b,a}?  background (default PANEL_R/G/B)
--   accent       string?     "primary" (default), "secondary", "danger"
--   bottomBorder bool?       draw a 1-px LINE border at the bottom (default false)
--
---@param parent ISPanel?
---@param opts table
---@return ISPanel
function ManualSave.makeHeaderPanel(parent, opts)
    local TH     = ManualSave.Theme
    local accent = opts.accent or "primary"
    local bg     = opts.bg or { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }
    return ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y or 0, w=opts.w, h=opts.h,
        bg=bg, border=false,
        prerender = function(hp)
            if accent == "danger" then
                hp:drawRect(0, 0, hp.width, 2, 1,
                    TH.DANGER_R * 0.9, TH.DANGER_G * 0.5, TH.DANGER_B * 0.4)
            else
                ManualSave.Draw.accentBar(hp, 0, 0, hp.width, 2, accent == "secondary")
            end
            if opts.bottomBorder then
                hp:drawRect(0, hp.height - 1, hp.width, 1, 1, TH.LINE_R, TH.LINE_G, TH.LINE_B)
            end
        end,
    })
end

-- Detail view panel for LoadScreen right column. Encapsulates the full save-info
-- rendering (name, date, fields, MAP/MODS) with fade-in animation.
-- All drawing is inside this element; sections/screens call no prerender.
--
-- opts:
--   x, y, w, h     number
--   onMouseUp      fun(p, mx, my)?
--
---@param parent ISPanel?
---@param opts table
---@return ISPanel
function ManualSave.makeSaveDetailView(parent, opts)
    local TH = ManualSave.Theme

    local function pxTrunc(txt, mxW)
        if getTextManager():MeasureStringX(UIFont.Small, txt) <= mxW then return txt end
        local s = txt
        while #s > 0 and getTextManager():MeasureStringX(UIFont.Small, s .. "\226\128\166") > mxW do
            s = s:sub(1, -2)
        end
        return s .. "\226\128\166"
    end

    local function charTrunc(s, max)
        if #s <= max then return s end
        return s:sub(1, max - 3) .. "..."
    end

    local function drawDetail(dp)
        local st = ManualSave.LoadScreen._state
        if not st or not st.selected then
            dp:drawText(getText("UI_MSM_Detail_NoSelection"), 12, 16,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.40, UIFont.Small)
            return
        end
        local m  = st.selected
        local fa = math.min(1, (st.fadealpha or 0) + 0.06)
        st.fadealpha = fa

        if not st.renamingSlot then
            local sl = ManualSave.slotDisplay and ManualSave.slotDisplay(m.slot or "") or (m.slot or "")
            dp:drawText(charTrunc(sl, 33), 0, 2,
                TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, fa, UIFont.Large)
        end

        local dateY = TH.FONT_HGT_LARGE + 6
        if m.DATE and m.DATE ~= "" then
            dp:drawText(m.DATE, 0, dateY,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, fa * 0.75, UIFont.Small)
        end

        local divY = TH.FONT_HGT_LARGE + TH.FONT_HGT_SMALL + 14
        dp:drawRect(0, divY, dp.width, 1, fa, TH.LINE_R, TH.LINE_G, TH.LINE_B)

        local y     = divY + TH.GAP
        local fh    = TH.FONT_HGT_SMALL * 2 + 8
        local halfW = math.floor(dp.width / 2)

        local function field(lbl, val, fx, fy)
            dp:drawText(lbl,        fx, fy,
                TH.DIM_R,  TH.DIM_G,  TH.DIM_B,  fa * 0.8, UIFont.Small)
            dp:drawText(val or "--", fx, fy + TH.FONT_HGT_SMALL + 2,
                TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, fa,        UIFont.Small)
        end

        field(getText("UI_MSM_Display_GameMode"), m.GMODE or m.gameMode or "--", 0,     y)
        field(getText("UI_MSM_Display_World"),    m.world or m.WORLD     or "--", halfW, y)
        y = y + fh
        field(getText("UI_MSM_Display_Playtime"), m.PLAYTIME or "--", 0,     y)
        field(getText("UI_MSM_Display_Size"),     m.SIZE     or "--", halfW, y)
        y = y + fh

        if m.CORRUPTED then
            ManualSave.Draw.badge(dp, 0, y, "CORRUPTED", "danger")
            y = y + TH.FONT_HGT_SMALL + 8
        end

        dp:drawRect(0, y, dp.width, 1, fa * 0.5, TH.LINE_R, TH.LINE_G, TH.LINE_B)
        y = y + TH.GAP

        local mapEntries = {}
        local mapRaw = m.MAP or ""
        if mapRaw:find("map%s*=") then
            for n in mapRaw:gmatch("map%s*=%s*([^,]+)") do
                n = n:match("^%s*(.-)%s*$")
                if n ~= "" then table.insert(mapEntries, n) end
            end
        end
        if #mapEntries == 0 then
            for e in mapRaw:gmatch("[^;]+") do
                local s = e:match("^%s*(.-)%s*$")
                if s ~= "" then table.insert(mapEntries, s) end
            end
        end

        local mods  = st.selectedMods or {}
        local colW  = halfW - 8
        local maxR  = 4

        dp:drawText(getText("UI_MSM_Display_MapCount",  tostring(#mapEntries)), 0,     y,
            TH.DIM_R, TH.DIM_G, TH.DIM_B, fa * 0.8, UIFont.Small)
        dp:drawText(getText("UI_MSM_Display_ModsCount", tostring(#mods)),       halfW, y,
            TH.DIM_R, TH.DIM_G, TH.DIM_B, fa * 0.8, UIFont.Small)
        y = y + TH.FONT_HGT_SMALL + 4

        local rowH = TH.FONT_HGT_SMALL + 2
        for i = 1, math.min(maxR, math.max(#mapEntries, #mods)) do
            if i <= #mapEntries then
                dp:drawText(pxTrunc(mapEntries[i], colW), 4, y,
                    TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, fa, UIFont.Small)
            end
            if i <= #mods then
                dp:drawText(pxTrunc(mods[i].name or "", colW), halfW + 4, y,
                    TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, fa, UIFont.Small)
            end
            y = y + rowH
        end
        if #mapEntries > maxR then
            dp:drawText(getText("UI_MSM_Display_MoreCount", tostring(#mapEntries - maxR)), 4, y,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, fa * 0.6, UIFont.Small)
        end
        if #mods > maxR then
            dp:drawText(getText("UI_MSM_Display_MoreCount", tostring(#mods - maxR)), halfW + 4, y,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, fa * 0.6, UIFont.Small)
        end
    end

    return ManualSave.makePanel(parent, {
        x=opts.x, y=opts.y, w=opts.w, h=opts.h,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
        prerender = function(dp) drawDetail(dp) end,
        onMouseUp  = opts.onMouseUp,
    })
end

-- Augments a floating panel's title bar with a Watcher status dot + label.
-- Wraps the existing prerender; call once after makeFloatingPanel.
-- Defined in elements/ so callers in screens/ need no prerender themselves.
--
-- titleBar  ISPanel   d._titleBar from makeFloatingPanel
-- opts: { titleH:number, panelW:number }
--
function ManualSave.makeWatcherStatusDot(titleBar, opts)
    local TH   = ManualSave.Theme
    local GOOD_R, GOOD_G, GOOD_B = 0.37, 0.63, 0.35
    local orig = titleBar.prerender
    titleBar.prerender = function(tb)
        orig(tb)
        local alive = ManualSave.SignalBus.isBatAlive() ~= false
        local r     = alive and GOOD_R   or TH.DANGER_R
        local g     = alive and GOOD_G   or TH.DANGER_G
        local b     = alive and GOOD_B   or TH.DANGER_B
        local lbl   = alive and "Watcher running" or "Watcher offline"
        local lw    = getTextManager():MeasureStringX(UIFont.Small, lbl)
        local dotSz = 7
        local xBtn  = opts.panelW - 28 - 6
        local ix    = xBtn - lw - 6 - dotSz - 4
        local iy    = math.floor((opts.titleH - dotSz) / 2)
        local ty    = math.floor((opts.titleH - TH.FONT_HGT_SMALL) / 2) + 1
        tb:drawRect(ix, iy, dotSz, dotSz, 1, r, g, b)
        tb:drawText(lbl, ix + dotSz + 4, ty, r, g, b, 0.9, UIFont.Small)
    end
end

-- Creates a 1-pixel horizontal separator using the LINE colour from Theme.
-- Avoids any direct drawing in screen code.
--
-- opts:
--   x, y    number
--   w       number
--   alpha   number?   opacity (default 0.3)
--
---@param parent ISPanel?
---@param opts { x:number, y:number, w:number, alpha:number? }
---@return ISPanel
function ManualSave.makeSeparatorLine(parent, opts)
    local TH = ManualSave.Theme
    local a  = opts.alpha or 0.3
    return ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y, w=opts.w, h=1,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=a },
        border=false,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Panel.lua loaded.")
