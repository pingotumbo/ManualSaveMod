-- core/Platform.lua
-- Detect the host OS by reading ManualSave_OS.txt, written by the Watcher
-- at boot ("windows" from the .ps1, "linux" / "darwin" from the .py port).
-- Used by the Settings UI to gate features that are Windows-only for now
-- (screenshot capture in particular).
---@diagnostic disable: undefined-global, inject-field

ManualSave          = ManualSave or {}
ManualSave.Platform = ManualSave.Platform or {}

local cached = nil

local function readOSFile()
    local r = getFileReader("ManualSave_OS.txt", false)
    if not r then return nil end
    local s = r:readLine() or ""
    r:close()
    s = s:gsub("[\r\n%s]+", "")
    if s == "" then return nil end
    return s:lower()
end

function ManualSave.Platform.get()
    if cached == nil then
        cached = readOSFile() or "unknown"
    end
    return cached
end

function ManualSave.Platform.isWindows()
    return ManualSave.Platform.get() == "windows"
end

-- Force a re-read on next get(). Useful when a screen reopens after the
-- Watcher has had time to write the OS marker for the first time.
function ManualSave.Platform.refresh()
    cached = nil
    return ManualSave.Platform.get()
end

print("[ManualSaveMod] Core/Platform.lua loaded.")
