-- Core/SaveManager.lua
-- High-level save/load operations.  All I/O goes through SignalBus + MetaCache.
-- Screen code calls these functions; it never touches signal files directly.
---@diagnostic disable: undefined-global

ManualSave            = ManualSave or {}
ManualSave.SaveManager = ManualSave.SaveManager or {}

local PENDING_FILE  = "ManualSave_Pending.txt"
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
    return { slotName=data.SLOT, gameMode=data.GMODE, saveName=data.SAVENAME, reenter=data.REENTER=="1" }
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
-- When loading via ManualSave, PZ world name is set to the slot name.
-- We store the original world/gmode here so saves use the correct paths.
ManualSave.SaveManager._sessionWorld = nil
ManualSave.SaveManager._sessionGmode = nil

Events.OnMainMenuEnter.Add(function()
    ManualSave.SaveManager._sessionWorld = nil
    ManualSave.SaveManager._sessionGmode = nil
end)

local function resolveWorld(info)
    return ManualSave.SaveManager._sessionWorld or info.saveName
end
local function resolveGmode(info)
    return ManualSave.SaveManager._sessionGmode or info.gameMode
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
    local gmode = resolveGmode(info)
    local world = resolveWorld(info)

    clearScreenshotDone()
    requestScreenshot(slotName)

    local frames = 0
    local handler
    handler = function()
        frames = frames + 1
        if checkScreenshotDone() or frames >= 300 then
            Events.OnRenderTick.Remove(handler)
            clearScreenshotDone()
            local meta = ManualSave.MetaCache.collectLiveData("QUICK")
            ManualSave.MetaCache.write(gmode, world, slotName, meta)
            ManualSave.SignalBus.send("SAVE",
                { GMODE=gmode, WORLD=world, SLOT=slotName },
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
    local gmode = resolveGmode(info)
    local world = resolveWorld(info)

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
            ManualSave.SignalBus.send("SAVE", { GMODE=gmode, WORLD=world, SLOT=slotName })
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
    if p and p.reenter then
        getWorld():setGameMode(p.gameMode)
        getWorld():setWorld(p.saveName)
        MainScreen.instance:setDefaultSandboxVars()
        MainScreen.continueLatestSaveAux()
    end
end

-- Loads a slot: sends LOAD signal, polls for done, then starts the game.
---@param gmode  string
---@param world  string
---@param slot   string
---@param onDone fun(status:string)?
function ManualSave.SaveManager.load(gmode, world, slot, onDone)
    ManualSave.SignalBus.send(
        "LOAD",
        { GMODE=gmode, WORLD=world, SLOT=slot },
        function(status, _)
            if status == "OK" then
                ManualSave.SaveManager._sessionWorld = world
                ManualSave.SaveManager._sessionGmode = gmode
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
