-- Core/SaveManager.lua
-- Coordinatore pubblico. Delega il pipeline a SavePipeline, il tracciamento
-- sessione a LoadTracker e il lock a SaveLock.
---@diagnostic disable: undefined-global

ManualSave            = ManualSave or {}
ManualSave.SaveManager = ManualSave.SaveManager or {}

-- ── Public: save ──────────────────────────────────────────────────────────────

---@param slotName string
---@param onDone   fun(status:string)?
function ManualSave.SaveManager.quickSave(slotName, onDone)
    ManualSave.SavePipeline.quickSave(slotName, onDone)
end

---@param slotName string
---@param reenter  boolean?
function ManualSave.SaveManager.fullSave(slotName, reenter)
    ManualSave.SavePipeline.fullSave(slotName, reenter)
end

function ManualSave.SaveManager.checkReenter()
    ManualSave.LoadTracker.checkReenter()
end

-- ── Public: load ──────────────────────────────────────────────────────────────

---@param gmode  string
---@param world  string
---@param slot   string
---@param onDone fun(status:string)?
function ManualSave.SaveManager.load(gmode, world, slot, onDone)
    local LT = ManualSave.LoadTracker
    -- "in game" means there's a live player object — i.e. a world is currently
    -- loaded. Do NOT use MainScreen.instance:isVisible() here: as soon as we
    -- added the sub-screen pattern, MainScreen stays visible behind the pause
    -- menu (and is hidden during the death screen), so isVisible() gives the
    -- wrong answer in both cases. Result of using isVisible(): the in-game
    -- branch (quit + writePendingLoad + restart) didn't fire when expected,
    -- and the user saw the load animation/sound but the game never actually
    -- reloaded until they pressed Esc. getPlayer() is the canonical "is a
    -- world loaded?" check and survives any UI refactor.
    local inGame = getPlayer() ~= nil
    if inGame then pcall(save, true) end

    ManualSave.SignalBus.send(
        "LOAD",
        { GMODE=gmode, WORLD=world, SLOT=slot },
        function(status, result)
            if status == "OK" then
                LT.setSession(world, gmode, slot, result and result.SESSION_ID)

                local ok, liveWorld = pcall(function()
                    return getWorld() and getWorld():getWorld()
                end)
                if inGame and ok and liveWorld == slot then
                    LT.clearSessionFile()
                    LT.writePendingLoad(slot, gmode, world)
                    if onDone then pcall(onDone, status) end
                    getCore():quit()
                    return
                end

                LT.writePendingSession(slot, world, gmode, result and result.SESSION_ID)
                getWorld():setGameMode(gmode)
                getWorld():setWorld(slot)
                MainScreen.instance:setDefaultSandboxVars()
                MainScreen.continueLatestSaveAux()
            end
            if onDone then pcall(onDone, status) end
        end
    )
end

-- ── Public: altre operazioni ──────────────────────────────────────────────────

---@param gmode  string
---@param world  string
---@param slot   string
---@param onDone fun(status:string)?
function ManualSave.SaveManager.delete(gmode, world, slot, onDone)
    ManualSave.SignalBus.send("DELETE", { GMODE=gmode, WORLD=world, SLOT=slot },
        function(status, _) if onDone then pcall(onDone, status) end end)
end

---@param gmode   string
---@param world   string
---@param oldSlot string
---@param newSlot string
---@param onDone  fun(status:string)?
function ManualSave.SaveManager.rename(gmode, world, oldSlot, newSlot, onDone)
    ManualSave.SignalBus.send("RENAME",
        { GMODE=gmode, WORLD=world, OLD_SLOT=oldSlot, NEW_SLOT=newSlot },
        function(status, _)
            if status == "OK" then
                ManualSave.MetaCache.copy(gmode, world, oldSlot, newSlot, false)
            end
            if onDone then pcall(onDone, status) end
        end)
end

---@param gmode   string
---@param world   string
---@param oldSlot string
---@param newSlot string
---@param onDone  fun(status:string, result:table?)?
function ManualSave.SaveManager.clone(gmode, world, oldSlot, newSlot, onDone)
    local progressPanel = ManualSave.openProgressPanel and
        ManualSave.openProgressPanel({ label = newSlot }) or nil

    ManualSave.SignalBus.send("CLONE",
        { GMODE=gmode, WORLD=world, OLD_SLOT=oldSlot, NEW_SLOT=newSlot },
        function(status, result)
            if status == "OK" then
                ManualSave.MetaCache.copy(gmode, world, oldSlot, newSlot, true,
                    result and result.DATE)
            end
            if progressPanel then
                if status == "OK" then
                    pcall(progressPanel.showDone)
                    local t = 0
                    local closeH
                    closeH = function()
                        t = t + 1
                        if t >= 80 then
                            Events.OnRenderTick.Remove(closeH)
                            pcall(progressPanel.close)
                            if onDone then pcall(onDone, status, result) end
                        end
                    end
                    Events.OnRenderTick.Add(closeH)
                else
                    pcall(progressPanel.close)
                    if onDone then pcall(onDone, status, result) end
                end
            else
                if onDone then pcall(onDone, status, result) end
            end
        end)
end

---@return table[]
function ManualSave.SaveManager.listSaves()
    local index = ManualSave.MetaCache.listSaves()
    print(string.format("[MSM-LIST] listSaves: index has %d entries", #index))
    local result = {}
    for _, entry in ipairs(index) do
        local meta = ManualSave.MetaCache.read(entry.gameMode, entry.world, entry.slot) or {}
        meta.gameMode = entry.gameMode
        meta.world    = entry.world
        meta.slot     = entry.slot
        print(string.format("[MSM-LIST]   gmode=%s world=%s slot=%s",
            tostring(entry.gameMode), tostring(entry.world), tostring(entry.slot)))
        table.insert(result, meta)
    end
    return result
end

print("[ManualSaveMod] Core/SaveManager.lua loaded.")
