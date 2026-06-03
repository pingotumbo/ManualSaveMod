-- UI/Base/Widgets/Elements/Text.lua
-- Shared text-rendering helpers used by every screen so labels and bullet
-- lists always wrap inside their container, no matter how long a translation
-- gets. Use these helpers anywhere you draw a string that might overflow.
---@diagnostic disable: undefined-global

ManualSave      = ManualSave or {}
ManualSave.Text = ManualSave.Text or {}

-- Word-wraps `text` so each returned line is at most `maxW` pixels wide in
-- the given font. Words longer than maxW are not broken further (rendered
-- on their own line). Returns at least one entry, even for empty input,
-- so callers can compute height = #rows * lineHeight without special-casing.
---@param text string?
---@param font any              -- UIFont constant (Small / Medium / Large / Big)
---@param maxW number           -- available pixel width for the text block
---@return string[]
function ManualSave.Text.wrap(text, font, maxW)
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

-- Convenience: returns the total pixel height a wrapped block would occupy,
-- given a per-line height (lineH). Saves the caller from doing
-- `#ManualSave.Text.wrap(...) * lineH` everywhere.
---@param text string?
---@param font any
---@param maxW number
---@param lineH number
---@return number
function ManualSave.Text.wrappedHeight(text, font, maxW, lineH)
    return #ManualSave.Text.wrap(text, font, maxW) * lineH
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Text.lua loaded.")
