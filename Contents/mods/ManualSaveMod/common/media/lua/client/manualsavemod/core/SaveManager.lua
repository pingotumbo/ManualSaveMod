-- Core/SaveManager.lua
-- High-level save/load operations.  All I/O goes through SignalBus + MetaCache.
-- Screen code calls these functions; it never touches signal files directly.
---@diagnostic disable: undefined-global

ManualSave            = ManualSave or {}
ManualSave.SaveManager = ManualSave.SaveManager or {}

local PENDING_FILE  = "ManualSave_Pending.txt"
local SESSION_FILE  = "ManualSave_Session.txt"
local SCREEN_REQ    = "ManualSave_ScreenReq.txt"
local SCREEN_DONE   = "ManualSave_ScreenDone.txt"

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function currentSaveInfo()
    local ok, info = pcall(function()
        return getSaveInfo(getWorld():getWorld())
    end)
    return ok and info or nil
end

local function writePending(slotName, gmode, saveName, reenter)
    local w = getFileWriter(PENDING_FILE, true, false)
    if not w then return end
    w:write("SLOT="     .. slotName .. "\r\n")
    w:write("GMODE="    .. gmode    .. "\r\n")
    w:write("SAVENAME=" .. saveName .. "\r\n")
    w:write("REENTER="  .. (reenter and "1" or "0") .. "\r\n")
    w:close()
end

local function writePendingLoad(slot, gmode, world)
    local w = getFileWriter(PENDING_FILE, true, false)
    if not w then return end
    w:write("SLOT="     .. slot  .. "\r\n")
    w:write("GMODE="    .. gmode .. "\r\n")
    w:write("SAVENAME=" .. world .. "\r\n")
    w:write("REENTER=1\r\n")
    w:write("PENDINGLOAD=1\r\n")
    w:close()
end

local function readAndClearPending()
    local r = getFileReader(PENDING_FILE, true)
    if not r then return nil end
    local data = {}
    while true do
        local line = r:readLine()
        if line == nil then break end
        line = line:match("^%s*(.-)%s*$")
        local k, v = line:match("^(.-)=(.+)$")
        if k and v then data[k] = v end
    end
    r:close()
    local w = getFileWriter(PENDING_FILE, true, false)
    if w then w:close() end
    if not data.SLOT then return nil end
    return { slotName=data.SLOT, gameMode=data.GMODE, saveName=data.SAVENAME, reenter=data.REENTER=="1", pendingLoad=data.PENDINGLOAD=="1" }
end

-- ── Screenshot helpers (Screenshotter.exe protocol, separate from SignalBus) ──

local function requestScreenshot(slotName)
    local w = getFileWriter(SCREEN_REQ, true, false)
    if w then w:write("SLOT=" .. slotName .. "\r\n"); w:close() end
end

local function checkScreenshotDone()
    local r = getFileReader(SCREEN_DONE, true)
    if not r then return false end
    local line = r:readLine()
    r:close()
    return line ~= nil and line:find("DONE") ~= nil
end

local function clearScreenshotDone()
    local w = getFileWriter(SCREEN_DONE, true, false)
    if w then w:close() end
end

-- ── Session tracking ─────────────────────────────────────────────────────────
-- When loading via ManualSave, PZ renames the live folder to the slot name.
-- We persist the original world/gmode to a file so they survive OnMainMenuEnter,
-- which fires on both genuine main-menu returns AND the death/new-character screen.
-- resolveWorld/resolveGmode restore from file when in-memory values are nil,
-- validating that info.saveName still matches the slot we loaded (so a native
-- load of a different world never picks up a stale session).
ManualSave.SaveManager._sessionWorld = nil
ManualSave.SaveManager._sessionGmode = nil
ManualSave.SaveManager._sessionSlot  = nil
ManualSave.SaveManager._sessionId    = nil

local function writeSession(slot, world, gmode, sid)
    local w = getFileWriter(SESSION_FILE, true, false)
    if not w then return end
    w:write("SLOT="  .. slot  .. "\r\n")
    w:write("WORLD=" .. world .. "\r\n")
    w:write("GMODE=" .. gmode .. "\r\n")
    if sid then w:write("SID=" .. sid .. "\r\n") end
    w:close()
end

local function readSession()
    local r = getFileReader(SESSION_FILE, true)
    if not r then return nil end
    local data = {}
    while true do
        local line = r:readLine()
        if line == nil then break end
        line = line:match("^%s*(.-)%s*$")
        local k, v = line:match("^(.-)=(.+)$")
        if k and v then data[k] = v end
    end
    r:close()
    if not data.SLOT then return nil end
    return { slot=data.SLOT, world=data.WORLD, gmode=data.GMODE, sessionId=data.SID }
end

local function restoreSessionIfNeeded(info)
    if ManualSave.SaveManager._sessionWorld then return end
    local s = readSession()
    if s and s.slot == info.saveName then
        ManualSave.SaveManager._sessionWorld = s.world
        ManualSave.SaveManager._sessionGmode = s.gmode
        ManualSave.SaveManager._sessionSlot  = s.slot
        ManualSave.SaveManager._sessionId    = s.sessionId
    end
end

-- True for the first OnMainMenuEnter in each Lua VM lifetime.
-- A genuine game→menu exit reloads the Lua VM (all module code re-runs → reset to true).
-- A continueLatestSaveAux load transition fires OnMainMenuEnter WITHOUT reloading the VM,
-- so the flag is already false and the cleanup block is skipped.
local _firstMenuEnter = true

Events.OnMainMenuEnter.Add(function()
    if _firstMenuEnter then
        _firstMenuEnter = false
        local s = readSession()
        if s and s.sessionId then
            ManualSave.SignalBus.send("SESSION_END",
                { GMODE=s.gmode, SLOT=s.slot, SESSION_ID=s.sessionId })
            local w = getFileWriter(SESSION_FILE, true, false)
            if w then w:close() end
        end
    end
    ManualSave.SaveManager._sessionWorld = nil
    ManualSave.SaveManager._sessionGmode = nil
    ManualSave.SaveManager._sessionSlot  = nil
    ManualSave.SaveManager._sessionId    = nil
end)

local function resolveWorld(info)
    restoreSessionIfNeeded(info)
    return ManualSave.SaveManager._sessionWorld or info.saveName
end
local function resolveGmode(info)
    restoreSessionIfNeeded(info)
    return ManualSave.SaveManager._sessionGmode or info.gameMode
end
-- Returns the actual PZ live save folder name (may differ from resolveWorld after a load).
local function resolveLiveWorld(info)
    return info.saveName
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Quick save: screenshot → write meta → send SAVE signal.
-- onDone(status) where status = "OK" | "ERROR"
---@param slotName string
---@param onDone   fun(status:string)?
function ManualSave.SaveManager.quickSave(slotName, onDone)
    local info = currentSaveInfo()
    if not info then
        if onDone then pcall(onDone, "ERROR") end
        return
    end
    local gmode     = resolveGmode(info)
    local world     = resolveWorld(info)
    local liveWorld = resolveLiveWorld(info)

    clearScreenshotDone()
    requestScreenshot(slotName)

    local frames = 0
    local handler
    handler = function()
        frames = frames + 1
        if checkScreenshotDone() or frames >= 300 then
            Events.OnRenderTick.Remove(handler)
            clearScreenshotDone()
            save(true)
            local meta = ManualSave.MetaCache.collectLiveData("QUICK")
            ManualSave.MetaCache.write(gmode, world, slotName, meta)
            local params = { GMODE=gmode, WORLD=world, SLOT=slotName }
            if liveWorld ~= world then params.LIVE_WORLD = liveWorld end
            ManualSave.SignalBus.send("SAVE", params,
                function(status) if onDone then pcall(onDone, status) end end)
        end
    end
    Events.OnRenderTick.Add(handler)
end

-- Full save: writes meta + pending file, sends SAVE signal, then quits.
-- No callback — the game process exits.
---@param slotName string
---@param reenter  boolean?  if true, re-enters the world after the .bat finishes
function ManualSave.SaveManager.fullSave(slotName, reenter)
    local info = currentSaveInfo()
    if not info then return end
    local gmode     = resolveGmode(info)
    local world     = resolveWorld(info)
    local liveWorld = resolveLiveWorld(info)

    local meta = ManualSave.MetaCache.collectLiveData("FULL")
    ManualSave.MetaCache.write(gmode, world, slotName, meta)
    writePending(slotName, gmode, world, reenter or false)

    -- Take screenshot while game is still visible, then send signal and quit
    clearScreenshotDone()
    requestScreenshot(slotName)

    local frames = 0
    local handler
    handler = function()
        frames = frames + 1
        if checkScreenshotDone() or frames >= 300 then
            Events.OnRenderTick.Remove(handler)
            clearScreenshotDone()
            local params = { GMODE=gmode, WORLD=world, SLOT=slotName }
            if liveWorld ~= world then params.LIVE_WORLD = liveWorld end
            if not reenter and ManualSave.SaveManager._sessionId then
                params.SESSION_CLOSE = "1"
                params.SESSION_ID    = ManualSave.SaveManager._sessionId
            end
            ManualSave.SignalBus.send("SAVE", params)
            local ms = MainScreen.instance
            if ms and ms:isVisible() then
                ms:setVisible(false)
                ms:removeFromUIManager()
            end
            getCore():quit()
        end
    end
    Events.OnRenderTick.Add(handler)
end

-- Checks for a pending reenter after a full save and acts on it.
-- Call this from OnMainMenuEnter.
function ManualSave.SaveManager.checkReenter()
    local p = readAndClearPending()
    if not p or not p.reenter then return end
    ManualSave.SaveManager._sessionWorld = p.saveName
    ManualSave.SaveManager._sessionGmode = p.gameMode
    if p.pendingLoad then
        -- Second Watcher copy from clean main menu: PZ is fully stopped so it
        -- cannot overwrite the restored backup this time.
        ManualSave.SaveManager.load(p.gameMode, p.saveName, p.slotName, nil)
        return
    end
    getWorld():setGameMode(p.gameMode)
    getWorld():setWorld(p.saveName)
    MainScreen.instance:setDefaultSandboxVars()
    MainScreen.continueLatestSaveAux()
end

--- Loads a slot: flushes PZ state, sends LOAD signal, then enters the world.
---
--- ### Same-world load after death
--- After dying and creating a new character, PZ holds the new character's state in
--- memory.  If we try to load a slot that lives in the same world folder, PZ ignores
--- the disk state the Watcher just restored and loads from memory instead.
---
--- Fix: call `save(true)` BEFORE signalling the Watcher so all in-memory data is
--- flushed to disk first.  When the Watcher then copies the backup over the live
--- folder, there is nothing dirty left in memory.  We then call `getCore():quit()`
--- so PZ restarts clean and reads purely from disk -- where the restored backup is.
--- `checkReenter()` on the next OnMainMenuEnter picks up the pending file and
--- re-enters the correct slot automatically.
---
--- For different-world loads (no memory conflict) we skip the quit and load directly.
---
---@param gmode  string
---@param world  string
---@param slot   string
---@param onDone fun(status:string)?
function ManualSave.SaveManager.load(gmode, world, slot, onDone)
    local inGame = MainScreen.instance and not MainScreen.instance:isVisible()
    if inGame then pcall(save, true) end   -- flush memory only when in-game

    ManualSave.SignalBus.send(
        "LOAD",
        { GMODE=gmode, WORLD=world, SLOT=slot },
        function(status, result)
            if status == "OK" then
                ManualSave.SaveManager._sessionWorld = world
                ManualSave.SaveManager._sessionGmode = gmode
                ManualSave.SaveManager._sessionSlot  = slot
                ManualSave.SaveManager._sessionId    = result and result.SESSION_ID
                writeSession(slot, world, gmode, result and result.SESSION_ID)

                local ok, liveWorld = pcall(function()
                    return getWorld() and getWorld():getWorld()
                end)
                if inGame and ok and liveWorld == slot then
                    -- Same world while in-game: PZ writes its state on quit and
                    -- overwrites the backup the Watcher just copied. We quit anyway
                    -- to get a clean PZ state; checkReenter() will call load() again
                    -- from the main menu, triggering a second Watcher copy that PZ
                    -- can no longer interfere with.
                    writePendingLoad(slot, gmode, world)
                    if onDone then pcall(onDone, status) end
                    getCore():quit()
                    return
                end

                getWorld():setGameMode(gmode)
                getWorld():setWorld(slot)
                MainScreen.instance:setDefaultSandboxVars()
                MainScreen.continueLatestSaveAux()
            end
            if onDone then pcall(onDone, status) end
        end
    )
end

-- Deletes a slot.
---@param gmode  string
---@param world  string
---@param slot   string
---@param onDone fun(status:string)?
function ManualSave.SaveManager.delete(gmode, world, slot, onDone)
    ManualSave.SignalBus.send(
        "DELETE",
        { GMODE=gmode, WORLD=world, SLOT=slot },
        function(status, _)
            if onDone then pcall(onDone, status) end
        end
    )
end

-- Renames a slot.
---@param gmode   string
---@param world   string
---@param oldSlot string
---@param newSlot string
---@param onDone  fun(status:string)?
function ManualSave.SaveManager.rename(gmode, world, oldSlot, newSlot, onDone)
    ManualSave.SignalBus.send(
        "RENAME",
        { GMODE=gmode, WORLD=world, OLD_SLOT=oldSlot, NEW_SLOT=newSlot },
        function(status, _)
            if status == "OK" then
                ManualSave.MetaCache.copy(gmode, world, oldSlot, newSlot, false)
            end
            if onDone then pcall(onDone, status) end
        end
    )
end

-- Clones a slot.
---@param gmode   string
---@param world   string
---@param oldSlot string
---@param newSlot string
---@param onDone  fun(status:string, result:table?)?
function ManualSave.SaveManager.clone(gmode, world, oldSlot, newSlot, onDone)
    ManualSave.SignalBus.send(
        "CLONE",
        { GMODE=gmode, WORLD=world, OLD_SLOT=oldSlot, NEW_SLOT=newSlot },
        function(status, result)
            if status == "OK" then
                ManualSave.MetaCache.copy(gmode, world, oldSlot, newSlot, true, result and result.DATE)
            end
            if onDone then pcall(onDone, status, result) end
        end
    )
end

-- Returns a combined list of saves with their metadata attached.
-- Each entry: MetaCache.read result merged with { gameMode, world, slot }.
---@return table[]
function ManualSave.SaveManager.listSaves()
    local index = ManualSave.MetaCache.listSaves()
    local result = {}
    for _, entry in ipairs(index) do
        local meta = ManualSave.MetaCache.read(entry.gameMode, entry.world, entry.slot) or {}
        meta.gameMode = entry.gameMode
        meta.world    = entry.world
        meta.slot     = entry.slot
        table.insert(result, meta)
    end
    return result
end

print("[ManualSaveMod] Core/SaveManager.lua loaded.")
