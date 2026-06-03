-- UI/Base/Widgets/Elements/Thumbnail.lua
-- Scaled image panel with fade overlay, optional overlay renderer, and an
-- optional zoom button that opens the texture full-screen via Lightbox.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field

ManualSave = ManualSave or {}

-- Small zoom-button overlay drawn on hover when opts.zoomable is true.
-- Glyph is a generic "expand" arrow that any UTF-8 font renders.
local ZOOM_BTN_SIZE = 22
local ZOOM_BTN_PAD  = 4

local function drawZoomBadge(tp)
    local bx = tp.width  - ZOOM_BTN_SIZE - ZOOM_BTN_PAD
    local by = ZOOM_BTN_PAD
    tp:drawRect(bx, by, ZOOM_BTN_SIZE, ZOOM_BTN_SIZE, 0.55, 0, 0, 0)
    tp:drawRectBorder(bx, by, ZOOM_BTN_SIZE, ZOOM_BTN_SIZE, 0.85, 1, 1, 1)
    -- The glyph is intentionally a Latin character ("+") rather than a
    -- decorative Unicode arrow so it renders on every PZ font without
    -- needing a custom asset. Two thin chevrons under it hint "expand".
    local font = UIFont.Medium
    local gw   = getTextManager():MeasureStringX(font, "+")
    local gh   = getTextManager():getFontHeight(font)
    tp:drawText("+",
        bx + math.floor((ZOOM_BTN_SIZE - gw) / 2),
        by + math.floor((ZOOM_BTN_SIZE - gh) / 2) - 1,
        1, 1, 1, 1, font)
end

local function pointInThumb(tp, mx, my)
    return mx >= 0 and mx <= tp.width and my >= 0 and my <= tp.height
end

-- Creates a panel that displays a scaled texture with an optional gradient fade.
--
-- opts:
--   x, y, w, h    number
--   bg            {r,g,b,a}?   background when no texture (default: black)
--   getTexture    fun()->tex?  called each frame; nil = no texture
--   hasContent    fun()->bool? true = show emptyMsg when no texture
--   emptyMsg      string?      default "No preview available"
--   fade          number?      gradient overlay alpha (default 0.55)
--   overlay       fun(panel)?  called after texture/fade; draw text or badges here
--   zoomable      bool?        if true, hover/focus shows a zoom button and
--                              click anywhere on the thumbnail opens it in
--                              a full-screen Lightbox (needs openImageLightbox).
--   zoomCaption   string?      optional caption rendered under the zoomed image.
--
---@param parent ISPanel?
---@param opts table
---@return ISPanel
function ManualSave.makeThumbnail(parent, opts)
    local TH = ManualSave.Theme
    local tp = ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y or 0, w=opts.w, h=opts.h,
        bg=opts.bg or { r=0, g=0, b=0, a=1 },
        prerender = function(p)
            local tex = opts.getTexture and opts.getTexture()
            if tex then
                local tw, th = tex:getWidth(), tex:getHeight()
                local scale  = math.max(p.width / tw, p.height / th)
                local dw     = math.floor(tw * scale)
                local dh     = math.floor(th * scale)
                local ox     = math.floor((p.width  - dw) / 2)
                local oy     = math.floor((p.height - dh) / 2)
                p:setStencilRect(0, 0, p.width, p.height)
                p:drawTextureScaled(tex, ox, oy, dw, dh, 1)
                p:clearStencilRect()
                ManualSave.Draw.thumbnailFade(p, p.width, p.height, opts.fade or 0.55)
            elseif opts.hasContent and opts.hasContent() then
                local msg = opts.emptyMsg or "No preview available"
                local mw  = getTextManager():MeasureStringX(UIFont.Small, msg)
                p:drawText(msg,
                    math.floor((p.width  - mw) / 2),
                    math.floor((p.height - TH.FONT_HGT_SMALL) / 2),
                    TH.DIM_R, TH.DIM_G, TH.DIM_B, 1, UIFont.Small)
            end
            if opts.overlay then opts.overlay(p) end
            -- Zoom badge: only when the option is on AND we have a texture
            -- AND the mouse (or gamepad focus) is over the thumb.
            if opts.zoomable and tex then
                local mx = p:getMouseX()
                local my = p:getMouseY()
                local hover = pointInThumb(p, mx, my)
                local focused = p._inputFocused == true   -- set by InputNav when on gamepad
                if hover or focused then drawZoomBadge(p) end
            end
        end,
    })

    -- Click anywhere on the thumbnail (including the badge) opens the
    -- lightbox. We don't bother with badge-only hit detection because the
    -- intent of zoomable is "click the picture to see it big".
    if opts.zoomable then
        local origMouseDown = tp.onMouseDown
        tp.onMouseDown = function(self2, mx, my)
            local tex = opts.getTexture and opts.getTexture()
            if tex and ManualSave.openImageLightbox then
                -- zoomCaption may be a string OR a fun()->string so callers
                -- can hand off slot-bound captions that change with selection.
                -- Coerce to string to guard against accidental table returns
                -- (drawText would crash on a KahluaTable).
                local cap = opts.zoomCaption
                if type(cap) == "function" then cap = cap() end
                if type(cap) ~= "string" then
                    cap = (cap and tostring(cap)) or nil
                end
                ManualSave.openImageLightbox({
                    getTexture = opts.getTexture,
                    caption    = cap,
                })
                return true
            end
            if origMouseDown then return origMouseDown(self2, mx, my) end
        end
    end

    return tp
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Thumbnail.lua loaded.")
