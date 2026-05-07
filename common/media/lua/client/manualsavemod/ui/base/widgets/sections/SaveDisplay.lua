-- UI/Base/Widgets/Sections/SaveDisplay.lua
-- Save-related display panels: banner, save file info, world state, map/mods lists.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

local slotDisplay = ManualSave.slotDisplay

-- Thumbnail banner with save name, game mode tag, and alive/dead badge.
-- opts: { w, h, save, thumb }
function ManualSave.makeSaveBanner(parent, opts)
    local TH  = ManualSave.Theme
    local FHS = TH.FONT_HGT_SMALL
    local m   = opts.save
    ManualSave.makeThumbnail(parent, {
        x=opts.x or 0, y=opts.y or 0, w=opts.w, h=opts.h,
        bg={ r=0.05, g=0.04, b=0.04, a=1 },
        getTexture = function() return opts.thumb end,
        fade = 0.75,
        overlay = function(bn)
            local tag = (m.gameMode or "")
            if (m.world or "") ~= "" then tag = tag .. "  .  " .. m.world end
            if tag ~= "" then
                bn:drawText(tag, 16, bn.height - TH.FONT_HGT_LARGE - 6 - FHS - 2,
                    TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.85, UIFont.Small)
            end
            bn:drawText((slotDisplay and slotDisplay(m.slot or "") or (m.slot or "")):sub(1,55),
                16, bn.height - TH.FONT_HGT_LARGE - 6,
                TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Large)
            local alive = m.ALIVE or m.alive
            if alive then
                local badge = (alive == "DEAD") and "DEAD" or "ALIVE"
                local bR, bG, bB = 0.30, 0.72, 0.36
                if badge == "DEAD" then bR, bG, bB = TH.DANGER_R, TH.DANGER_G, TH.DANGER_B end
                ManualSave.Draw.badge(bn, bn.width - 60, 10, badge,
                    badge == "DEAD" and "danger" or { r=bR, g=bG, b=bB })
            end
        end,
    })
end

-- SAVE FILE section panel (game mode, save type, last saved, playtime, size).
-- opts: { y, w, save }
-- Returns: panel height
function ManualSave.makeSaveFileSection(parent, opts)
    local TH  = ManualSave.Theme
    local FHS = TH.FONT_HGT_SMALL
    local m   = opts.save
    local lh  = FHS * 2 + 6
    local h   = FHS + 12 + lh * 3 + 6

    local sec = ManualSave.makeSectionPanel(parent, {
        x=0, y=opts.y, w=opts.w, h=h, label="SAVE FILE",
    })
    local x1, x2 = 12, math.floor(opts.w / 2)
    local y = sec.headerH

    ManualSave.makeFieldPair(sec.panel, { x=x1, y=y,      w=x2-x1-4,      label="Game Mode", getValue=function() return m.GMODE    or m.gameMode or "--" end })
    ManualSave.makeFieldPair(sec.panel, { x=x2, y=y,      w=opts.w-x2-4,  label="Save Type", getValue=function() return m.TYPE     or "--"       end })
    y = y + lh
    ManualSave.makeFieldPair(sec.panel, { x=x1, y=y,      w=opts.w-x1-4,  label="Last Saved",getValue=function() return m.DATE     or "--"       end })
    y = y + lh
    ManualSave.makeFieldPair(sec.panel, { x=x1, y=y,      w=x2-x1-4,      label="Playtime",  getValue=function() return m.PLAYTIME or "--"       end })
    ManualSave.makeFieldPair(sec.panel, { x=x2, y=y,      w=opts.w-x2-4,  label="Size",      getValue=function() return m.SIZE     or "--"       end })

    return h
end

-- WORLD STATE section panel (world name, day, seed).
-- opts: { y, w, save }
-- Returns: panel height
function ManualSave.makeWorldStateSection(parent, opts)
    local TH  = ManualSave.Theme
    local FHS = TH.FONT_HGT_SMALL
    local m   = opts.save
    local lh  = FHS * 2 + 6
    local h   = FHS + 12 + lh * 2 + 6

    local sec = ManualSave.makeSectionPanel(parent, {
        x=0, y=opts.y, w=opts.w, h=h, label="WORLD STATE", accent="secondary",
    })
    local x1, x2 = 12, math.floor(opts.w / 2)
    local y = sec.headerH

    ManualSave.makeFieldPair(sec.panel, { x=x1, y=y,    w=x2-x1-4,     label="World", getValue=function() return m.world or "--" end })
    ManualSave.makeFieldPair(sec.panel, { x=x2, y=y,    w=opts.w-x2-4, label="Day",   getValue=function() return m.DAY and ("Day "..m.DAY) or "--" end })
    y = y + lh
    ManualSave.makeFieldPair(sec.panel, { x=x1, y=y,    w=opts.w-x1-4, label="Seed",  getValue=function() return m.SEED or "--" end })

    return h
end

-- MAP + MODS side-by-side sections with expand panels.
-- opts: { y, w, save, mods }
-- Returns: { mapExpand, modsExpand }
function ManualSave.makeMapModsLists(parent, opts)
    local TH      = ManualSave.Theme
    local FHS     = TH.FONT_HGT_SMALL
    local m       = opts.save
    local mods    = opts.mods or {}
    local halfGap = 6
    local halfW   = math.floor((opts.w - halfGap) / 2)
    local modsW   = opts.w - halfW - halfGap
    local rowH    = FHS + 4
    local maxR    = 6
    local listH   = rowH * maxR + 4
    local secH    = FHS + 10 + listH   -- headerH (FHS+10) + listH
    local hdrH    = FHS + 10           -- matches makeSectionPanel headerH
    local btnSz   = FHS + 2            -- small square expand button, fits below 2px accent bar
    local btnY    = 2 + math.floor((hdrH - 2 - btnSz) / 2)

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
    if #mapEntries == 0 then mapEntries = { "--" } end

    local MAP_W  = 270
    local MODS_W = 290
    local sw     = getCore():getScreenWidth()
    local mapX   = math.floor((sw - MAP_W - MODS_W - 20) / 2)
    local modsX  = mapX + MAP_W + 20

    -- MAP expand popup
    local mapExpand = ManualSave.makeExpandPanel({
        title   = "MAP  (" .. #mapEntries .. ")",
        w       = MAP_W, x = mapX,
        items   = mapEntries,
        drawRow = function(pb, entry, ex, ey, ew, eh, sel, _)
            if sel then pb:drawRect(ex, ey, ew, eh, 0.15, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B) end
            pb:drawText(entry, ex + 8, ey + math.floor((eh - FHS) / 2),
                TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Small)
        end,
    })

    -- MAP section: standard header + compact scrolllist + expand button
    local mapSec = ManualSave.makeSectionPanel(parent, {
        x=0, y=opts.y, w=halfW, h=secH,
        label = "MAP (" .. #mapEntries .. ")",
    })
    ManualSave.makeButton(mapSec.panel, {
        x=halfW - btnSz - 4, y=btnY,
        w=btnSz, h=btnSz, label="+", style="normal",
        onClick = mapExpand.open,
    })
    ManualSave.makeScrollList(mapSec.panel, {
        x=0, y=mapSec.headerH, w=halfW, h=listH,
        rowH=rowH, items=mapEntries,
        bg={ r=TH.BG_R, g=TH.BG_G, b=TH.BG_B },
        drawRow = function(pb, entry, ex, ey, ew, eh, sel, _)
            if sel then pb:drawRect(ex, ey, ew, eh, 0.15, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B) end
            pb:drawText(entry, ex + 8, ey + math.floor((eh - FHS) / 2),
                TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Small)
        end,
    })

    -- MODS expand popup
    local modItems = #mods > 0 and mods or {{ name="(none)" }}
    local modsExpand = ManualSave.makeExpandPanel({
        title   = "MODS  (" .. #mods .. ")",
        w       = MODS_W, x = modsX,
        items   = modItems,
        drawRow = function(pb, mod, ex, ey, ew, eh, sel, _)
            if sel then pb:drawRect(ex, ey, ew, eh, 0.15, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B) end
            local isMissing = (mod.name or ""):find("%(missing%)$") ~= nil
            pb:drawText(mod.name or "", ex + 8, ey + math.floor((eh - FHS) / 2),
                isMissing and TH.DANGER_R or TH.TEXT_R,
                isMissing and TH.DANGER_G or TH.TEXT_G,
                isMissing and TH.DANGER_B or TH.TEXT_B, 1, UIFont.Small)
        end,
    })

    -- MODS section: standard header + compact scrolllist + expand button
    local modsSec = ManualSave.makeSectionPanel(parent, {
        x=halfW + halfGap, y=opts.y, w=modsW, h=secH,
        label = "MODS (" .. #mods .. ")",
    })
    ManualSave.makeButton(modsSec.panel, {
        x=modsW - btnSz - 4, y=btnY,
        w=btnSz, h=btnSz, label="+", style="normal",
        onClick = modsExpand.open,
    })
    ManualSave.makeScrollList(modsSec.panel, {
        x=0, y=modsSec.headerH, w=modsW, h=listH,
        rowH=rowH, items=modItems,
        bg={ r=TH.BG_R, g=TH.BG_G, b=TH.BG_B },
        drawRow = function(pb, mod, ex, ey, ew, eh, sel, _)
            if sel then pb:drawRect(ex, ey, ew, eh, 0.15, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B) end
            local isMissing = (mod.name or ""):find("%(missing%)$") ~= nil
            pb:drawText(mod.name or "", ex + 8, ey + math.floor((eh - FHS) / 2),
                isMissing and TH.DANGER_R or TH.TEXT_R,
                isMissing and TH.DANGER_G or TH.TEXT_G,
                isMissing and TH.DANGER_B or TH.TEXT_B, 1, UIFont.Small)
        end,
    })

    return { mapExpand=mapExpand, modsExpand=modsExpand }
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SaveDisplay.lua loaded.")
