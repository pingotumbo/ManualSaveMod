-- UI/Base/Widgets/Elements/Thumbnail.lua
-- Scaled image panel with fade overlay and optional overlay renderer.
---@diagnostic disable: undefined-global, undefined-doc-name

ManualSave = ManualSave or {}

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
--
---@param parent ISPanel?
---@param opts table
---@return ISPanel
function ManualSave.makeThumbnail(parent, opts)
    local TH = ManualSave.Theme
    return ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y or 0, w=opts.w, h=opts.h,
        bg=opts.bg or { r=0, g=0, b=0, a=1 },
        prerender = function(tp)
            local tex = opts.getTexture and opts.getTexture()
            if tex then
                local tw, th = tex:getWidth(), tex:getHeight()
                local scale  = math.max(tp.width / tw, tp.height / th)
                local dw     = math.floor(tw * scale)
                local dh     = math.floor(th * scale)
                local ox     = math.floor((tp.width  - dw) / 2)
                local oy     = math.floor((tp.height - dh) / 2)
                tp:setStencilRect(0, 0, tp.width, tp.height)
                tp:drawTextureScaled(tex, ox, oy, dw, dh, 1)
                tp:clearStencilRect()
                ManualSave.Draw.thumbnailFade(tp, tp.width, tp.height, opts.fade or 0.55)
            elseif opts.hasContent and opts.hasContent() then
                local msg = opts.emptyMsg or "No preview available"
                local mw  = getTextManager():MeasureStringX(UIFont.Small, msg)
                tp:drawText(msg,
                    math.floor((tp.width  - mw) / 2),
                    math.floor((tp.height - TH.FONT_HGT_SMALL) / 2),
                    TH.DIM_R, TH.DIM_G, TH.DIM_B, 1, UIFont.Small)
            end
            if opts.overlay then opts.overlay(tp) end
        end,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Thumbnail.lua loaded.")
