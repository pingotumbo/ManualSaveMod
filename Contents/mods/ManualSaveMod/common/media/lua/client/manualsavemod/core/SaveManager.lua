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
    -- If the Load was triggered from the pause menu, close it RIGHT NOW. With
    -- the pause menu open the rest of the pipeline (signal poll → save() →
    -- quit) stays gated behind it and the user has to press Esc themselves to
    -- "release" the load. Closing the pause menu programmatically removes the
    -- gate so the Load proceeds immediately on click. setGameSpeed(1) wakes
    -- the world so the watcher's signal poll runs at full pace.
    if inGame then
        pcall(function()
            local ms = MainScreen.instance
            if ms and ms:isVisible() and ms.inGame then
                ms:setVisible(false)
                ms:removeFromUIManager()
            end
            setGameSpeed(1)
        end)
    end
    -- Pipeline overview:
    --   in-game  → ALWAYS quit + writePendingLoad + restart (any destination).
    --              On the post-restart MainMenu, checkReenter re-fires this
    --              same Load through the "not in-game" branch in a fresh VM.
    --              This avoids racing the watcher's SESSION_END deletion with
    --              PZ's in-VM world transition (corruption + crash).
    --   menu     → setWorld + continueLatestSaveAux directly. Fast, no restart.
    --
    -- save(true) before quit runs only for same-world reloads: it stops PZ
    -- from overwriting the just-restored backup with stale in-memory state on
    -- the way out. Different-world quits skip it (no useful state to flush).

    ManualSave.SignalBus.send(
        "LOAD",
        { GMODE=gmode, WORLD=world, SLOT=slot },
        function(status, result)
            if status == "OK" then
                LT.setSession(world, gmode, slot, result and result.SESSION_ID)

                local ok, liveWorld = pcall(function()
                    return getWorld() and getWorld():getWorld()
                end)
                if inGame then
                    -- ALWAYS restart PZ when the user triggers a Load from
                    -- in-game (not just when reloading the same world). Without
                    -- this, the in-VM transition (setWorld + continueLatestSaveAux)
                    -- races with the watcher's SESSION_END: the watcher deletes
                    -- the leaving world's vanilla folder while PZ is still
                    -- finishing IngameState.exit (animals removeFromWorld,
                    -- chunk cleanup, ...). The corruption surfaces as a
                    -- downstream NPE such as AnimalDefinitions.getDef and PZ
                    -- crashes. Quitting first guarantees PZ has zero handles
                    -- on the old folder by the time SESSION_END deletes it.
                    --
                    -- save(true) only on same-world: it preserves the just
                    -- restored backup from being overwritten by stale in-memory
                    -- state on quit. For a different world we leave the
                    -- current one alone.
                    if ok and liveWorld == slot then
                        pcall(save, true)
                    end
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
                -- Hide MainScreen before kicking the load: PZ otherwise keeps
                -- the menu drawing on the main thread and continueLatestSaveAux
                -- gets queued but never picked up until the user presses any
                -- input (the "Esc to start Load" bug).
                local ms = MainScreen.instance
                if ms and ms:isVisible() then
                    ms:setVisible(false)
                    ms:removeFromUIManager()
                end
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
