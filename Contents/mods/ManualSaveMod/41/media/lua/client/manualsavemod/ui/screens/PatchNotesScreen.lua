-- UI/Screens/PatchNotesScreen.lua
-- "What's New" popup shown over the Load screen when opened from the main menu.
-- Blocking modal: title bar + version badge + X, hero highlight cards, a flat
-- "fixed in this update" list, a changelog link, and a footer with a
-- "Don't show again" checkbox (synced to Config SHOW_PATCH_NOTES), Visit
-- website, and Close.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field, inject-field

ManualSave = ManualSave or {}

local W       = 580
local CARD_H  = 70
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

-- Word-wrap a string to maxW pixels for the given font.
local function wrap(text, font, maxW)
    local tm = getTextManager()
    if not text or text == "" then return { "" } end
    if maxW <= 0 or tm:MeasureStringX(font, text) <= maxW then return { text } end
    local out, line = {}, ""
    for word in (text .. " "):gmatch("([^ ]+) ") do
        local try = (line == "") and word or (line .. " " .. word)
        if tm:MeasureStringX(font, try) <= maxW then
            line = try
        else
            if line ~= "" then table.insert(out, line) end
            line = word
        end
    end
    if line ~= "" then table.insert(out, line) end
    if #out == 0 then out[1] = "" end
    return out
end

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
            local a = over and 1.0 or 0.85
            self2:drawText(self2:getTitle(), 0, math.floor((self2.height - FHS) / 2),
                TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, a, UIFont.Small)
            if over then
                local tw = getTextManager():MeasureStringX(UIFont.Small, self2:getTitle())
                self2:drawRect(0, math.floor((self2.height + FHS) / 2) + 1, tw, 1, a,
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
    local colGap  = TH.GAP
    local cardW   = math.floor((W - TH.PAD * 2 - colGap) / 2)
    local rows    = math.ceil(#highlights / 2)
    local gridH   = rows * CARD_H + (rows - 1) * TH.GAP

    local gridTop  = titleH + TH.PAD
    local fixHdrY  = gridTop + gridH + TH.PAD
    local fixListY = fixHdrY + lh + 4
    local linkY    = fixListY + #fixed * lh + TH.GAP
    local footerY  = linkY + lh + TH.PAD
    local H        = footerY + footerH + TH.PAD

    -- ── Modal shell ──────────────────────────────────────────────────────────
    local d = ManualSave.makeModalPanel({ w=W, h=H })
    local p = d.panel
    -- Darker body so the PANEL-coloured highlight cards stand out against it.
    p.backgroundColor = { r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }

    local function doClose()
        _open = false
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

        -- Hero highlight cards
        for i, hl in ipairs(highlights) do
            local col  = (i - 1) % 2
            local row  = math.floor((i - 1) / 2)
            local cx   = TH.PAD + col * (cardW + colGap)
            local cy   = gridTop + row * (CARD_H + TH.GAP)
            self2:drawRect(cx, cy, cardW, CARD_H, 1, TH.PANEL_R, TH.PANEL_G, TH.PANEL_B)
            self2:drawRectBorder(cx, cy, cardW, CARD_H, 1, TH.LINE_R, TH.LINE_G, TH.LINE_B)
            self2:drawRect(cx, cy, 3, CARD_H, 1, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
            self2:drawText(hl.title, cx + 12, cy + 8,
                TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 1, UIFont.Small)
            local dy   = cy + 8 + FHS + 3
            local rows2 = wrap(hl.desc, UIFont.Small, cardW - 22)
            for li = 1, math.min(2, #rows2) do
                self2:drawText(rows2[li], cx + 12, dy,
                    TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 1, UIFont.Small)
                dy = dy + lh
            end
        end

        -- "Fixed in this update" header + rule
        local fh = getText("UI_MSM_Patch_FixedHeader")
        self2:drawText(fh, TH.PAD, fixHdrY, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 0.95, UIFont.Small)
        self2:drawRect(TH.PAD, fixHdrY + FHS + 1, W - TH.PAD * 2, 1, 0.3,
            TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
        -- Fixed list (> bullets)
        local fy = fixListY
        for _, line in ipairs(fixed) do
            self2:drawText(">", TH.PAD + 4, fy, TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B, 1, UIFont.Small)
            self2:drawText(line, TH.PAD + 18, fy, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 0.85, UIFont.Small)
            fy = fy + lh
        end
        -- Footer separator
        self2:drawRect(0, footerY - math.floor(TH.PAD / 2), W, 1, 1,
            TH.LINE_R, TH.LINE_G, TH.LINE_B)
    end

    -- X button (top-right)
    local xW = 28
    ManualSave.makeButton(p, {
        x = W - xW - 6, y = math.floor((titleH - xW) / 2), w = xW, h = xW,
        label = "X", style = "normal",
        onClick = doClose,
    })

    -- Changelog link
    local linkLabel = getText("UI_MSM_Patch_Changelog")
    local linkW     = getTextManager():MeasureStringX(UIFont.Small, linkLabel) + 4
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

    -- Footer: Visit website + Close (right)
    local closeLabel = getText("UI_MSM_Common_BtnClose")
    local siteLabel  = getText("UI_MSM_Patch_Website")
    local closeW     = ManualSave.textBtnW(closeLabel, 80)
    local siteW      = ManualSave.textBtnW(siteLabel, 110)
    local closeX     = W - TH.PAD - closeW
    local siteX      = closeX - TH.GAP - siteW
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

-- Opens the popup only if the user has not suppressed it. Called when the Load
-- screen opens from the main menu.
function ManualSave.maybeShowPatchNotes()
    if _open then return end
    if ManualSave.Config.get("SHOW_PATCH_NOTES") ~= "1" then return end
    ManualSave.openPatchNotes()
end

print("[ManualSaveMod] UI/Screens/PatchNotesScreen.lua loaded.")
