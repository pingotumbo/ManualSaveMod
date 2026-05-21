-- UI/Base/Dialogs.lua
-- High-level dialog helpers.  Screen code calls these instead of building
-- panels directly.  Two flavours:
--   openConfirmDialog  — aggressive modal (dark overlay, no click-outside close)
--                        for destructive actions (delete, load-with-flags)
--   openNameInputDialog — non-aggressive popup (transparent overlay, closes on
--                         click outside) for rename / export-as operations
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, undefined-field

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

    -- The dialog's nav was auto-installed by makeModalPanel. Buttons added below
    -- auto-register into it via parent walk-up; we only need to set the default
    -- focus on Confirm so Enter activates the primary action immediately.

    -- Confirm button (right side, visually). Created first so visual layout is correct;
    -- registered explicitly into the group below in the right L-R focus order.
    local confirmObj = ManualSave.makeButton(p, {
        x = W - (btnW + TH.PAD),
        y = btnY,
        w = btnW, h = btnH,
        label = opts.confirm or getText("UI_MSM_Dialog_BtnConfirm"),
        style = opts.danger and "danger" or "primary",
        focusGroup = false,  -- registered manually below for correct L-R order
        onClick = function()
            d.close()
            if opts.onConfirm then pcall(opts.onConfirm) end
        end,
    })

    local cancelObj = (not opts._infoOnly) and ManualSave.makeButton(p, {
        x = W - (btnW + TH.PAD) * 2 - TH.GAP,
        y = btnY,
        w = btnW, h = btnH,
        label = opts.cancel or getText("UI_MSM_Common_BtnCancel"),
        style = "normal",
        focusGroup = false,
        onClick = function()
            d.close()
            if opts.onCancel then pcall(opts.onCancel) end
        end,
    })

    -- Register in visual left-to-right order and focus Confirm by default.
    -- Info-only dialogs (single OK button) skip the cancel registration.
    local btnGroup = p._inputNavGroup
    if btnGroup then
        if cancelObj then btnGroup:add(cancelObj.btn) end
        btnGroup:add(confirmObj.btn)
        btnGroup:setFocus(confirmObj.btn)
    end

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

-- Opens a blocking info dialog with a single OK button.
--
-- opts:
--   title    string
--   body     string         one or more lines (auto-wraps)
--   ok       string?        OK button label (default "OK")
--   onClose  fun()?         called after the dialog closes
--
-- Simple wrapper around openConfirmDialog: re-uses the same modal layout but
-- hides the Cancel button so the user sees a single primary action. Use for
-- read-only notifications like crash-recovery alerts.
function ManualSave.openInfoDialog(opts)
    return ManualSave.openConfirmDialog({
        title     = opts.title,
        body      = opts.body,
        confirm   = opts.ok or "OK",
        cancel    = "",
        onConfirm = function() if opts.onClose then pcall(opts.onClose) end end,
        onCancel  = function() if opts.onClose then pcall(opts.onClose) end end,
        _infoOnly = true,
    })
end

-- Opens a blocking modal that captures the next keyboard key pressed.
--
-- opts:
--   title    string?       header text (default getText("UI_MSM_KeyCapture_Title"))
--   body     string?       prompt text (default getText("UI_MSM_KeyCapture_Body"))
--   onKey    fun(name:string)?   called with the short key name ("K", "F9", ...)
--                                or "" if cleared via the Unbind button
--   allowUnbind boolean?   if true, shows a "Clear binding" button
--
-- The dialog auto-installs a transient Events.OnKeyPressed listener that fires
-- exactly once. Escape cancels without changing the binding. The modal is
-- aggressive (dark overlay, click-outside disabled) so the user can hit any
-- key without worrying about accidentally dismissing the popup.
function ManualSave.openKeyCaptureDialog(opts)
    opts = opts or {}
    local TH = ManualSave.Theme

    local function codeToName(code)
        if not Keyboard then return "" end
        for k, v in pairs(Keyboard) do
            if v == code and type(k) == "string" then
                return (k:gsub("^KEY_", ""))
            end
        end
        return ""
    end

    local title = opts.title or getText("UI_MSM_KeyCapture_Title")
    local body  = opts.body  or getText("UI_MSM_KeyCapture_Body")

    local cancelLabel = getText("UI_MSM_Common_BtnCancel")
    local unbindLabel = getText("UI_MSM_KeyCapture_Unbind")
    local cancelW = ManualSave.textBtnW(cancelLabel, 80)
    local unbindW = ManualSave.textBtnW(unbindLabel, 100)
    local W = math.max(360, TH.PAD * 2 + cancelW + TH.GAP + unbindW)
    local lineH     = TH.FONT_HGT_SMALL + 4
    local bodyY     = TH.PAD + TH.FONT_HGT_MEDIUM + TH.GAP * 2
    local bodyLines = wrapBody(body, W - TH.PAD * 2)
    local H = math.max(170, bodyY + #bodyLines * lineH + 48 + TH.GAP)

    local d = ManualSave.makeModalPanel({ w=W, h=H })
    local p = d.panel

    local done = false
    local listener
    local function finish(name)
        if done then return end
        done = true
        if listener then
            Events.OnKeyPressed.Remove(listener)
            listener = nil
        end
        d.close()
        if name ~= nil and opts.onKey then pcall(opts.onKey, name) end
    end

    p.prerender = function(self2)
        ISPanel.prerender(self2)
        local ty = TH.PAD
        self2:drawText(title,
            TH.PAD, ty, TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1, UIFont.Medium)
        local by = ty + TH.FONT_HGT_MEDIUM + TH.GAP * 2
        for _, line in ipairs(bodyLines) do
            self2:drawText(line, TH.PAD, by,
                TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 1, UIFont.Small)
            by = by + lineH
        end
        ManualSave.Draw.separator(self2, 0, H - 48, W, 0.4)
    end

    local btnY = H - 38
    local btnH = TH.BUTTON_HGT

    local cancelObj = ManualSave.makeButton(p, {
        x = TH.PAD, y = btnY, w = cancelW, h = btnH,
        label = cancelLabel, style = "normal",
        focusGroup = false,
        onClick = function() finish(nil) end,
    })

    local unbindObj
    if opts.allowUnbind then
        unbindObj = ManualSave.makeButton(p, {
            x = W - TH.PAD - unbindW, y = btnY, w = unbindW, h = btnH,
            label = unbindLabel, style = "danger",
            focusGroup = false,
            onClick = function() finish("") end,
        })
    end

    local btnGroup = p._inputNavGroup
    if btnGroup then
        btnGroup:add(cancelObj.btn)
        if unbindObj then btnGroup:add(unbindObj.btn) end
        btnGroup:setFocus(cancelObj.btn)
    end

    -- The OnKeyPressed listener is what actually captures the binding. Buttons
    -- in the modal still receive their own clicks via mouse/joypad.
    listener = function(key)
        if done then return end
        if key == Keyboard.KEY_ESCAPE then
            finish(nil)
            return
        end
        local name = codeToName(key)
        if name == "" then return end
        finish(name)
    end
    Events.OnKeyPressed.Add(listener)

    d.onClose(function()
        if listener then
            Events.OnKeyPressed.Remove(listener)
            listener = nil
        end
    end)

    d.open()
    return d
end

-- Opens a non-blocking name-input popup.
--
-- opts:
--   title       string
--   placeholder string?         hint text in the input field
--   value       string?         initial value
--   confirm     string?         confirm button label  (default "OK")
--   anchorX/Y   number?         anchor for tooltip-style positioning
--   x, y        number?         explicit position (overrides anchor)
--   helpSection string?         if set, shows a "?" button that opens HelpScreen to this section
--   names       string[]?       list of forbidden names; auto-generates validate from it
--   validate    fun(string)?    custom validation; takes precedence over names
--   onConfirm   fun(name:string)?
--   onCancel    fun()?
--
function ManualSave.openNameInputDialog(opts)
    local TH = ManualSave.Theme
    -- Auto-build validate from names list when no explicit validate is provided
    if opts.names and not opts.validate then
        local nameSet = {}
        for _, n in ipairs(opts.names) do
            local k = ManualSave.sanitize and ManualSave.sanitize(n) or n
            if k ~= "" then nameSet[k] = true end
        end
        opts.validate = function(name)
            local k = ManualSave.sanitize and ManualSave.sanitize(name) or name
            if k ~= "" and nameSet[k] then return getText("UI_MSM_ErrNameExists") end
        end
    end
    local confirmLabel = opts.confirm or "OK"
    local cancelLabel  = getText("UI_MSM_Common_BtnCancel")
    local btnW = math.max(
        ManualSave.textBtnW(confirmLabel, 60),
        ManualSave.textBtnW(cancelLabel,  60))
    local W        = math.max(300, TH.PAD * 2 + btnW * 2 + TH.GAP)
    local inputY   = TH.PAD + TH.FONT_HGT_SMALL + TH.GAP
    local errLineH = TH.FONT_HGT_SMALL + 2
    local errY     = inputY + TH.BUTTON_HGT + TH.GAP
    local btnY     = errY + errLineH + TH.GAP
    local H        = btnY + TH.BUTTON_HGT + TH.PAD
    local errMsg   = ""

    local d = ManualSave.makePopupPanel({
        w = W, h = H,
        anchorX = opts.anchorX, anchorY = opts.anchorY,
        x = opts.x, y = opts.y,
        onClose = opts.onCancel,
    })
    local p = d.panel

    ManualSave.makeLabel(p, {
        x = TH.PAD, y = TH.PAD, w = W - TH.PAD * 2, h = TH.FONT_HGT_SMALL,
        text = opts.title or "",
    })
    ManualSave.makeLabel(p, {
        x = TH.PAD, y = errY, w = W - TH.PAD * 2, h = errLineH,
        getText = function() return errMsg end,
        r = 0.90, g = 0.25, b = 0.22, a = 1,
    })

    -- Forward declare so the shared submit function can reference both before
    -- they exist; Lua captures the variables, not their current values.
    local ti, confirmObj
    local function doSubmit()
        local name = ti.getValue()
        if opts.validate then
            local err = opts.validate(name)
            if err then
                errMsg = err
                return
            end
        end
        d.close()
        if opts.onConfirm and name ~= "" then
            pcall(opts.onConfirm, name)
        end
    end

    ti = ManualSave.makeTextInput(p, {
        x = TH.PAD,
        y = inputY,
        w = W - TH.PAD * 2,
        h = TH.BUTTON_HGT,
        placeholder = opts.placeholder or "",
        value = opts.value or "",
        -- Enter in the text input submits (PZ may consume the key before our
        -- global handler can route it to the dialog's Confirm button).
        onCommandEntered = doSubmit,
        onChange = opts.validate and function(text)
            errMsg = opts.validate(text)
        end or nil,
    })

    -- Nav was auto-installed by makePopupPanel. Buttons created below use
    -- focusGroup=false and are manually added in the right L-R focus order;
    -- the TextInput above auto-registers itself so Tab can move to/from it.
    confirmObj = ManualSave.makeButton(p, {
        x = W - (btnW + TH.PAD),
        y = btnY,
        w = btnW, h = TH.BUTTON_HGT,
        label = opts.confirm or "OK",
        style = "primary",
        focusGroup = false,
        onClick = doSubmit,
    })

    local cancelObj = ManualSave.makeButton(p, {
        x = W - (btnW + TH.PAD) * 2 - TH.GAP,
        y = btnY,
        w = btnW, h = TH.BUTTON_HGT,
        label = getText("UI_MSM_Common_BtnCancel"),
        style = "normal",
        focusGroup = false,
        onClick = function()
            d.close()
        end,
    })

    local btnGroup = p._inputNavGroup
    if btnGroup then
        btnGroup:add(cancelObj.btn)
        btnGroup:add(confirmObj.btn)
        btnGroup:setFocus(confirmObj.btn)
    end

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
    -- Auto-focus the text input so the user can type the name immediately
    -- (Enter still triggers Confirm via the focused button in nav).
    if ti and ti.focus then pcall(ti.focus) end
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

    -- Nav was auto-installed by makeModalPanel. Buttons created below use
    -- focusGroup=false and are registered manually in visual L-R order.
    local cancelObj = ManualSave.makeButton(p, {
        x=TH.PAD, y=btnY, w=cancelW, h=btnH,
        label=cancelLabel, style="normal",
        focusGroup = false,
        onClick=function()
            d.close()
            if opts.onCancel then pcall(opts.onCancel) end
        end,
    })
    local exitObj = ManualSave.makeButton(p, {
        x=exitX, y=btnY, w=exitW, h=btnH,
        label=exitLabel, style="danger",
        focusGroup = false,
        onClick=function()
            d.close()
            if opts.onExit then pcall(opts.onExit) end
        end,
    })
    local returnObj = ManualSave.makeButton(p, {
        x=returnX, y=btnY, w=returnW, h=btnH,
        label=returnLabel, style="primary",
        focusGroup = false,
        onClick=function()
            d.close()
            if opts.onReturn then pcall(opts.onReturn) end
        end,
    })

    local btnGroup = p._inputNavGroup
    if btnGroup then
        btnGroup:add(cancelObj.btn)
        btnGroup:add(exitObj.btn)
        btnGroup:add(returnObj.btn)
        btnGroup:setFocus(returnObj.btn)
    end

    d.open()
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Dialogs.lua loaded.")
