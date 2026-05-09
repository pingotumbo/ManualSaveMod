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

-- Returns the minimum button pixel width to display label with standard horizontal padding.
-- label: already-translated string.  minW: optional hard floor.
function ManualSave.textBtnW(label, minW)
    local tw = getTextManager():MeasureStringX(UIFont.Small, label or "")
    return math.max(minW or 0, tw + 24)
end

print("[ManualSaveMod] UI/Base/Config/Utils.lua loaded.")
