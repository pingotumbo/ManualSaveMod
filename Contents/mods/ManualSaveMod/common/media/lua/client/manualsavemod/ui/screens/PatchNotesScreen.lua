-- UI/Screens/PatchNotesScreen.lua
-- "What's New" popup shown over the Load screen when opened from the main menu.
-- Blocking modal: title bar + version badge + X, hero highlight cards, a flat
-- "fixed in this update" list, a changelog link, and a footer with a
-- "Don't show again" checkbox (synced to Config SHOW_PATCH_NOTES), Visit
-- website, and Close.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

local W       = 720
local CARD_H  = 98
local ICON_SZ = 56
local _open   = false

-- Opens a URL in the Steam overlay (falls back to the OS browser if available).
local function openURL(url)
    if not url or url == "" then return end
    if activateSteamOverlayToWebPage then
        local ok = pcall(activateSteamOverlayToWebPage, url)
        if ok then return end
    end
    if openUrl then pcall(openUrl, url) end ---@diagnostic disable-line: undefined-global
end

-- Local alias to the shared toolkit helper (loaded earlier from
-- ui/base/widgets/elements/Text.lua). Centralising wrap() in one place means
-- every screen wraps the same way and a future improvement to wrap (e.g.
-- breaking long words) lands everywhere at once.
local wrap = ManualSave.Text.wrap

-- Checkbox-style button: draws a checkbox glyph + label, toggles on activate.
local function makeCheckbox(parent, opts)
    local TH  = ManualSave.Theme
    local FHS = TH.FONT_HGT_SMALL
    return ManualSave.makeButton(parent, {
        x=opts.x, y=opts.y, w=opts.w, h=opts.h, label=opts.label, style="normal",
        onClick = opts.onClick,
        render = function(self2)
            local on    = opts.getValue and opts.getValue() or false
            local cbSz  = 14
            local cbY   = math.floor((self2.height - cbSz) / 2)
            local over  = false
            pcall(function() over = self2:isMouseOver() end)
            if over then self2:drawRect(0, 0, self2.width, self2.height, 0.05, 1, 1, 1) end
            ManualSave.Draw.checkbox(self2, 2, cbY, cbSz, on)
            self2:drawText(self2:getTitle(), 2 + cbSz + 8,
                math.floor((self2.height - FHS) / 2),
                TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Small)
        end,
    })
end

-- Text-link button (accent text, underline on hover), no border.
local function makeLink(parent, opts)
    local TH  = ManualSave.Theme
    local FHS = TH.FONT_HGT_SMALL
    return ManualSave.makeButton(parent, {
        x=opts.x, y=opts.y, w=opts.w, h=opts.h, label=opts.label, style="accent",
        onClick = opts.onClick,
        render = function(self2)
            local over = false
            pcall(function() over = self2:isMouseOver() end)
            local a  = over and 1.0 or 0.85
            local tw = getTextManager():MeasureStringX(UIFont.Small, self2:getTitle())
            local tx = math.floor((self2.width - tw) / 2)
            self2:drawText(self2:getTitle(), tx, math.floor((self2.height - FHS) / 2),
                TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, a, UIFont.Small)
            if over then
                self2:drawRect(tx, math.floor((self2.height + FHS) / 2) + 1, tw, 1, a,
                    TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
            end
        end,
    })
end

function ManualSave.openPatchNotes()
    if _open then return end
    _open = true

    local TH      = ManualSave.Theme
    local PN      = ManualSave.PatchNotes
    local FHS     = TH.FONT_HGT_SMALL
    local FHL     = TH.FONT_HGT_LARGE
    local lh      = FHS + 3
    local titleH  = FHL + 22
    local footerH = TH.BUTTON_HGT + TH.PAD

    local highlights = PN.highlights()
    local fixed      = PN.fixed()

    -- ── Layout pass: compute total height so nothing overflows ────────────────
    -- Cards auto-size in HEIGHT so any wrapped translation can fit, no matter
    -- how long it gets. Per-card height = top pad + title row + gap + N wrapped
    -- desc rows + bottom pad. The two cards in a row share the taller height
    -- so the grid stays aligned.
    local colGap  = TH.GAP
    local cardW   = math.floor((W - TH.PAD * 2 - colGap) / 2)
    local rows    = math.ceil(#highlights / 2)

    local CARD_TOP_PAD    = 12
    local CARD_BOT_PAD    = 12
    local CARD_TITLE_GAP  = 4
    local CARD_TEXT_INSET = 14   -- left padding inside the card before icon/text

    local function cardTextW(hl)
        local inner = cardW - CARD_TEXT_INSET - 12
        if hl.tex then inner = inner - ICON_SZ - 12 end
        return inner
    end
    local function cardDescRows(hl)
        return wrap(hl.desc or "", UIFont.Small, cardTextW(hl))
    end
    -- Per-card content height (text-driven), floored to CARD_H so visually
    -- consistent for short single-line descs too.
    local cardH = {}
    for i, hl in ipairs(highlights) do
        local nRows = #cardDescRows(hl)
        local h = CARD_TOP_PAD + TH.FONT_HGT_MEDIUM + CARD_TITLE_GAP
                + nRows * lh + CARD_BOT_PAD
        cardH[i] = math.max(CARD_H, h)
    end
    -- For each row in the 2-col grid, take the tallest of the two cards.
    local rowH = {}
    for r = 1, rows do
        local h1 = cardH[(r - 1) * 2 + 1] or 0
        local h2 = cardH[(r - 1) * 2 + 2] or 0
        rowH[r] = math.max(h1, h2, CARD_H)
    end
    -- Cumulative Y for each row, and total grid height.
    local rowY  = {}
    local gridH = 0
    do
        local accY = 0
        for r = 1, rows do
            rowY[r] = accY
            accY    = accY + rowH[r] + TH.GAP
        end
        gridH = accY - (rows > 0 and TH.GAP or 0)
    end

    local gridTop  = titleH + TH.PAD
    local fixHdrY  = gridTop + gridH + TH.PAD
    local fixListY = fixHdrY + lh + 4

    -- Wrap every fix line up-front so the list height grows with the longest
    -- translation instead of overflowing to the right. The same wrapped table
    -- is reused by prerender to avoid wrapping twice per frame.
    local FIX_BULLET_INDENT = 18
    local fixTextW          = W - TH.PAD * 2 - FIX_BULLET_INDENT
    local fixedWrapped      = {}
    local fixedTotalRows    = 0
    for _, ln in ipairs(fixed) do
        local wrapped = wrap(ln or "", UIFont.Small, fixTextW)
        table.insert(fixedWrapped, wrapped)
        fixedTotalRows = fixedTotalRows + #wrapped
    end

    local linkY    = fixListY + fixedTotalRows * lh + TH.GAP
    local footerY  = linkY + lh + TH.PAD
    local H        = footerY + footerH + TH.PAD

    -- ── Modal shell ──────────────────────────────────────────────────────────
    local d = ManualSave.makeModalPanel({ w=W, h=H })
    local p = d.panel
    -- Darker body so the PANEL-coloured highlight cards stand out against it.
    p.backgroundColor = { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }

    local function doClose()
        _open = false
        -- Stamp the current mod version so the popup won't auto-reshow on the
        -- next boot for THIS release. A future release (modversion change) will
        -- re-trigger it via maybeShowPatchNotes() even if the user previously
        -- ticked "Don't show this again".
        local v = PN.version() or ""
        if v ~= "" and v ~= "?" then
            ManualSave.Config.set("LAST_SEEN_VERSION", v)
        end
        d.close()
    end

    -- Static content (title bar, badge, cards, fixed list)
    p.prerender = function(self2)
        ISPanel.prerender(self2)
        -- Title bar
        self2:drawRect(0, 0, W, titleH, 1, TH.PANEL_R, TH.PANEL_G, TH.PANEL_B)
        self2:drawRect(0, titleH - 1, W, 1, 1, TH.LINE_R, TH.LINE_G, TH.LINE_B)
        ManualSave.Draw.accentBar(self2, 0, 0, W)
        local ty = math.floor((titleH - FHL) / 2)
        local title = getText("UI_MSM_Patch_Title")
        self2:drawText(title, TH.PAD, ty, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Large)
        -- Version badge
        local badge  = "v" .. PN.version()
        local bw     = getTextManager():MeasureStringX(UIFont.Small, badge) + 14
        local bx     = TH.PAD + getTextManager():MeasureStringX(UIFont.Large, title) + 10
        local bh     = FHS + 6
        local by     = math.floor((titleH - bh) / 2)
        self2:drawRect(bx, by, bw, bh, 0.18, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
        self2:drawRectBorder(bx, by, bw, bh, 0.8, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
        self2:drawText(badge, bx + 7, by + 3, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 1, UIFont.Small)

        -- Hero highlight cards (optional left icon + title + wrapped desc).
        -- Card height is row-driven (computed above) so wrapped desc lines
        -- are never truncated: every line of every translation is shown.
        for i, hl in ipairs(highlights) do
            local col   = (i - 1) % 2
            local rowIx = math.floor((i - 1) / 2) + 1
            local cx    = TH.PAD + col * (cardW + colGap)
            local cy    = gridTop + rowY[rowIx]
            local ch    = rowH[rowIx]
            self2:drawRect(cx, cy, cardW, ch, 1, TH.PANEL_R, TH.PANEL_G, TH.PANEL_B)
            self2:drawRectBorder(cx, cy, cardW, ch, 1, TH.LINE_R, TH.LINE_G, TH.LINE_B)
            self2:drawRect(cx, cy, 3, ch, 1, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
            local textX = cx + CARD_TEXT_INSET
            if hl.tex then
                local iy = cy + math.floor((ch - ICON_SZ) / 2)
                self2:drawTextureScaled(hl.tex, cx + 12, iy, ICON_SZ, ICON_SZ, 1)
                textX = cx + 12 + ICON_SZ + 12
            end
            self2:drawText(hl.title, textX, cy + CARD_TOP_PAD,
                TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 1, UIFont.Medium)
            local dy    = cy + CARD_TOP_PAD + TH.FONT_HGT_MEDIUM + CARD_TITLE_GAP
            local rows2 = cardDescRows(hl)
            for li = 1, #rows2 do
                self2:drawText(rows2[li], textX, dy,
                    TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 1, UIFont.Small)
                dy = dy + lh
            end
        end

        -- "Fixed in this update" header + rule
        local fh = getText("UI_MSM_Patch_FixedHeader")
        self2:drawText(fh, TH.PAD, fixHdrY, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 0.95, UIFont.Small)
        self2:drawRect(TH.PAD, fixHdrY + FHS + 1, W - TH.PAD * 2, 1, 0.3,
            TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
        -- Fixed list (> bullets). Each entry can wrap onto multiple lines;
        -- the bullet aligns with the first line, continuation lines are
        -- indented to match the bullet's text column.
        local fy = fixListY
        for i = 1, #fixed do
            local wrapped = fixedWrapped[i]
            self2:drawText(">", TH.PAD + 4, fy, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 1, UIFont.Small)
            for _, row in ipairs(wrapped) do
                self2:drawText(row, TH.PAD + FIX_BULLET_INDENT, fy,
                    TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 0.85, UIFont.Small)
                fy = fy + lh
            end
        end
        -- Footer separator
        self2:drawRect(0, footerY - math.floor(TH.PAD / 2), W, 1, 1,
            TH.LINE_R, TH.LINE_G, TH.LINE_B)
    end

    -- Draggable title bar: hold the title strip (above titleH, not the X) to move
    -- the window. Child widgets consume their own clicks, so this only fires on
    -- the bare title area.
    p.onMouseDown = function(self2, mx, my)
        if my <= titleH then self2.moveWithMouse = true end
        return ISPanel.onMouseDown(self2, mx, my)
    end
    p.onMouseUp = function(self2, mx, my)
        self2.moveWithMouse = false
        return ISPanel.onMouseUp(self2, mx, my)
    end

    -- X button (top-right)
    local xW = 28
    ManualSave.makeButton(p, {
        x = W - xW - 6, y = math.floor((titleH - xW) / 2), w = xW, h = xW,
        label = "X", style = "normal",
        onClick = doClose,
    })

    -- Changelog link (left-aligned; text centered inside its own button box)
    local linkLabel = getText("UI_MSM_Patch_Changelog")
    local linkW     = getTextManager():MeasureStringX(UIFont.Small, linkLabel) + 14
    makeLink(p, {
        x = TH.PAD, y = linkY, w = linkW, h = lh,
        label = linkLabel,
        onClick = function() openURL(PN.CHANGELOG_URL) end,
    })

    -- Footer: Don't show again (left)
    makeCheckbox(p, {
        x = TH.PAD, y = footerY + math.floor((TH.BUTTON_HGT - (FHS + 6)) / 2),
        w = 220, h = FHS + 6,
        label = getText("UI_MSM_Patch_DontShow"),
        getValue = function() return ManualSave.Config.get("SHOW_PATCH_NOTES") == "0" end,
        onClick = function()
            local suppressed = ManualSave.Config.get("SHOW_PATCH_NOTES") == "0"
            ManualSave.Config.set("SHOW_PATCH_NOTES", suppressed and "1" or "0")
        end,
    })

    -- Footer (right side): Linux feedback + Visit website + Close
    local closeLabel = getText("UI_MSM_Common_BtnClose")
    local siteLabel  = getText("UI_MSM_Patch_Website")
    local linuxLabel = getText("UI_MSM_Patch_LinuxFeedback")
    local closeW     = ManualSave.textBtnW(closeLabel, 80)
    local siteW      = ManualSave.textBtnW(siteLabel, 110)
    local linuxW     = ManualSave.textBtnW(linuxLabel, 150)
    local closeX     = W - TH.PAD - closeW
    local siteX      = closeX - TH.GAP - siteW
    local linuxX     = siteX  - TH.GAP - linuxW
    ManualSave.makeButton(p, {
        x = linuxX, y = footerY, w = linuxW, h = TH.BUTTON_HGT,
        label = linuxLabel, style = "accent",
        onClick = function() openURL(PN.LINUX_FEEDBACK_URL) end,
    })
    ManualSave.makeButton(p, {
        x = siteX, y = footerY, w = siteW, h = TH.BUTTON_HGT,
        label = siteLabel, style = "normal",
        onClick = function() openURL(PN.WEBSITE_URL) end,
    })
    ManualSave.makeButton(p, {
        x = closeX, y = footerY, w = closeW, h = TH.BUTTON_HGT,
        label = closeLabel, style = "primary",
        onClick = doClose,
    })

    d.onClose(function() _open = false end)
    -- Modal manages keyboard focus via its own InputNav group; the blocking
    -- overlay does not transfer joypad focus from the screen below.
    d.open()
end

-- Decides whether the "What's New" popup should auto-open. Called by
-- LoadScreen the first time the user reaches it from the main menu.
--
-- The popup re-emerges on every NEW mod version even when the user has
-- previously ticked "Don't show this again": we compare the current
-- modversion against LAST_SEEN_VERSION (stored when the popup was last
-- closed). When they differ, the popup is forced open (and the "don't show"
-- flag is reset to "1" so the footer checkbox starts unchecked again).
-- When they match, we respect SHOW_PATCH_NOTES.
function ManualSave.maybeShowPatchNotes()
    if _open then return end
    local PN          = ManualSave.PatchNotes
    local currentVer  = (PN and PN.version and PN.version()) or ""
    local lastSeen    = ManualSave.Config.get("LAST_SEEN_VERSION") or ""
    if currentVer ~= "" and currentVer ~= "?" and currentVer ~= lastSeen then
        -- New release: reset the suppression flag so the footer checkbox is
        -- unchecked by default in this release's popup.
        ManualSave.Config.set("SHOW_PATCH_NOTES", "1")
        ManualSave.openPatchNotes()
        return
    end
    if ManualSave.Config.get("SHOW_PATCH_NOTES") ~= "1" then return end
    ManualSave.openPatchNotes()
end

print("[ManualSaveMod] UI/Screens/PatchNotesScreen.lua loaded.")
