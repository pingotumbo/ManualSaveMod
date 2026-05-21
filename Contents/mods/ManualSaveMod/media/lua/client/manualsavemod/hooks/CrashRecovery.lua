-- Hooks/CrashRecovery.lua
-- Show an info dialog when the watcher has recovered one or more saves after
-- a crash / forced shutdown of the previous session.
--
-- The watcher writes ManualSave_CrashRecovery.txt (one slot name per line)
-- when its startup pass finds stale VanillaOwned entries whose vanilla folder
-- still exists on disk — that means PZ exited without going through our
-- SESSION_END (a crash, a Task Manager kill, a power-off). The watcher copies
-- each into Backups/<gmode>/<world>/<slot>_crash_<timestamp> so the user
-- doesn't lose their progress.
--
-- We read the file at the first MainMenuEnter, show a single-OK dialog
-- listing how many saves were recovered, then delete the marker file so it
-- doesn't pop up again.
---@diagnostic disable: undefined-global

-- B41 skip: the recovery popup depends on ManualSave.openInfoDialog which is
-- built on top of the new modal/focus system shipped in B42. On B41 the
-- watcher still creates _crash_<timestamp> backups, the user just doesn't see
-- the popup at the next main menu (the saves are still in the Load list).
if ManualSave and ManualSave.IS_B41 then
    print("[ManualSaveMod] Hooks/CrashRecovery.lua: skipped (B41 build).")
    return
end

ManualSave = ManualSave or {}

local CRASH_FILE  = "ManualSave_CrashRecovery.txt"
local _checked    = false

local function readLines(file)
    local r = getFileReader(file, false)
    if not r then return nil end
    local lines = {}
    while true do
        local line = r:readLine()
        if not line then break end
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then table.insert(lines, line) end
    end
    r:close()
    return lines
end

local function clearFile(file)
    local w = getFileWriter(file, true, false)
    if w then w:close() end
end

local function showRecoveryDialog(slots)
    if not slots or #slots == 0 then return end
    local count = #slots
    local title = (count == 1) and "Crash recovery"
                                or "Crash recovery (" .. count .. " saves)"
    local lines = {
        "The mod detected that the previous session ended unexpectedly",
        "(crash, force-quit, or power-off).",
        "",
    }
    if count == 1 then
        table.insert(lines, "A recovery copy has been saved as:")
    else
        table.insert(lines, count .. " recovery copies have been saved:")
    end
    -- Cap listed slot names to avoid an absurdly tall dialog.
    local shown = math.min(count, 5)
    for i = 1, shown do
        table.insert(lines, "  - " .. tostring(slots[i]))
    end
    if count > shown then
        table.insert(lines, "  ... and " .. (count - shown) .. " more")
    end
    table.insert(lines, "")
    table.insert(lines, "Open the Load Manual Save panel to find them in the list.")
    ManualSave.openInfoDialog({
        title = title,
        body  = table.concat(lines, "\n"),
        ok    = "OK",
    })
end

Events.OnMainMenuEnter.Add(function()
    if _checked then return end
    _checked = true
    local slots = readLines(CRASH_FILE)
    if not slots or #slots == 0 then return end
    clearFile(CRASH_FILE)
    -- Delay one frame so the main menu is fully on-screen before the dialog appears.
    local tick
    tick = function()
        Events.OnRenderTick.Remove(tick)
        pcall(showRecoveryDialog, slots)
    end
    Events.OnRenderTick.Add(tick)
end)

print("[ManualSaveMod] Hooks/CrashRecovery.lua loaded.")
