-- UI/Base/Widgets/Elements/Layout.lua
-- Structural layout helpers. Eliminate repeated column/section setup across screens.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave        = ManualSave or {}
ManualSave.Layout = ManualSave.Layout or {}

-- ── makeTwoColumnLayout ───────────────────────────────────────────────────────
--
-- Creates two transparent container panels side by side inside parent.
-- Callers position child widgets relative to each panel (starting at 0,0).
--
-- opts:
--   x, y        number       position inside parent
--   w, h        number       total area to split
--   splitRatio  number?      fraction of w given to left panel  (default 0.44)
--   gap         number?      pixels between the two panels      (default TH.PAD)
--
-- returns:
--   left        ISPanel      left container
--   right       ISPanel      right container
--   leftW       number       width of left panel
--   rightW      number       width of right panel
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, splitRatio:number?, gap:number? }
---@return { left:ISPanel, right:ISPanel, leftW:number, rightW:number }
function ManualSave.makeTwoColumnLayout(parent, opts)
    local TH    = ManualSave.Theme
    local ratio = opts.splitRatio or 0.44
    local gap   = opts.gap        or TH.PAD

    local leftW  = math.floor(opts.w * ratio) - math.floor(gap / 2)
    local rightW = opts.w - leftW - gap
    local rightX = opts.x + leftW + gap

    local transparent = { r=0, g=0, b=0, a=0 }

    local left = ISPanel:new(opts.x, opts.y, leftW, opts.h)
    left.backgroundColor = transparent
    left.borderColor     = transparent
    left:initialise(); left:instantiate()
    if parent then parent:addChild(left) end

    local right = ISPanel:new(rightX, opts.y, rightW, opts.h)
    right.backgroundColor = transparent
    right.borderColor     = transparent
    right:initialise(); right:instantiate()
    if parent then parent:addChild(right) end

    return { left=left, right=right, leftW=leftW, rightW=rightW }
end

-- ── makeSectionPanel ──────────────────────────────────────────────────────────
--
-- Creates a labelled section panel with a 2-px accent bar at the top.
-- Returns { panel, headerH } so callers add child labels below headerH.
-- No prerender opt — callers must use makeLabel / makeFieldPair for content.
--
-- opts:
--   x, y        number
--   w, h        number
--   label       string       section title drawn in DIM colour
--   accent      string?      "primary" (default), "secondary" (dimmed), "danger"
--
-- returns:
--   { panel:ISPanel, headerH:number }
--   headerH = TH.FONT_HGT_SMALL + 10  (also in ManualSave.Layout.SECTION_HEADER_H)
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, label:string, accent:string? }
---@return { panel:ISPanel, headerH:number }
function ManualSave.makeSectionPanel(parent, opts)
    local TH      = ManualSave.Theme
    local accent  = opts.accent or "primary"
    local label   = opts.label  or ""
    local headerH = TH.FONT_HGT_SMALL + 10   -- bar(2) + gap(2) + text + padding

    local p = ISPanel:new(opts.x or 0, opts.y or 0, opts.w, opts.h)
    p.backgroundColor = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }
    p.borderColor     = { r=TH.LINE_R,  g=TH.LINE_G,  b=TH.LINE_B,  a=1 }
    p:initialise(); p:instantiate()

    p.prerender = function(self2)
        ISPanel.prerender(self2)
        if accent == "danger" then
            self2:drawRect(0, 0, self2.width, 2, 1,
                TH.DANGER_R * 0.9, TH.DANGER_G * 0.5, TH.DANGER_B * 0.4)
        else
            ManualSave.Draw.accentBar(self2, 0, 0, self2.width, 2, accent == "secondary")
        end
        self2:drawText(label, 12, 4, TH.DIM_R, TH.DIM_G, TH.DIM_B, 0.8, UIFont.Small)
    end

    if parent then parent:addChild(p) end
    return { panel=p, headerH=headerH }
end

-- ── makeFieldPair ─────────────────────────────────────────────────────────────
--
-- Two-line field display: uppercase dim label above, value text below.
-- Adds itself as children of parent.
--
-- opts:
--   x, y        number       top-left of the pair within parent
--   w           number       width
--   label       string       field name (auto-uppercased)
--   value       string?      static value text (use getValue for dynamic)
--   getValue    fun():string?  dynamic value; shown as "--" when nil/""
--
-- returns: height consumed  (TH.FONT_HGT_SMALL * 2 + 6)
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, label:string, value:string?, getValue:fun():string? }
---@return number
function ManualSave.makeFieldPair(parent, opts)
    local TH  = ManualSave.Theme
    local FHS = TH.FONT_HGT_SMALL
    local lh  = FHS * 2 + 6

    ManualSave.makeLabel(parent, {
        x=opts.x, y=opts.y, w=opts.w, h=FHS + 1,
        text=(opts.label or ""):upper(),
        r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=1,
    })
    ManualSave.makeLabel(parent, {
        x=opts.x, y=opts.y + FHS + 1, w=opts.w, h=FHS + 1,
        text = (opts.getValue and opts.getValue()) or opts.value or "--",
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    return lh
end

-- Expose header height constant for legacy callers.
ManualSave.Layout.SECTION_HEADER_H = nil
Events.OnGameBoot.Add(function()
    if ManualSave.Theme then
        ManualSave.Layout.SECTION_HEADER_H = ManualSave.Theme.FONT_HGT_SMALL + 10
    end
end)

print("[ManualSaveMod] UI/Base/Widgets/Elements/Layout.lua loaded.")
