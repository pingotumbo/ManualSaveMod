-- Core/SignalBus.lua
-- File-I/O bridge between Lua and the .bat watcher.
-- One pending signal at a time; send() resets any previous pending state.
--
-- Signal file written by Lua  →  ManualSave_Signal.txt
--   ACTION=<verb>
--   <KEY>=<value>  (zero or more named params)
--
-- Done file written by .bat   →  ManualSave_Done.txt
--   STATUS=OK|ERROR
--   ACTION=<original verb>
--   <KEY>=<value>  (optional extra fields the bat writes back)
--
-- The done file is initialised to STATUS=PENDING before each send so that a
-- stale OK from a previous operation is never misread.
---@diagnostic disable: undefined-global

ManualSave        = ManualSave or {}
ManualSave.SignalBus = ManualSave.SignalBus or {}

local SIGNAL_FILE = "ManualSave_Signal.txt"
local DONE_FILE   = "ManualSave_Done.txt"
local HB_FILE     = "ManualSave_Heartbeat.txt"

local _pending  = nil   -- { action, onDone, timeout, tick }
local _hbTick   = 0
local _hbPrev   = "0"  -- seeded: first BAT write will differ immediately
local _hbAlive  = nil  -- nil=unknown, true=alive, false=dead

-- Seed heartbeat file with "0" so any stale value from a previous session is cleared.
-- The BAT increments from 0, so the first poll already has a conclusive comparison.
local _hw = getFileWriter(HB_FILE, true, false)
if _hw then _hw:write("0\r\n"); _hw:close() end

-- Parses the done file. Returns nil when the file is absent or still PENDING.
local function parseDone()
    local r = getFileReader(DONE_FILE, true)
    if not r then return nil end
    local data = {}
    while true do
        local line = r:readLine()
        if line == nil then break end
        line = line:match("^%s*(.-)%s*$")
        local k, v = line:match("^(.-)=(.*)$")
        if k and v then data[k] = v end
    end
    r:close()
    if not data.STATUS or data.STATUS == "PENDING" then return nil end
    return data
end

-- Single always-on poll: handles both pending-signal checks and heartbeat.
local function poll()
    -- ── Signal polling (only when a send() is waiting for a response) ──
    if _pending then
        _pending.tick = _pending.tick + 1
        local done = parseDone()
        if done then
            if done.ACTION and done.ACTION ~= _pending.action then return end
            local p = _pending
            _pending = nil
            pcall(p.onDone, done.STATUS, done)
        elseif _pending.tick >= _pending.timeout then
            local p = _pending
            _pending = nil
            pcall(p.onDone, "ERROR", { STATUS="ERROR", ERROR="timeout", ACTION=p.action })
        end
    end

    -- ── Heartbeat (every ~2 s) ──────────────────────────────────────────
    _hbTick = _hbTick + 1
    if _hbTick % 120 == 0 then
        local val
        local r = getFileReader(HB_FILE, true)
        if r then val = r:readLine(); r:close() end
        if val == nil then
            _hbAlive = false
        else
            _hbAlive = (val ~= _hbPrev)
            _hbPrev  = val
        end
        if ManualSave.UI and ManualSave.UI.evalConditions then
            ManualSave.UI.evalConditions()
        end
    end
end

Events.OnRenderTick.Add(poll)

-- Sends a signal and optionally polls for the done file.
--
-- action   string         e.g. "SAVE", "LOAD", "DELETE", "RENAME"
-- params   table?         extra key→value pairs written to the signal file
-- onDone   fun(status:string, result:table)?
--          status = "OK" | "ERROR"
--          result = parsed done-file (always contains STATUS and ACTION)
-- timeout  number?        frames before giving up (default 1800 ≈ 30 s at 60 fps)
--
---@param action string
---@param params table?
---@param onDone fun(status:string, result:table)?
---@param timeout number?
function ManualSave.SignalBus.send(action, params, onDone, timeout)
    -- While a full save is committing, only the SAVE signal itself is allowed through.
    -- Anything else (DELETE, RENAME, CLONE, …) would overwrite the SAVE in the shared
    -- signal file before the Watcher reads it, losing the backup.
    if action ~= "SAVE" and ManualSave.SaveManager and ManualSave.SaveManager._quitting then
        print("[ManualSaveMod] SignalBus: IGNORED " .. action .. " (full save in progress)")
        if onDone then pcall(onDone, "ERROR", { STATUS="ERROR", ERROR="quitting", ACTION=action }) end
        return
    end

    -- Reset done file so a stale OK is never picked up
    local dw = getFileWriter(DONE_FILE, true, false)
    if dw then dw:write("STATUS=PENDING\r\n"); dw:close() end

    -- Write signal
    local w = getFileWriter(SIGNAL_FILE, true, false)
    if not w then
        print("[ManualSaveMod] SignalBus: ERROR — could not write " .. SIGNAL_FILE)
        if onDone then pcall(onDone, "ERROR", { STATUS="ERROR", ERROR="io_error" }) end
        return
    end
    w:write("ACTION=" .. action .. "\r\n")
    if params then
        for k, v in pairs(params) do
            w:write(tostring(k) .. "=" .. tostring(v) .. "\r\n")
        end
    end
    w:close()
    print("[ManualSaveMod] SignalBus: sent " .. action)

    if not onDone then return end
    _pending = { action=action, onDone=onDone, timeout=timeout or 1800, tick=0 }
end

-- Cancels any pending poll without firing the callback.
function ManualSave.SignalBus.cancel()
    _pending = nil
end

-- Returns true if a signal has been sent and we are still waiting for done.
---@return boolean
function ManualSave.SignalBus.isPending()
    return _pending ~= nil
end

--- Returns true if the watcher BAT is alive, false if dead, nil if not yet determined.
---@return boolean?
function ManualSave.SignalBus.isBatAlive()
    return _hbAlive
end

print("[ManualSaveMod] Core/SignalBus.lua loaded.")
