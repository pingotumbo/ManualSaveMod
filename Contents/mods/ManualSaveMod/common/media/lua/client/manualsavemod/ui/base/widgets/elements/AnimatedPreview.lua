-- UI/Base/Widgets/Elements/AnimatedPreview.lua
-- Bordered preview panel that cycles through a list of textures at a fixed FPS.
-- Size and visibility are read live via callbacks so they stay in sync with external state.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: {
--   x?, y, w, h
--   textures            array of texture paths (strings)
--   fps?                frames between advances (default 8, lower = faster)
--   getSize?            fun():number  sprite size in px (default: fills panel)
--   isActive?           fun():bool    when false shows noActiveKey text instead of sprite
--   noActiveKey?        string        i18n key for the "not active" label
-- }
function ManualSave.makeAnimatedPreview(parent, opts)
    local TH       = ManualSave.Theme
    local fps      = opts.fps or 8
    local texPaths = opts.textures or {}
    local nFrames  = math.max(1, #texPaths)

    local textures = {}
    for _, path in ipairs(texPaths) do
        table.insert(textures, getTexture(path))
    end

    local tick = 0
    local idx  = 0

    return ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y, w=opts.w, h=opts.h,
        bg={ r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }, border=false,
        prerender = function(pv)
            local TH2    = ManualSave.Theme
            local active = not opts.isActive or opts.isActive()

            pv:drawRectBorder(0, 0, pv.width, pv.height, 0.35,
                TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)

            tick = tick + 1
            if tick >= fps then tick = 0; idx = (idx + 1) % nFrames end

            if not active then
                if opts.noActiveKey then
                    local txt = getText(opts.noActiveKey)
                    local tw  = getTextManager():MeasureStringX(UIFont.Small, txt)
                    pv:drawText(txt,
                        math.floor((pv.width  - tw)                  / 2),
                        math.floor((pv.height - TH2.FONT_HGT_SMALL) / 2),
                        TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.6, UIFont.Small)
                end
                return
            end

            local sprSz = opts.getSize and opts.getSize()
                or math.min(pv.width - 16, pv.height - 16)
            sprSz = math.max(4, math.min(pv.height - 16, pv.width - 16, sprSz))

            local tex = textures[idx + 1]
            if tex then
                pv:drawTextureScaled(tex,
                    math.floor((pv.width  - sprSz) / 2),
                    math.floor((pv.height - sprSz) / 2),
                    sprSz, sprSz, 1)
            end
        end,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/AnimatedPreview.lua loaded.")
