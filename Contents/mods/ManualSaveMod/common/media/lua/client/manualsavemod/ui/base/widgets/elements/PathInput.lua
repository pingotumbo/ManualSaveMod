-- UI/Base/Widgets/Elements/PathInput.lua
-- Text field for editing a filesystem path, with an inline reset button.
-- Designed to support future watcher integration via onChange callback.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: {
--   x?, y, w
--   configKey           string   Config key to read initial value from and write on commit
--   placeholderKey      string   i18n key for the placeholder text
--   resetBtnKey         string   i18n key for the reset button label
--   resetValue?         string   value to set on reset (default "")
--   onChange?           fun(value)  called after value is committed (lost focus, Enter, reset)
--                                   caller can use this to send a watcher command
-- }
-- Returns { getValue: fun():string, setValue: fun(string) }
function ManualSave.makePathInput(parent, opts)
    local TH         = ManualSave.Theme
    local resetVal   = opts.resetValue or ""
    local resetLabel = getText(opts.resetBtnKey)
    local resetW     = ManualSave.textBtnW(resetLabel, 70)
    local inputH     = TH.BUTTON_HGT + 2
    local inputW     = opts.w - (opts.x or 0) - resetW - TH.GAP - 14

    local function commit(v)
        ManualSave.Config.set(opts.configKey, v)
        if opts.onChange then opts.onChange(v) end
    end

    local inp
    inp = ManualSave.makeTextInput(parent, {
        x=opts.x or 0, y=opts.y, w=inputW, h=inputH,
        value       = ManualSave.Config.get(opts.configKey) or "",
        placeholder = getText(opts.placeholderKey),
        onLostFocus      = function() commit(inp.getValue()) end,
        onCommandEntered = function() commit(inp.getValue()) end,
    })

    ManualSave.makeButton(parent, {
        x=(opts.x or 0) + inputW + TH.GAP, y=opts.y, w=resetW, h=inputH,
        label   = resetLabel,
        style   = "normal",
        onClick = function()
            inp.setValue(resetVal)
            commit(resetVal)
        end,
    })

    return {
        getValue = function() return inp.getValue() end,
        setValue = function(v) inp.setValue(v) end,
    }
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/PathInput.lua loaded.")
