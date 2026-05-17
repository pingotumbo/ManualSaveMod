-- Core/SavePipeline.lua
-- Pipeline unificata di salvataggio (QUICK e FULL).
--
-- ctx = {
--   mode      "QUICK" | "FULL"
--   slot      string
--   gmode     string
--   world     string   nome sessione originale
--   liveWorld string   cartella PZ live (puo' differire dopo un load)
--   reenter   bool?    FULL only: true = Save & Return
--   onDone    fun?     QUICK only: chiamata con "OK"|"ERROR" a completamento
-- }
--
-- Step 1 [FULL] — lock + flag + pending file + unpause per screenshot
-- Step 2 [both] — screenshot async (OnRenderTick)
-- Step 3 [both] — flush + metadata + segnale + post-action
--                 QUICK: save(true) → SAVE signal → aspetta DONE → onDone
--                 FULL:  SAVE signal → quit (il Watcher copia dopo l'uscita)
---@diagnostic disable: undefined-global

ManualSave            = ManualSave or {}
ManualSave.SavePipeline = ManualSave.SavePipeline or {}

-- ── Costanti file ─────────────────────────────────────────────────────────────
local SCREEN_REQ      = "ManualSave_ScreenReq.txt"
local SCREEN_DONE     = "ManualSave_ScreenDone.txt"
local REENTER_FLAG    = "ManualSave_ReenterFlag.txt"
local FULLSAVE_PENDING = "ManualSave_FullSavePending.txt"

-- ── Helpers privati ───────────────────────────────────────────────────────────

local function currentSaveInfo()
    local ok, info = pcall(function()
        return getSaveInfo(getWorld():getWorld())
    end)
    return ok and info or nil
end

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

-- ── Pipeline ──────────────────────────────────────────────────────────────────

local function executeSave(ctx)

    -- Step 1: prepara (solo FULL) ──────────────────────────────────────────────
    if ctx.mode == "FULL" then
        ManualSave.SaveLock.lock()
        if ctx.reenter then
            local fw = getFileWriter(REENTER_FLAG, true, false)
            if fw then fw:write("1\r\n"); fw:close() end
        end
        ManualSave.LoadTracker.writePending(
            ctx.slot, ctx.gmode, ctx.world, ctx.reenter or false, ctx.liveWorld)
        pcall(function() if getPlayer() then setGameSpeed(1) end end)
    end

    -- Step 2: screenshot async ─────────────────────────────────────────────────
    clearScreenshotDone()
    requestScreenshot(ctx.slot)
    local frames = 0
    local handler
    handler = function()
        frames = frames + 1
        if not (checkScreenshotDone() or frames >= 300) then return end
        Events.OnRenderTick.Remove(handler)
        clearScreenshotDone()

        -- Step 3: flush + metadata + segnale + post-action ────────────────────
        if ctx.mode == "QUICK" then save(true) end

        local meta = ManualSave.MetaCache.collectLiveData(ctx.mode)
        ManualSave.MetaCache.write(ctx.gmode, ctx.world, ctx.slot, meta)

        local params = { GMODE=ctx.gmode, WORLD=ctx.world, SLOT=ctx.slot }
        if ctx.liveWorld ~= ctx.world then params.LIVE_WORLD = ctx.liveWorld end

        if ctx.mode == "QUICK" then
            local progressPanel = nil
            if ManualSave.openProgressPanel then
                progressPanel = ManualSave.openProgressPanel({ label = ctx.slot })
            end
            ManualSave.SignalBus.send("SAVE", params,
                function(status)
                    ManualSave.SaveLock.unlock()
                    if progressPanel then pcall(progressPanel.close) end
                    if ctx.onDone then pcall(ctx.onDone, status) end
                end)
        else
            local sid = ManualSave.LoadTracker.getSessionId()
            if not ctx.reenter and sid then
                params.SESSION_CLOSE = "1"
                params.SESSION_ID    = sid
            end
            local fw = getFileWriter(FULLSAVE_PENDING, true, false)
            if fw then fw:write("SLOT=" .. ctx.slot .. "\r\n"); fw:close() end
            ManualSave.SignalBus.send("SAVE", params)
            local ms = MainScreen.instance
            if ms and ms:isVisible() then
                ms:setVisible(false); ms:removeFromUIManager()
            end
            getCore():quit()
        end
    end
    Events.OnRenderTick.Add(handler)
end

-- ── API pubblica ──────────────────────────────────────────────────────────────

---@param slotName string
---@param onDone   fun(status:string)?
function ManualSave.SavePipeline.quickSave(slotName, onDone)
    if ManualSave.SaveLock.isLocked() then
        if onDone then pcall(onDone, "ERROR") end
        return
    end
    local info = currentSaveInfo()
    if not info then
        if onDone then pcall(onDone, "ERROR") end
        return
    end
    local LT = ManualSave.LoadTracker
    ManualSave.SaveLock.lock()
    executeSave({
        mode      = "QUICK",
        slot      = slotName,
        gmode     = LT.resolveGmode(info),
        world     = LT.resolveWorld(info),
        liveWorld = LT.resolveLiveWorld(info),
        onDone    = onDone,
    })
end

---@param slotName string
---@param reenter  boolean?
function ManualSave.SavePipeline.fullSave(slotName, reenter)
    if ManualSave.SaveLock.isLocked() then return end
    local info = currentSaveInfo()
    if not info then return end
    local LT = ManualSave.LoadTracker
    executeSave({
        mode      = "FULL",
        slot      = slotName,
        gmode     = LT.resolveGmode(info),
        world     = LT.resolveWorld(info),
        liveWorld = LT.resolveLiveWorld(info),
        reenter   = reenter or false,
    })
end

print("[ManualSaveMod] Core/SavePipeline.lua loaded.")
