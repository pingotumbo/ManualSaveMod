-- UI/Base/Dialogs.lua
-- High-level dialog helpers.  Screen code calls these instead of building
-- panels directly.  Two flavours:
--   openConfirmDialog  — aggressive modal (dark overlay, no click-outside close)
--                        for destructive actions (delete, load-with-flags)
--   openNameInputDialog — non-aggressive popup (transparent overlay, closes on
--                         click outside) for rename / export-as operations
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field

ManualSave = ManualSave or {}

-- Splits text on \n and word-wraps each paragraph to fit within maxW pixels.
-- Returns a flat list of rendered strings (empty string = blank line).
local function wrapBody(text, maxW)
    local tm  = getTextManager()
    local out = {}
    for para in (text .. "\n"):gmatch("([^\n]*)\n") do
        if para == "" then
            table.insert(out, "")
        elseif tm:MeasureStringX(UIFont.Small, para) <= maxW then
            table.insert(out, para)
        else
            local line = ""
            for word in (para .. " "):gmatch("([^ ]+) ") do
                local try = line == "" and word or (line .. " " .. word)
                if tm:MeasureStringX(UIFont.Small, try) <= maxW then
                    line = try
                else
                    if line ~= "" then table.insert(out, line) end
                    line = word
                end
            end
            if line ~= "" then table.insert(out, line) end
        end
    end
    return out
end

-- Opens a blocking confirmation dialog.
--
-- opts:
--   title       string
--   body        string          one or two lines of explanatory text
--   confirm     string?         confirm button label  (default "Confirm")
--   cancel      string?         cancel button label   (default "Cancel")
--   danger      boolean?        if true, confirm button uses "danger" style
--   helpSection string?         if set, shows a "?" button that opens HelpScreen to this section
--   onConfirm   fun()?
--   onCancel    fun()?
--
function ManualSave.openConfirmDialog(opts)
    local TH = ManualSave.Theme
    local confirmLabel = opts.confirm or getText("UI_MSM_Dialog_BtnConfirm")
    local cancelLabel  = opts.cancel  or getText("UI_MSM_Common_BtnCancel")
    local btnW = math.max(
        ManualSave.textBtnW(confirmLabel, 80),
        ManualSave.textBtnW(cancelLabel,  80))
    local W = math.max(360, TH.PAD * 2 + btnW * 2 + TH.GAP)
    local lineH     = TH.FONT_HGT_SMALL + 4
    local bodyY     = TH.PAD + TH.FONT_HGT_MEDIUM + TH.GAP * 2
    local bodyLines = wrapBody(opts.body or "", W - TH.PAD * 2)
    local H = math.max(160, bodyY + #bodyLines * lineH + 48 + TH.GAP)

    local d = ManualSave.makeModalPanel({ w=W, h=H })
    local p = d.panel

    -- Title
    p.prerender = function(self2)
        ISPanel.prerender(self2)
        local ty = TH.PAD
        self2:drawText(opts.title or "",
            TH.PAD, ty, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Medium)
        local by = ty + TH.FONT_HGT_MEDIUM + TH.GAP * 2
        for _, line in ipairs(bodyLines) do
            self2:drawText(line, TH.PAD, by,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 1, UIFont.Small)
            by = by + lineH
        end
        -- Separator above buttons
        ManualSave.Draw.separator(self2, 0, H - 48, W, 0.4)
    end

    local btnY = H - 38
    local btnH = TH.BUTTON_HGT

    ManualSave.makeButton(p, {
        x = W - (btnW + TH.PAD),
        y = btnY,
        w = btnW, h = btnH,
        label = opts.confirm or getText("UI_MSM_Dialog_BtnConfirm"),
        style = opts.danger and "danger" or "primary",
        onClick = function()
            d.close()
            if opts.onConfirm then pcall(opts.onConfirm) end
        end,
    })

    ManualSave.makeButton(p, {
        x = W - (btnW + TH.PAD) * 2 - TH.GAP,
        y = btnY,
        w = btnW, h = btnH,
        label = opts.cancel or getText("UI_MSM_Common_BtnCancel"),
        style = "normal",
        onClick = function()
            d.close()
            if opts.onCancel then pcall(opts.onCancel) end
        end,
    })

    if opts.helpSection then
        ManualSave.makeButton(p, {
            x = W - TH.PAD - 22, y = TH.PAD - 2,
            w = 22, h = 22,
            label = "?", style = "normal",
            onClick = function()
                if ManualSave.openHelpScreen then ManualSave.openHelpScreen(opts.helpSection) end
            end,
        })
    end

    d.onClose(function()
        if opts.onCancel then pcall(opts.onCancel) end
    end)

    d.open()
    return d
end

-- Opens a non-blocking name-input popup.
--
-- opts:
--   title       string
--   placeholder string?     hint text in the input field
--   value       string?     initial value
--   confirm     string?     confirm button label  (default "OK")
--   anchorX/Y   number?     anchor for tooltip-style positioning
--   x, y        number?     explicit position (overrides anchor)
--   helpSection string?     if set, shows a "?" button that opens HelpScreen to this section
--   onConfirm   fun(name:string)?
--   onCancel    fun()?
--
function ManualSave.openNameInputDialog(opts)
    local TH = ManualSave.Theme
    local confirmLabel = opts.confirm or "OK"
    local cancelLabel  = getText("UI_MSM_Common_BtnCancel")
    local btnW = math.max(
        ManualSave.textBtnW(confirmLabel, 60),
        ManualSave.textBtnW(cancelLabel,  60))
    local W = math.max(300, TH.PAD * 2 + btnW * 2 + TH.GAP)
    local H = 110

    local d = ManualSave.makePopupPanel({
        w = W, h = H,
        anchorX = opts.anchorX, anchorY = opts.anchorY,
        x = opts.x, y = opts.y,
        onClose = opts.onCancel,
    })
    local p = d.panel

    -- Title
    p.prerender = function(self2)
        ISPanel.prerender(self2)
        self2:drawText(opts.title or "",
            TH.PAD, TH.PAD, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Small)
    end

    local inputY = TH.PAD + TH.FONT_HGT_SMALL + TH.GAP
    local ti = ManualSave.makeTextInput(p, {
        x = TH.PAD,
        y = inputY,
        w = W - TH.PAD * 2,
        h = TH.BUTTON_HGT,
        placeholder = opts.placeholder or "",
        value = opts.value or "",
    })

    local btnY = inputY + TH.BUTTON_HGT + TH.GAP

    ManualSave.makeButton(p, {
        x = W - (btnW + TH.PAD),
        y = btnY,
        w = btnW, h = TH.BUTTON_HGT,
        label = opts.confirm or "OK",  -- "OK" kept as generic default; callers pass specific labels
        style = "primary",
        onClick = function()
            local name = ti.getValue()
            d.close()
            if opts.onConfirm and name ~= "" then
                pcall(opts.onConfirm, name)
            end
        end,
    })

    ManualSave.makeButton(p, {
        x = W - (btnW + TH.PAD) * 2 - TH.GAP,
        y = btnY,
        w = btnW, h = TH.BUTTON_HGT,
        label = getText("UI_MSM_Common_BtnCancel"),
        style = "normal",
        onClick = function()
            d.close()
        end,
    })

    if opts.helpSection then
        ManualSave.makeButton(p, {
            x = W - TH.PAD - 22, y = TH.PAD - 2,
            w = 22, h = 22,
            label = "?", style = "normal",
            onClick = function()
                if ManualSave.openHelpScreen then ManualSave.openHelpScreen(opts.helpSection) end
            end,
        })
    end

    d.open()
    return d
end

-- Opens a 3-button "Full Save" dialog: Cancel | Save & Exit | Save & Return.
--
-- opts:
--   onExit    fun()?   called when user chooses "Save & Exit"
--   onReturn  fun()?   called when user chooses "Save & Return"
--
function ManualSave.openFullSaveDialog(opts)
    local TH = ManualSave.Theme
    local cancelLabel = getText("UI_MSM_Common_BtnCancel")
    local exitLabel   = getText("UI_MSM_Dialog_BtnSaveExit")
    local returnLabel = getText("UI_MSM_Dialog_BtnSaveReturn")
    local cancelW = ManualSave.textBtnW(cancelLabel, 60)
    local exitW   = ManualSave.textBtnW(exitLabel,   80)
    local returnW = ManualSave.textBtnW(returnLabel, 90)
    local W = math.max(420, TH.PAD * 2 + cancelW + TH.GAP + exitW + TH.GAP + returnW)
    local H = 158

    local d = ManualSave.makeModalPanel({ w=W, h=H })
    local p = d.panel

    p.prerender = function(self2)
        ISPanel.prerender(self2)
        self2:drawText(getText("UI_MSM_Dialog_FullSaveTitle"),
            TH.PAD, TH.PAD, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Medium)
        local y = TH.PAD + TH.FONT_HGT_MEDIUM + TH.GAP * 2
        self2:drawText(getText("UI_MSM_Dialog_FullSaveBody1"),
            TH.PAD, y, TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 1, UIFont.Small)
        self2:drawText(getText("UI_MSM_Dialog_FullSaveBody2"),
            TH.PAD, y + TH.FONT_HGT_SMALL + 4, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Small)
        ManualSave.Draw.separator(self2, 0, H - 48, W, 0.4)
    end

    local btnH     = TH.BUTTON_HGT
    local btnY     = H - btnH - TH.PAD
    local returnX  = W - TH.PAD - returnW
    local exitX    = returnX - TH.GAP - exitW

    ManualSave.makeButton(p, {
        x=TH.PAD, y=btnY, w=cancelW, h=btnH,
        label=cancelLabel, style="normal",
        onClick=function() d.close() end,
    })
    ManualSave.makeButton(p, {
        x=exitX, y=btnY, w=exitW, h=btnH,
        label=exitLabel, style="danger",
        onClick=function()
            d.close()
            if opts.onExit then pcall(opts.onExit) end
        end,
    })
    ManualSave.makeButton(p, {
        x=returnX, y=btnY, w=returnW, h=btnH,
        label=returnLabel, style="primary",
        onClick=function()
            d.close()
            if opts.onReturn then pcall(opts.onReturn) end
        end,
    })

    d.open()
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Dialogs.lua loaded.")
