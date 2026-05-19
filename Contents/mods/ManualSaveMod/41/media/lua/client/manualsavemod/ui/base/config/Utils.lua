-- UI/Base/Utils.lua
-- Shared string utilities used across multiple screens.
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

-- Converts a user-entered name to a filesystem-safe slot name.
---@param name string
---@return string
function ManualSave.sanitize(name)
    return (name:gsub('%s+', '_'):gsub('[\\/:*?"<>|]', "_"):match("^%s*(.-)%s*$"))
end

-- Strips the [QUICK_SAVE] suffix from a slot name for display.
---@param slot string
---@return string
function ManualSave.slotDisplay(slot)
    return slot:gsub("%[QUICK_SAVE%]", ""):match("^%s*(.-)%s*$")
end

-- Returns the next available "copy" name for a slot, given the current saves list.
---@param baseSlot string
---@param saves table
---@return string
function ManualSave.nextCopyName(baseSlot, saves)
    local base  = ManualSave.slotDisplay(baseSlot) .. "_copy"
    local taken = {}
    for _, s in ipairs(saves) do taken[s.slot] = true end
    if not taken[base] then return base end
    local n = 2
    repeat
        local c = base .. "_(" .. n .. ")"
        if not taken[c] then return c end
        n = n + 1
    until n > 99
    return base
end

-- Returns the first available name in the sequence:
--   base, base (1), base (2), ...
-- Used when pre-filling the SaveScreen name field with a sensible default the
-- user can either accept or overwrite. Pattern matches the "Save / Save (1)"
-- convention common in many save dialogs (and distinct from nextCopyName
-- which uses _copy / _copy_(N) for duplicate operations).
---@param base string
---@param saves table
---@return string
function ManualSave.nextAvailableName(base, saves)
    if not base or base == "" then base = "Save" end
    local taken = {}
    for _, s in ipairs(saves) do taken[s.slot] = true end
    if not taken[base] then return base end
    local n = 1
    repeat
        local c = base .. " (" .. n .. ")"
        if not taken[c] then return c end
        n = n + 1
    until n > 999
    return base
end

-- Safe wrapper around getText. Returns the raw key string (never nil) if the
-- key is missing from the current language, and logs a warning so missing
-- translations are visible in console.txt.
-- Usage: replace getText("KEY") with ManualSave.t("KEY") in new screens.
---@param key string
---@return string
function ManualSave.t(key, ...)
    local ok, v = pcall(getText, key, ...)
    if not ok or v == nil then
        print("[ManualSaveMod] getText error for key: " .. tostring(key))
        return key
    end
    if v == key then
        print("[ManualSaveMod] Missing translation: " .. key)
    end
    return v
end

-- Returns the minimum button pixel width to display label with standard horizontal padding.
-- label: already-translated string.  minW: optional hard floor.
function ManualSave.textBtnW(label, minW)
    local tw = getTextManager():MeasureStringX(UIFont.Small, label or "")
    return math.max(minW or 0, tw + 24)
end

print("[ManualSaveMod] UI/Base/Config/Utils.lua loaded.")
