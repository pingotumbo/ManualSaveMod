-- Core/Config.lua
-- Reads/writes ManualSave_Config.txt in %USERPROFILE%\Zomboid\Lua\.
-- All settings are KEY=VALUE strings; callers use Config.get/set.
---@diagnostic disable: undefined-global

ManualSave        = ManualSave or {}
ManualSave.Config = ManualSave.Config or {}

local FILE = "ManualSave_Config.txt"

local DEFAULTS = {
    THUMB_SOURCE      = "screenshot",   -- "screenshot" | "placeholder"
    CONFIRM_LOAD      = "1",
    CONFIRM_DELETE    = "1",
    SHOW_WATCHER_WARN = "1",
    SPINNER_STYLE     = "spiffo",
    SPINNER_SIZE_PX   = "64",
    HUD_POS_X         = "0.500",
    HUD_POS_Y         = "0.880",
    HUD_HIDDEN        = "0",
    BACKUP_DIR        = "",
    VERBOSE_LOG       = "0",
    SAVE_NAME_DEFAULT = "Save",        -- prefix pre-filled in SaveScreen
    SHORTCUT_QUICK_SAVE = "K",         -- key letter / F1..F12 / "" disables
    SHORTCUT_QUICK_LOAD = "F9",
    SHOW_PATCH_NOTES    = "1",         -- "1" show What's New popup, "0" suppressed
}

local _data = nil

local function ensureLoaded()
    if _data then return end
    _data = {}
    for k, v in pairs(DEFAULTS) do _data[k] = v end
    local r = getFileReader(FILE, true)
    if not r then return end
    while true do
        local line = r:readLine()
        if line == nil then break end
        line = line:match("^%s*(.-)%s*$") or ""
        if not line:match("^#") and line ~= "" then
            local k, v = line:match("^([%w_]+)=(.*)$")
            if k and DEFAULTS[k] ~= nil then _data[k] = v end
        end
    end
    r:close()
end

local function flush()
    if not _data then return end
    local w = getFileWriter(FILE, true, false)
    if not w then return end
    for k, v in pairs(_data) do
        w:write(k .. "=" .. tostring(v) .. "\r\n")
    end
    w:close()
end

function ManualSave.Config.get(key)
    ensureLoaded()
    local v = _data[key]
    return (v ~= nil) and v or (DEFAULTS[key] or "")
end

function ManualSave.Config.set(key, value)
    ensureLoaded()
    if DEFAULTS[key] == nil then return end
    _data[key] = tostring(value)
    flush()
end

function ManualSave.Config.reset()
    _data = {}
    for k, v in pairs(DEFAULTS) do _data[k] = v end
    flush()
end

Events.OnGameBoot.Add(function() ensureLoaded() end)

print("[ManualSaveMod] Core/Config.lua loaded.")
