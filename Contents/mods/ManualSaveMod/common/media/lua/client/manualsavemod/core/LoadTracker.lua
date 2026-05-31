-- Core/LoadTracker.lua
-- Session and load tracking: persists which slot is loaded, handles the
-- pending/reenter flow across PZ restarts and Lua VM reloads.
---@diagnostic disable: undefined-global

ManualSave             = ManualSave or {}
ManualSave.LoadTracker = ManualSave.LoadTracker or {}

-- ── File constants ─────────────────────────────────────────────────────────────
local PENDING_FILE         = "ManualSave_Pending.txt"
local SESSION_FILE         = "ManualSave_Session.txt"
local PENDING_SESSION_FILE = "ManualSave_PendingSession.txt"
local REENTER_FLAG         = "ManualSave_ReenterFlag.txt"

-- ── In-memory session state ────────────────────────────────────────────────────
local _session = { world=nil, gmode=nil, slot=nil, sessionId=nil }
local _firstMenuEnter = true

-- ── File I/O helpers (private) ─────────────────────────────────────────────────

local function readKV(filename)
    local r = getFileReader(filename, true)
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
    return data
end

local function clearFile(filename)
    local w = getFileWriter(filename, true, false)
    if w then w:close() end
end

local function readAndClearPending()
    local data = readKV(PENDING_FILE)
    clearFile(PENDING_FILE)
    if not data or not data.SLOT then return nil end
    return {
        slotName    = data.SLOT,
        gameMode    = data.GMODE,
        saveName    = data.SAVENAME,
        liveWorld   = data.LIVEWORLD,
        reenter     = data.REENTER == "1",
        pendingLoad = data.PENDINGLOAD == "1",
    }
end

local function readAndClearPendingSession()
    local data = readKV(PENDING_SESSION_FILE)
    clearFile(PENDING_SESSION_FILE)
    if not data or not data.SLOT then return nil end
    return { slot=data.SLOT, world=data.WORLD, gmode=data.GMODE, sessionId=data.SID }
end

local function restoreSessionIfNeeded(info)
    if _session.world then return end
    local data = readKV(SESSION_FILE)
    if data and data.SLOT and data.SLOT == info.saveName then
        _session.world     = data.WORLD
        _session.gmode     = data.GMODE
        _session.slot      = data.SLOT
        _session.sessionId = data.SID
    end
end

-- ── Public: session state ──────────────────────────────────────────────────────

function ManualSave.LoadTracker.getSession()
    if not _session.world then return nil end
    return { world=_session.world, gmode=_session.gmode,
             slot=_session.slot,   sessionId=_session.sessionId }
end

function ManualSave.LoadTracker.setSession(world, gmode, slot, sessionId)
    _session.world     = world
    _session.gmode     = gmode
    _session.slot      = slot
    _session.sessionId = sessionId
end

function ManualSave.LoadTracker.clearSession()
    _session.world     = nil
    _session.gmode     = nil
    _session.slot      = nil
    _session.sessionId = nil
end

function ManualSave.LoadTracker.getSessionId()
    return _session.sessionId
end

-- ── Public: world/gmode resolution ────────────────────────────────────────────

function ManualSave.LoadTracker.resolveWorld(info)
    restoreSessionIfNeeded(info)
    return _session.world or info.saveName
end

function ManualSave.LoadTracker.resolveGmode(info)
    restoreSessionIfNeeded(info)
    return _session.gmode or info.gameMode
end

function ManualSave.LoadTracker.resolveLiveWorld(info)
    return info.saveName
end

-- ── Public: file writers ───────────────────────────────────────────────────────

function ManualSave.LoadTracker.writePending(slotName, gmode, saveName, reenter, liveWorld)
    local w = getFileWriter(PENDING_FILE, true, false)
    if not w then return end
    w:write("SLOT="     .. slotName .. "\r\n")
    w:write("GMODE="    .. gmode    .. "\r\n")
    w:write("SAVENAME=" .. saveName .. "\r\n")
    w:write("REENTER="  .. (reenter and "1" or "0") .. "\r\n")
    if liveWorld and liveWorld ~= saveName then
        w:write("LIVEWORLD=" .. liveWorld .. "\r\n")
    end
    w:close()
end

function ManualSave.LoadTracker.writePendingLoad(slot, gmode, world)
    local w = getFileWriter(PENDING_FILE, true, false)
    if not w then return end
    w:write("SLOT="     .. slot  .. "\r\n")
    w:write("GMODE="    .. gmode .. "\r\n")
    w:write("SAVENAME=" .. world .. "\r\n")
    w:write("REENTER=1\r\n")
    w:write("PENDINGLOAD=1\r\n")
    w:close()
end

function ManualSave.LoadTracker.writePendingSession(slot, world, gmode, sid)
    local w = getFileWriter(PENDING_SESSION_FILE, true, false)
    if not w then return end
    w:write("SLOT="  .. slot  .. "\r\n")
    w:write("WORLD=" .. world .. "\r\n")
    w:write("GMODE=" .. gmode .. "\r\n")
    if sid then w:write("SID=" .. sid .. "\r\n") end
    w:close()
end

function ManualSave.LoadTracker.writeSession(slot, world, gmode, sid)
    local w = getFileWriter(SESSION_FILE, true, false)
    if not w then return end
    w:write("SLOT="  .. slot  .. "\r\n")
    w:write("WORLD=" .. world .. "\r\n")
    w:write("GMODE=" .. gmode .. "\r\n")
    if sid then w:write("SID=" .. sid .. "\r\n") end
    w:close()
end

function ManualSave.LoadTracker.readSession()
    local data = readKV(SESSION_FILE)
    if not data or not data.SLOT then return nil end
    return { slot=data.SLOT, world=data.WORLD, gmode=data.GMODE, sessionId=data.SID }
end

function ManualSave.LoadTracker.clearSessionFile()
    clearFile(SESSION_FILE)
end

-- ── Public: reenter ────────────────────────────────────────────────────────────

function ManualSave.LoadTracker.checkReenter()
    local p = readAndClearPending()
    if not p or not p.reenter then return end
    _session.world = p.saveName
    _session.gmode = p.gameMode
    local s = ManualSave.LoadTracker.readSession()
    if s then _session.sessionId = s.sessionId end
    if p.pendingLoad then
        ManualSave.SaveManager.load(p.gameMode, p.saveName, p.slotName, nil)
        return
    end
    getWorld():setGameMode(p.gameMode)
    getWorld():setWorld(p.liveWorld or p.saveName)
    MainScreen.instance:setDefaultSandboxVars()
    -- Hide MainScreen before kicking the load (see SaveManager.load comment):
    -- without this the menu keeps the main thread and the load only starts
    -- after the user presses a key (the "Esc to start Load" bug).
    local ms = MainScreen.instance
    if ms and ms:isVisible() then
        ms:setVisible(false)
        ms:removeFromUIManager()
    end
    MainScreen.continueLatestSaveAux()
end

-- ── Events ─────────────────────────────────────────────────────────────────────

local FULLSAVE_PENDING = "ManualSave_FullSavePending.txt"
local DONE_FILE        = "ManualSave_Done.txt"

Events.OnMainMenuEnter.Add(function()
    if _firstMenuEnter then
        _firstMenuEnter = false
        local rfr = getFileReader(REENTER_FLAG, true)
        local reenterPending = false
        if rfr then reenterPending = rfr:readLine() ~= nil; rfr:close() end
        if not reenterPending then
            local s = ManualSave.LoadTracker.readSession()
            if s and s.sessionId then
                ManualSave.SignalBus.send("SESSION_END",
                    { GMODE=s.gmode, SLOT=s.slot, SESSION_ID=s.sessionId })
                clearFile(SESSION_FILE)
            end
        end
    end
    ManualSave.LoadTracker.clearSession()

    -- Progress panel for full save: written before getCore():quit(), read here after Lua reload
    local pfData = readKV(FULLSAVE_PENDING)
    if pfData and pfData.SLOT then
        clearFile(FULLSAVE_PENDING)
        if ManualSave.openProgressPanel then
            local panel = ManualSave.openProgressPanel({ label = pfData.SLOT })
            local doneHandler
            doneHandler = function()
                local d = readKV(DONE_FILE)
                if d and d.STATUS and d.STATUS ~= "PENDING" then
                    Events.OnRenderTick.Remove(doneHandler)
                    pcall(panel.close)
                end
            end
            Events.OnRenderTick.Add(doneHandler)
        end
    end
end)

Events.OnGameStart.Add(function()
    clearFile(REENTER_FLAG)
    local ps = readAndClearPendingSession()
    if ps then
        ManualSave.LoadTracker.writeSession(ps.slot, ps.world, ps.gmode, ps.sessionId)
        _session.sessionId = ps.sessionId
        -- "Esc to start Load" bug: PZ re-shows the pause menu and keeps
        -- gameSpeed at 0 after a mod-driven load, so the user has to dismiss
        -- it (Esc) before the world becomes visible/interactive. Force the
        -- pause menu closed and resume time so the world is immediately
        -- alive. Only runs when ps is set, i.e. the load came from our
        -- pipeline; vanilla Continue is untouched.
        pcall(function()
            local ms = MainScreen.instance
            if ms and ms:isVisible() then
                ms:setVisible(false)
                ms:removeFromUIManager()
            end
        end)
        pcall(function() setGameSpeed(1) end)
        pcall(function() setShowPausedMessage(false) end)
    end
end)

print("[ManualSaveMod] Core/LoadTracker.lua loaded.")
