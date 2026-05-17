-- UI/Screens/SettingsScreen.lua
-- Settings overlay: floating panel with left nav and four tabbed sections.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

local W, H  = 640, 560
local NAV_W = 148

local SECTIONS = {
    { id="general",  labelKey="UI_MSM_Settings_NavGeneral"  },
    { id="progress", labelKey="UI_MSM_Settings_NavProgress" },
    { id="paths",    labelKey="UI_MSM_Settings_NavPaths"    },
    { id="advanced", labelKey="UI_MSM_Settings_NavAdvanced" },
}

local _screen          = nil
local _section         = "general"
local _sectionPanels   = {}
local _resetDialogOpen = false

-- ── Row helpers ───────────────────────────────────────────────────────────────

-- Clean checkbox toggle row. No card background. Checkbox + title + desc +
-- thin bottom separator. Same visual language as Import/EditMods checkboxes.
local function makeCheckRow(parent, opts)
    local TH    = ManualSave.Theme
    local FHS   = TH.FONT_HGT_SMALL
    local ROW_H = opts.h or (FHS * 2 + 28)
    local cbSz  = 13
    local cbX   = 14
    local cbY   = 4 + math.floor((FHS - cbSz) / 2)
    local textX = cbX + cbSz + 8
    local label = opts.label or ""
    local desc  = opts.desc  or ""
    return ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y, w=opts.w, h=ROW_H,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
        prerender = function(fc)
            local TH2  = ManualSave.Theme
            local isOn = opts.getValue and opts.getValue()
            local over = false
            pcall(function() over = fc:isMouseOver() end)
            if over then
                fc:drawRect(0, 0, fc.width, fc.height - 1, 0.04, 1, 1, 1)
            end
            fc:drawRect(0, fc.height - 1, fc.width, 1,
                0.3, TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
            ManualSave.Draw.checkbox(fc, cbX, cbY, cbSz, isOn)
            local tR, tG, tB, tA
            if isOn then
                tR, tG, tB, tA = TH2.TEXT_R, TH2.TEXT_G, TH2.TEXT_B, 1.0
            else
                tR, tG, tB, tA = TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B, 0.85
            end
            fc:drawText(label, textX, 4, tR, tG, tB, tA, UIFont.Small)
            fc:drawText(desc, textX, 4 + TH2.FONT_HGT_SMALL + 3,
                TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.65, UIFont.Small)
        end,
        onMouseDown = function()
            if opts.onToggle then opts.onToggle() end
            return true
        end,
    })
end

-- Row with title on the left, segmented toolbar on the right.
-- When opts.descKey is nil: compact single-line mode.
-- opts.onPreview(value) fires immediately on selection change (before Config.set).
local function makeSettingToolbar(parent, opts)
    local TH      = ManualSave.Theme
    local compact = not opts.descKey
    local ROW_H   = opts.h or (compact
        and (TH.BUTTON_HGT + 12)
        or  (TH.FONT_HGT_SMALL * 2 + TH.BUTTON_HGT + 32))

    local p = ISPanel:new(opts.x or 0, opts.y, opts.w, ROW_H)
    p.backgroundColor = { r=0, g=0, b=0, a=0 }
    p.borderColor     = { r=0, g=0, b=0, a=0 }
    p:initialise()
    p:instantiate()

    p.prerender = function(self2)
        ISPanel.prerender(self2)
        local TH2    = ManualSave.Theme
        local titleY = compact
            and math.floor((self2.height - TH2.FONT_HGT_SMALL) / 2)
            or 12
        self2:drawRect(0, self2.height - 1, self2.width, 1,
            0.3, TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
        self2:drawText(getText(opts.titleKey), 14, titleY,
            TH2.TEXT_R, TH2.TEXT_G, TH2.TEXT_B, 1, UIFont.Small)
        if not compact then
            self2:drawText(getText(opts.descKey), 14, titleY + TH2.FONT_HGT_SMALL + 4,
                TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B, 0.8, UIFont.Small)
        end
    end

    local curVal  = ManualSave.Config.get(opts.key)
    local tbItems = {}
    for _, it in ipairs(opts.items) do
        table.insert(tbItems, {
            id     = it.id,
            label  = getText(it.labelKey),
            kind   = "toggle",
            group  = "ss_" .. opts.key,
            active = (curVal == it.value),
        })
    end
    local tbH = TH.BUTTON_HGT
    local tbW = math.floor(opts.w * 0.55)
    local tbX = opts.w - 14 - tbW
    local tbY = compact
        and math.floor((ROW_H - tbH) / 2)
        or  (ROW_H - tbH - 10)

    ManualSave.makeToolbar(p, {
        x=tbX, y=tbY, w=tbW, h=tbH,
        items    = tbItems,
        onToggle = function(id)
            for _, it in ipairs(opts.items) do
                if it.id == id then
                    if opts.onPreview then opts.onPreview(it.value) end
                    ManualSave.Config.set(opts.key, it.value)
                    break
                end
            end
        end,
    })

    if parent then parent:addChild(p) end
    return p
end

-- ── Section builders ──────────────────────────────────────────────────────────

local function buildGeneral(parent, x, y, w, h)
    local TH    = ManualSave.Theme
    local p     = ManualSave.makePanel(parent, {
        x=x, y=y, w=w, h=h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local ROW_H = TH.FONT_HGT_SMALL * 2 + 28
    local cy    = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavGeneral") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    local rows = {
        { key="CONFIRM_LOAD",      titleKey="UI_MSM_Settings_ConfirmLoadTitle", descKey="UI_MSM_Settings_ConfirmLoadDesc" },
        { key="CONFIRM_DELETE",    titleKey="UI_MSM_Settings_ConfirmDelTitle",  descKey="UI_MSM_Settings_ConfirmDelDesc"  },
        { key="SHOW_WATCHER_WARN", titleKey="UI_MSM_Settings_WatcherWarnTitle", descKey="UI_MSM_Settings_WatcherWarnDesc" },
    }
    for _, row in ipairs(rows) do
        local key = row.key
        makeCheckRow(p, {
            x=0, y=cy, w=w, h=ROW_H,
            label    = getText(row.titleKey),
            desc     = getText(row.descKey),
            getValue = function() return ManualSave.Config.get(key) ~= "0" end,
            onToggle = function()
                ManualSave.Config.set(key, ManualSave.Config.get(key) == "0" and "1" or "0")
            end,
        })
        cy = cy + ROW_H
    end

    -- ── Save image chooser ────────────────────────────────────────────────────
    cy = cy + TH.GAP * 3

    ManualSave.makePanel(p, {
        x=0, y=cy, w=w, h=1,
        bg={r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.4}, border=false,
    })
    cy = cy + 1 + TH.GAP

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_SaveImageTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_SaveImageDesc") end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    local thumbTex = getTexture("media/textures/MSM_ThumbPreview_Screenshot.png")
    local placeTex = getTexture("media/textures/MSM_ThumbPreview_Placeholder.png")

    local CARD_PREV_H  = 64
    local CARD_TITLE_H = 26
    local CARD_H       = CARD_PREV_H + CARD_TITLE_H
    local cardW        = math.floor((w - 28 - TH.GAP) / 2)

    local cardDefs = {
        { value="screenshot",  titleKey="UI_MSM_Settings_ThumbScreenshotTitle",  tex=thumbTex },
        { value="placeholder", titleKey="UI_MSM_Settings_ThumbPlaceholderTitle", tex=placeTex },
    }
    for i, cd in ipairs(cardDefs) do
        local cardX = 14 + (i - 1) * (cardW + TH.GAP)
        local val   = cd.value
        local tex   = cd.tex
        ManualSave.makePanel(p, {
            x=cardX, y=cy, w=cardW, h=CARD_H,
            bg={r=0,g=0,b=0,a=0}, border=false,
            prerender = function(pv)
                local TH2  = ManualSave.Theme
                local isOn = ManualSave.Config.get("THUMB_SOURCE") == val
                local over = false
                pcall(function() over = pv:isMouseOver() end)

                -- Preview image area
                pv:drawRect(0, 0, pv.width, CARD_PREV_H, 1, 0.06, 0.05, 0.04)
                if tex then
                    pv:drawTextureScaled(tex, 0, 0, pv.width, CARD_PREV_H, 1)
                end

                -- Title bar
                pv:drawRect(0, CARD_PREV_H, pv.width, CARD_TITLE_H, 1,
                    TH2.PANEL_R, TH2.PANEL_G, TH2.PANEL_B)
                local tR = isOn and TH2.ACCENT_R or TH2.TEXT_R
                local tG = isOn and TH2.ACCENT_G or TH2.TEXT_G
                local tB = isOn and TH2.ACCENT_B or TH2.TEXT_B
                local fy = CARD_PREV_H + math.floor((CARD_TITLE_H - TH2.FONT_HGT_SMALL) / 2)
                pv:drawText(getText(cd.titleKey), 8, fy, tR, tG, tB, 1, UIFont.Small)

                -- Accent separator at top of title bar when active
                if isOn then
                    pv:drawRect(0, CARD_PREV_H, pv.width, 2, 1,
                        TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                end

                -- Border
                local bA = isOn and 0.95 or (over and 0.45 or 0.35)
                local bR = isOn and TH2.ACCENT_R or TH2.LINE_R * (over and 2 or 1)
                local bG = isOn and TH2.ACCENT_G or TH2.LINE_G * (over and 2 or 1)
                local bB = isOn and TH2.ACCENT_B or TH2.LINE_B * (over and 2 or 1)
                pv:drawRectBorder(0, 0, pv.width, pv.height, bA, bR, bG, bB)
            end,
            onMouseDown = function()
                ManualSave.Config.set("THUMB_SOURCE", val)
                return true
            end,
        })
    end

    return p
end

local function buildProgress(parent, x, y, w, h)
    local TH    = ManualSave.Theme
    local p     = ManualSave.makePanel(parent, {
        x=x, y=y, w=w, h=h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local cy    = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavProgress") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    -- Live preview state
    local previewStyle  = ManualSave.Config.get("SPINNER_STYLE") or "spiffo"
    local SLIDER_MIN    = 24
    local SLIDER_MAX    = 128
    local SLIDER_PAD    = 14
    local previewSizePx  = math.max(SLIDER_MIN, math.min(SLIDER_MAX,
        tonumber(ManualSave.Config.get("SPINNER_SIZE_PX")) or 64))
    local sliderDragging  = false
    local sliderDownAbsX  = 0
    local sliderDownPanelX = 0

    -- Spiffo textures
    local spiffoTexs = {
        getTexture("media/textures/MSM_SpiffoHammer_01_WindUp.png"),
        getTexture("media/textures/MSM_SpiffoHammer_02_MidSwing.png"),
        getTexture("media/textures/MSM_SpiffoHammer_03_Strike.png"),
        getTexture("media/textures/MSM_SpiffoHammer_04_Rest.png"),
    }

    local spiffoTick = 0
    local spiffoIdx  = 0
    local SPIFFO_FPS = 8

    -- ── Spinner style row (compact) ──────────────────────────────────────────
    local compactH = TH.BUTTON_HGT + 12
    makeSettingToolbar(p, {
        x=0, y=cy, w=w, key="SPINNER_STYLE",
        titleKey = "UI_MSM_Settings_SpinnerStyleTitle",
        items = {
            { id="spiffo", labelKey="UI_MSM_Settings_SpinnerSpiffo", value="spiffo" },
            { id="none",   labelKey="UI_MSM_Settings_SpinnerNone",   value="none"   },
        },
        onPreview = function(v) previewStyle = v end,
    })
    cy = cy + compactH + TH.GAP

    -- ── Spinner size slider ──────────────────────────────────────────────────
    local SLIDER_ROW_H = TH.FONT_HGT_SMALL + 20

    local function xToSizePx(panelW, mx)
        local trackW = panelW - SLIDER_PAD * 2
        local f = math.max(0, math.min(1, (mx - SLIDER_PAD) / trackW))
        return math.floor(SLIDER_MIN + f * (SLIDER_MAX - SLIDER_MIN))
    end

    ManualSave.makePanel(p, {
        x=0, y=cy, w=w, h=SLIDER_ROW_H,
        bg={r=0,g=0,b=0,a=0}, border=false,
        prerender = function(pv)
            local TH2    = ManualSave.Theme
            local trackH = 4
            local trackW = pv.width - SLIDER_PAD * 2
            local trackY = TH2.FONT_HGT_SMALL + 8
            pv:drawRect(0, pv.height - 1, pv.width, 1, 0.3, TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
            pv:drawText(getText("UI_MSM_Settings_SpinnerSizeTitle"), SLIDER_PAD, 4,
                TH2.TEXT_R, TH2.TEXT_G, TH2.TEXT_B, 1, UIFont.Small)
            local valStr = tostring(previewSizePx) .. " px"
            local valW   = getTextManager():MeasureStringX(UIFont.Small, valStr)
            pv:drawText(valStr, pv.width - SLIDER_PAD - valW, 4,
                TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B, 0.75, UIFont.Small)
            pv:drawRect(SLIDER_PAD, trackY, trackW, trackH, 0.55, 0, 0, 0)
            local f     = (previewSizePx - SLIDER_MIN) / (SLIDER_MAX - SLIDER_MIN)
            local fillW = math.floor(f * trackW)
            if fillW > 0 then
                pv:drawRect(SLIDER_PAD, trackY, fillW, trackH, 0.9,
                    TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            end
            local THUMB_W, THUMB_H = 8, 12
            local thumbX = math.max(SLIDER_PAD,
                math.min(SLIDER_PAD + trackW - THUMB_W,
                    SLIDER_PAD + fillW - math.floor(THUMB_W / 2)))
            local thumbY = trackY + math.floor((trackH - THUMB_H) / 2)
            pv:drawRect(thumbX, thumbY, THUMB_W, THUMB_H, 1,
                TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
        end,
        onMouseDown = function(sp, mx, _)
            sliderDragging    = true
            sliderDownAbsX    = getMouseX()
            sliderDownPanelX  = mx
            previewSizePx     = xToSizePx(sp.width, mx)
            ManualSave.Config.set("SPINNER_SIZE_PX", tostring(previewSizePx))
        end,
        onMouseMove = function(self2, _, _)
            if not sliderDragging then return end
            local panelX = sliderDownPanelX + (getMouseX() - sliderDownAbsX)
            previewSizePx = xToSizePx(self2.width, panelX)
        end,
        onMouseUp = function(sp, mx, _)
            if not sliderDragging then return end
            sliderDragging = false
            previewSizePx  = xToSizePx(sp.width, mx)
            ManualSave.Config.set("SPINNER_SIZE_PX", tostring(previewSizePx))
        end,
    })
    cy = cy + SLIDER_ROW_H + TH.GAP

    -- ── Spinner animation preview ─────────────────────────────────────────────
    local SPIN_PREV_H = 120
    ManualSave.makePanel(p, {
        x=14, y=cy, w=w-28, h=SPIN_PREV_H,
        bg={ r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }, border=false,
        prerender = function(pv)
            local TH2   = ManualSave.Theme
            local pcx   = math.floor(pv.width  / 2)
            local pcy   = math.floor(pv.height / 2)
            local sprSz = math.max(4, math.min(pv.height - 16, pv.width - 16, previewSizePx))
            pv:drawRectBorder(0, 0, pv.width, pv.height, 0.35,
                TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
            spiffoTick = spiffoTick + 1
            if spiffoTick >= SPIFFO_FPS then spiffoTick = 0; spiffoIdx = (spiffoIdx + 1) % 4 end
            if previewStyle == "spiffo" then
                local tex = spiffoTexs[spiffoIdx + 1]
                if tex then
                    pv:drawTextureScaled(tex,
                        math.floor(pcx - sprSz / 2), math.floor(pcy - sprSz / 2),
                        sprSz, sprSz, 1)
                end
            else
                local txt = getText("UI_MSM_Settings_PreviewNoSpinner")
                local tw  = getTextManager():MeasureStringX(UIFont.Small, txt)
                pv:drawText(txt,
                    math.floor((pv.width - tw) / 2),
                    math.floor((pv.height - TH2.FONT_HGT_SMALL) / 2),
                    TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.6, UIFont.Small)
            end
        end,
    })
    cy = cy + SPIN_PREV_H + TH.GAP

    -- ── HUD position block ────────────────────────────────────────────────────
    ManualSave.makePanel(p, {
        x=0, y=cy, w=w, h=1,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.35 }, border=false,
    })
    cy = cy + 1 + TH.GAP

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_HudPosTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_HudPosDesc") end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    -- Shared HUD position state
    local hudPosX  = tonumber(ManualSave.Config.get("HUD_POS_X")) or 0.500
    local hudPosY  = tonumber(ManualSave.Config.get("HUD_POS_Y")) or 0.880
    local hudHid   = ManualSave.Config.get("HUD_HIDDEN") == "1"
    local dragging = false
    local snapVX   = nil
    local snapHY   = nil

    local ANCHORS = {
        { id="tl", x=0.05, y=0.08 }, { id="tc", x=0.50, y=0.08 }, { id="tr", x=0.95, y=0.08 },
        { id="ml", x=0.05, y=0.50 }, { id="mc", x=0.50, y=0.50 }, { id="mr", x=0.95, y=0.50 },
        { id="bl", x=0.05, y=0.88 }, { id="bc", x=0.50, y=0.88 }, { id="br", x=0.95, y=0.88 },
    }
    local SNAP_THRESH = 0.06

    local function findAnchor()
        for _, a in ipairs(ANCHORS) do
            if math.abs(a.x - hudPosX) < 0.001 and math.abs(a.y - hudPosY) < 0.001 then
                return a.id
            end
        end
        return nil
    end

    local function applySnap(nx, ny)
        snapVX = nil; snapHY = nil
        local ox, oy = nx, ny
        local bestDX, bestDY = SNAP_THRESH, SNAP_THRESH
        for _, a in ipairs(ANCHORS) do
            local dx = math.abs(a.x - ox)
            local dy = math.abs(a.y - oy)
            if dx < bestDX then nx = a.x; bestDX = dx; snapVX = a.x end
            if dy < bestDY then ny = a.y; bestDY = dy; snapHY = a.y end
        end
        return nx, ny
    end

    local function saveHudPos()
        ManualSave.Config.set("HUD_POS_X", string.format("%.3f", hudPosX))
        ManualSave.Config.set("HUD_POS_Y", string.format("%.3f", hudPosY))
    end

    -- Layout constants
    local COMP_W    = 120
    local COMP_H    = 68
    local COMBO_GAP = TH.GAP * 2
    local schW      = w - 28 - COMBO_GAP - COMP_W
    local SCH_H     = 98
    local CELL_GAP  = 2
    local cellW     = math.floor((COMP_W - CELL_GAP * 2) / 3)
    local cellH     = math.floor((COMP_H - CELL_GAP * 2) / 3)
    local COMBO_H   = math.max(SCH_H + 4 + TH.FONT_HGT_SMALL,
                               TH.FONT_HGT_SMALL + 2 + COMP_H + TH.GAP + TH.BUTTON_HGT)

    local combo = ManualSave.makePanel(p, {
        x=14, y=cy, w=w-28, h=COMBO_H,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
    })

    -- Schematic (click-to-place + drag)
    ManualSave.makePanel(combo, {
        x=0, y=0, w=schW, h=SCH_H,
        bg={ r=TH.BG_R * 0.55, g=TH.BG_G * 0.50, b=TH.BG_B * 0.45, a=1 }, border=false,
        prerender = function(pv)
            local TH2 = ManualSave.Theme

            -- Drag update
            if dragging then
                local mdown = false
                pcall(function() mdown = getCore():isLeftMouseButtonDown() end)
                if not mdown then
                    dragging = false; snapVX = nil; snapHY = nil
                    saveHudPos()
                else
                    local ax, ay = 0, 0
                    pcall(function() ax = pv:getAbsoluteX(); ay = pv:getAbsoluteY() end)
                    local nx = math.max(0.02, math.min(0.98, (getMouseX() - ax) / pv.width))
                    local ny = math.max(0.02, math.min(0.98, (getMouseY() - ay) / pv.height))
                    hudPosX, hudPosY = applySnap(nx, ny)
                end
            end

            pv:drawRectBorder(0, 0, pv.width, pv.height, 0.35,
                TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)

            if hudHid then
                local txt = getText("UI_MSM_Settings_PreviewHudHidden")
                local tw  = getTextManager():MeasureStringX(UIFont.Small, txt)
                pv:drawText(txt,
                    math.floor((pv.width - tw) / 2),
                    math.floor((pv.height - TH2.FONT_HGT_SMALL) / 2),
                    TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.55, UIFont.Small)
                return
            end

            -- Moodle strip (top-right)
            pv:drawRect(pv.width - 9, 3, 6, 28, 0.12, 1, 1, 1)
            -- Player dot (center)
            local pdX = math.floor(pv.width / 2) - 2
            local pdY = math.floor(pv.height / 2) - 2
            pv:drawRect(pdX, pdY, 4, 4, 0.20, 1, 1, 1)
            -- Hotbar outline (bottom center)
            local hbW = math.floor(pv.width * 0.38)
            local hbX = math.floor((pv.width - hbW) / 2)
            local hbY = pv.height - 7
            pv:drawRectBorder(hbX, hbY, hbW, 4, 0.22, TH2.DIM_R, TH2.DIM_G, TH2.DIM_B)

            -- Snap guides (green)
            if snapVX then
                pv:drawRect(math.floor(snapVX * pv.width), 0, 1, pv.height,
                    0.5, 0.30, 0.68, 0.26)
            end
            if snapHY then
                pv:drawRect(0, math.floor(snapHY * pv.height), pv.width, 1,
                    0.5, 0.30, 0.68, 0.26)
            end

            -- Indicator pill
            local IND_W, IND_H = 34, 7
            local indX = math.floor(hudPosX * pv.width) - math.floor(IND_W / 2)
            local indY = math.floor(hudPosY * pv.height) - math.floor(IND_H / 2)
            indX = math.max(0, math.min(pv.width  - IND_W, indX))
            indY = math.max(0, math.min(pv.height - IND_H, indY))
            pv:drawRect(indX, indY, IND_W, IND_H, 0.9,
                TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
        end,
        onMouseDown = function(sp, mx, my)
            if hudHid then return end
            local indPx = math.floor(hudPosX * sp.width)
            local indPy = math.floor(hudPosY * sp.height)
            if math.abs(mx - indPx) <= 20 and math.abs(my - indPy) <= 12 then
                dragging = true
            else
                local nx = math.max(0.02, math.min(0.98, mx / sp.width))
                local ny = math.max(0.02, math.min(0.98, my / sp.height))
                hudPosX, hudPosY = applySnap(nx, ny)
                saveHudPos()
            end
        end,
        onMouseUp = function(_, _, _)
            if dragging then
                dragging = false; snapVX = nil; snapHY = nil
                saveHudPos()
            end
        end,
    })

    -- Coords readout
    ManualSave.makePanel(combo, {
        x=0, y=SCH_H + 4, w=schW, h=TH.FONT_HGT_SMALL,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
        prerender = function(pv)
            local TH2 = ManualSave.Theme
            local txt
            if hudHid then
                txt = getText("UI_MSM_Settings_PreviewHudHidden")
            else
                local aid   = findAnchor()
                local aname = aid and getText("UI_MSM_Anchor_" .. aid) or getText("UI_MSM_Anchor_Custom")
                txt = aname .. "   X " .. string.format("%.1f", hudPosX * 100) .. "%"
                          .. "   Y " .. string.format("%.1f", hudPosY * 100) .. "%"
            end
            pv:drawText(txt, 0, 0, TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.7, UIFont.Small)
        end,
    })

    -- Compass label
    local compassX = schW + COMBO_GAP
    ManualSave.makePanel(combo, {
        x=compassX, y=0, w=COMP_W, h=TH.FONT_HGT_SMALL,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
        prerender = function(pv)
            local TH2 = ManualSave.Theme
            pv:drawText(getText("UI_MSM_Settings_Compass"), 0, 0,
                TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.6, UIFont.Small)
        end,
    })

    -- Compass 3x3 grid
    local gridY = TH.FONT_HGT_SMALL + 2
    local anchorGrid = {
        { "tl", "tc", "tr" },
        { "ml", "mc", "mr" },
        { "bl", "bc", "br" },
    }
    for row = 0, 2 do
        for col = 0, 2 do
            local aid = anchorGrid[row + 1][col + 1]
            local cx2 = compassX + col * (cellW + CELL_GAP)
            local cy2 = gridY    + row * (cellH + CELL_GAP)
            local capturedId = aid
            ManualSave.makePanel(combo, {
                x=cx2, y=cy2, w=cellW, h=cellH,
                bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }, border=false,
                prerender = function(pv)
                    local TH2    = ManualSave.Theme
                    local active = (findAnchor() == capturedId)
                    local over   = false
                    pcall(function() over = pv:isMouseOver() end)
                    if active then
                        pv:drawRect(0, 0, pv.width, pv.height, 0.10,
                            TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                        pv:drawRectBorder(0, 0, pv.width, pv.height, 0.55,
                            TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                    else
                        if over then
                            pv:drawRect(0, 0, pv.width, pv.height, 0.06, 1, 1, 1)
                        end
                        pv:drawRectBorder(0, 0, pv.width, pv.height, 0.25,
                            TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
                    end
                    local barW = active and 18 or 14
                    local barH = active and 3  or 2
                    local bX   = math.floor((pv.width  - barW) / 2)
                    local bY   = math.floor((pv.height - barH) / 2)
                    local bA   = active and 0.9 or 0.35
                    local bR   = active and TH2.ACCENT_R or TH2.DIM_R
                    local bG   = active and TH2.ACCENT_G or TH2.DIM_G
                    local bB2  = active and TH2.ACCENT_B or TH2.DIM_B
                    pv:drawRect(bX, bY, barW, barH, bA, bR, bG, bB2)
                end,
                onMouseDown = function()
                    for _, a in ipairs(ANCHORS) do
                        if a.id == capturedId then
                            hudPosX, hudPosY = a.x, a.y
                            hudHid = false; snapVX = nil; snapHY = nil
                            ManualSave.Config.set("HUD_POS_X", string.format("%.3f", hudPosX))
                            ManualSave.Config.set("HUD_POS_Y", string.format("%.3f", hudPosY))
                            ManualSave.Config.set("HUD_HIDDEN", "0")
                            break
                        end
                    end
                    return true
                end,
            })
        end
    end

    -- Hide HUD toggle
    local hideBtnY = gridY + 3 * cellH + 2 * CELL_GAP + TH.GAP
    ManualSave.makePanel(combo, {
        x=compassX, y=hideBtnY, w=COMP_W, h=TH.BUTTON_HGT,
        bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 }, border=false,
        prerender = function(pv)
            local TH2  = ManualSave.Theme
            local over = false
            pcall(function() over = pv:isMouseOver() end)
            if hudHid then
                pv:drawRect(0, 0, pv.width, pv.height, 0.12,
                    TH2.DANGER_R, TH2.DANGER_G, TH2.DANGER_B)
                pv:drawRectBorder(0, 0, pv.width, pv.height, 0.55,
                    TH2.DANGER_R, TH2.DANGER_G, TH2.DANGER_B)
            else
                if over then
                    pv:drawRect(0, 0, pv.width, pv.height, 0.06, 1, 1, 1)
                end
                pv:drawRectBorder(0, 0, pv.width, pv.height, 0.30,
                    TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
            end
            -- Dot icon
            local dotSz = 6
            local dotX  = 8
            local dotY  = math.floor((pv.height - dotSz) / 2)
            if hudHid then
                pv:drawRect(dotX, dotY, dotSz, dotSz, 0.9,
                    TH2.DANGER_R, TH2.DANGER_G, TH2.DANGER_B)
            else
                pv:drawRectBorder(dotX, dotY, dotSz, dotSz, 0.55,
                    TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B)
            end
            -- Label
            local lbl = getText("UI_MSM_Settings_HideHud")
            local tR  = hudHid and TH2.DANGER_R or TH2.MUTED_R
            local tG  = hudHid and TH2.DANGER_G or TH2.MUTED_G
            local tB  = hudHid and TH2.DANGER_B or TH2.MUTED_B
            local ty2 = math.floor((pv.height - TH2.FONT_HGT_SMALL) / 2)
            pv:drawText(lbl, dotX + dotSz + 6, ty2, tR, tG, tB, 1, UIFont.Small)
        end,
        onMouseDown = function()
            hudHid = not hudHid
            ManualSave.Config.set("HUD_HIDDEN", hudHid and "1" or "0")
            return true
        end,
    })

    return p
end

local function buildPaths(parent, x, y, w, h)
    local TH = ManualSave.Theme
    local p  = ManualSave.makePanel(parent, {
        x=x, y=y, w=w, h=h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local cy = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavPaths") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    local sepH = 1
    ManualSave.makePanel(p, {
        x=0, y=cy, w=w, h=sepH,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.5 }, border=false,
    })
    cy = cy + sepH + TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_BackupTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + 2
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_BackupDesc") end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP + 4

    local resetW  = ManualSave.textBtnW(getText("UI_MSM_Settings_BtnResetPath"), 70)
    local inputW  = w - 14 - resetW - TH.GAP - 14
    local inputH  = TH.BUTTON_HGT + 2

    local inp
    inp = ManualSave.makeTextInput(p, {
        x=14, y=cy, w=inputW, h=inputH,
        value       = ManualSave.Config.get("BACKUP_DIR"),
        placeholder = getText("UI_MSM_Settings_BackupPlaceholder"),
        onLostFocus = function()
            ManualSave.Config.set("BACKUP_DIR", inp.getValue())
        end,
        onCommandEntered = function()
            ManualSave.Config.set("BACKUP_DIR", inp.getValue())
        end,
    })
    ManualSave.makeButton(p, {
        x=14 + inputW + TH.GAP, y=cy, w=resetW, h=inputH,
        label   = getText("UI_MSM_Settings_BtnResetPath"),
        style   = "normal",
        onClick = function()
            ManualSave.Config.set("BACKUP_DIR", "")
            inp.setValue("")
        end,
    })
    cy = cy + inputH + TH.GAP

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_BackupDefault") end,
        r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=0.9,
    })

    return p
end

local function buildAdvanced(parent, x, y, w, h)
    local TH    = ManualSave.Theme
    local p     = ManualSave.makePanel(parent, {
        x=x, y=y, w=w, h=h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local ROW_H = TH.FONT_HGT_SMALL * 2 + 28
    local cy    = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavAdvanced") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    makeCheckRow(p, {
        x=0, y=cy, w=w, h=ROW_H,
        label    = getText("UI_MSM_Settings_VerboseTitle"),
        desc     = getText("UI_MSM_Settings_VerboseDesc"),
        getValue = function() return ManualSave.Config.get("VERBOSE_LOG") ~= "0" end,
        onToggle = function()
            ManualSave.Config.set("VERBOSE_LOG",
                ManualSave.Config.get("VERBOSE_LOG") == "0" and "1" or "0")
        end,
    })
    cy = cy + ROW_H + TH.PAD

    -- Danger zone
    local sep = ISPanel:new(14, cy, w - 28, 1)
    sep.backgroundColor = { r=TH.DANGER_R * 0.7, g=TH.DANGER_G * 0.4, b=TH.DANGER_B * 0.35, a=0.9 }
    sep.borderColor     = { r=0, g=0, b=0, a=0 }
    sep:initialise(); sep:instantiate()
    p:addChild(sep)
    cy = cy + 1 + 6

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_DangerZone") end,
        r=TH.DANGER_R, g=TH.DANGER_G, b=TH.DANGER_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    local btnW = ManualSave.textBtnW(getText("UI_MSM_Settings_BtnResetAll"), 80)
    ManualSave.makeButton(p, {
        x=14, y=cy, w=btnW, h=TH.BUTTON_HGT,
        label   = getText("UI_MSM_Settings_BtnResetAll"),
        style   = "danger",
        onClick = function()
            if _resetDialogOpen then return end
            _resetDialogOpen = true
            ManualSave.openConfirmDialog({
                title   = getText("UI_MSM_Settings_ResetAllTitle"),
                body    = getText("UI_MSM_Settings_ResetAllBody"),
                confirm = getText("UI_MSM_Settings_BtnResetAll"),
                danger  = true,
                onConfirm = function()
                    _resetDialogOpen = false
                    ManualSave.Config.reset()
                    ManualSave.closeSettingsScreen()
                    ManualSave.openSettingsScreen()
                end,
                onCancel = function()
                    _resetDialogOpen = false
                end,
            })
        end,
    })

    return p
end

-- ── Nav ───────────────────────────────────────────────────────────────────────

local function buildNav(parent, y, h)
    local TH = ManualSave.Theme
    local p  = ManualSave.makePanel(parent, {
        x=0, y=y, w=NAV_W, h=h, border=false,
        bg={ r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B, a=1 },
        prerender = function(np)
            np:drawRect(np.width - 1, 0, 1, np.height, 1,
                TH.LINE_R, TH.LINE_G, TH.LINE_B)
        end,
    })

    local NAV_ITEM_H = TH.FONT_HGT_SMALL + 18
    local iy = 8
    for _, sec in ipairs(SECTIONS) do
        local id = sec.id
        local btn = ISButton:new(0, iy, NAV_W - 1, NAV_ITEM_H, getText(sec.labelKey), p, function()
            if _section == id then return end
            _section = id
            for sid, sp in pairs(_sectionPanels) do
                sp:setVisible(sid == id)
            end
        end)
        btn:initialise()
        btn:instantiate()
        btn.backgroundColor          = { r=0, g=0, b=0, a=0 }
        btn.backgroundColorMouseOver = { r=0, g=0, b=0, a=0 }
        btn.borderColor              = { r=0, g=0, b=0, a=0 }
        btn.textColor                = { r=0, g=0, b=0, a=0 }
        local capturedId = id
        btn.render = function(self2)
            local TH2      = ManualSave.Theme
            local isActive = (_section == capturedId)
            local over     = false
            pcall(function() over = self2:isMouseOver() end)

            if isActive then
                self2:drawRect(0, 0, self2.width, self2.height, 0.12,
                    TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
                self2:drawRect(0, 0, 3, self2.height, 1,
                    TH2.ACCENT_R, TH2.ACCENT_G, TH2.ACCENT_B)
            elseif over then
                self2:drawRect(0, 0, self2.width, self2.height, 0.06, 1, 1, 1)
            end

            local fh  = TH2.FONT_HGT_SMALL
            local ty2 = math.floor((self2.height - fh) / 2)
            local tR  = isActive and TH2.TEXT_R or TH2.MUTED_R
            local tG  = isActive and TH2.TEXT_G or TH2.MUTED_G
            local tB  = isActive and TH2.TEXT_B or TH2.MUTED_B
            self2:drawText(self2:getTitle(), 14, ty2, tR, tG, tB, 1, UIFont.Small)
        end
        p:addChild(btn)
        iy = iy + NAV_ITEM_H + 2
    end

    return p
end

-- ── Open / Close ──────────────────────────────────────────────────────────────

function ManualSave.openSettingsScreen()
    if _screen then
        _screen.panel:bringToTop()
        return
    end

    local TH = ManualSave.Theme
    _section       = "general"
    _sectionPanels = {}

    local footerH = TH.FONT_HGT_SMALL + TH.PAD * 2
    local cy      = 0

    local d = ManualSave.makeFloatingPanel({
        w=W, h=H,
        title   = getText("UI_MSM_Settings_Title"),
        onClose = function() ManualSave.closeSettingsScreen() end,
    })
    _screen = d

    cy = d.titleH
    local ch = H - cy

    buildNav(d.panel, cy, ch)

    local sx = NAV_W + 1
    local sw = W - NAV_W - 1
    local sh = ch - footerH

    local builders = {
        general  = buildGeneral,
        progress = buildProgress,
        paths    = buildPaths,
        advanced = buildAdvanced,
    }
    for _, sec in ipairs(SECTIONS) do
        local sp = builders[sec.id](d.panel, sx, cy, sw, sh)
        _sectionPanels[sec.id] = sp
        sp:setVisible(sec.id == _section)
    end

    -- Footer separator + "saved" hint
    local fY = H - footerH
    ManualSave.makePanel(d.panel, {
        x=sx, y=fY, w=sw, h=1,
        bg={ r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.5 }, border=false,
    })
    ManualSave.makeLabel(d.panel, {
        x=sx + TH.PAD, y=fY + TH.PAD, w=sw - TH.PAD * 2,
        getText = function() return getText("UI_MSM_Settings_Saved") end,
        r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=0.8,
    })

    d.open()
end

function ManualSave.closeSettingsScreen()
    if not _screen then return end
    local d        = _screen
    _screen        = nil
    _sectionPanels = {}
    _resetDialogOpen = false
    d.close()
end

print("[ManualSaveMod] UI/Screens/SettingsScreen.lua loaded.")
