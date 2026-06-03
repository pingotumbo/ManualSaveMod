-- UI/Base/Panels/Lightbox.lua
-- Full-screen modal panel that shows a single image (or animation frame) at
-- maximum readable size. Built on top of makeFloatingPanel so it inherits the
-- standard title bar, X button and accent border.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

-- opts:
--   getTexture  fun()->Texture   returns the texture to show each frame
--                                 (a function so animated sources can advance)
--   caption     string?           optional title-bar label (e.g. slot name)
--   joypadData  table?            forwarded to the floating panel so gamepad
--                                 focus transfers correctly when opened on pad
function ManualSave.openImageLightbox(opts)
    if not opts or not opts.getTexture then return end
    local TH  = ManualSave.Theme
    local sw  = getCore():getScreenWidth()
    local sh  = getCore():getScreenHeight()

    -- The lightbox covers ~90% of the screen so the image breathes inside it.
    local W = math.floor(sw * 0.90)
    local H = math.floor(sh * 0.90)

    -- Defensive: never pass a non-string as title. Floating's drawText would
    -- crash with "No implementation found for DrawText" if title were a table.
    local titleStr = opts.caption
    if type(titleStr) ~= "string" then
        titleStr = (titleStr and tostring(titleStr)) or ""
    end

    local d = ManualSave.makeFloatingPanel({
        w           = W,
        h           = H,
        title       = titleStr,
        borderStyle = "accent",
    })

    -- Image area: everything below the title bar minus a small padding.
    local imgPad = TH.PAD * 2
    local imgX   = imgPad
    local imgY   = d.titleH + imgPad
    local imgW   = W - imgPad * 2
    local imgH   = H - d.titleH - imgPad * 2

    ManualSave.makePanel(d.panel, {
        x = imgX, y = imgY, w = imgW, h = imgH,
        bg = { r = 0, g = 0, b = 0, a = 1 },
        prerender = function(p)
            local tex = opts.getTexture()
            if not tex then return end
            local tw = tex:getWidth() or 0
            local th = tex:getHeight() or 0
            if tw <= 0 or th <= 0 then return end
            -- Fit (preserve aspect, never crop): the image grows until either
            -- width or height fills the area, whichever happens first.
            local scale = math.min(p.width / tw, p.height / th)
            local dw    = math.floor(tw * scale)
            local dh    = math.floor(th * scale)
            local ox    = math.floor((p.width  - dw) / 2)
            local oy    = math.floor((p.height - dh) / 2)
            p:drawTextureScaled(tex, ox, oy, dw, dh, 1)
        end,
    })

    d.open(opts.joypadData)
end

print("[ManualSaveMod] UI/Base/Panels/Lightbox.lua loaded.")
