-- Core/SaveManager.lua
-- Coordinatore pubblico. Delega il pipeline a SavePipeline, il tracciamento
-- sessione a LoadTracker e il lock a SaveLock.
---@diagnostic disable: undefined-global

ManualSave            = ManualSave or {}
ManualSave.SaveManager = ManualSave.SaveManager or {}

-- ── Progress HUD helpers ──────────────────────────────────────────────────────
-- v1.6.1: every long-running op (LOAD, DELETE, RENAME, CLONE) now opens the
-- shared bottom HUD with a localized "<op>: <slot>" label so the user sees
-- which operation is running, not just a slot name in a vacuum.

-- Build the label that goes on the left of the HUD. opKey is the EN/IT
-- "Loading"/"Deleting"/etc. string; slotLabel is the slot the op applies to.
---@param opKey string
---@param slotLabel string?
---@return string
local function opLabel(opKey, slotLabel)
    local txt = getText(opKey)
    if slotLabel and slotLabel ~= "" then
        return txt .. ": " .. slotLabel
    end
    return txt
end

-- Opens the progress HUD or returns nil if the panel module isn't loaded yet.
---@param opKey string
---@param slotLabel string?
local function openOpProgress(opKey, slotLabel)
    if not ManualSave.openProgressPanel then return nil end
    return ManualSave.openProgressPanel({ label = opLabel(opKey, slotLabel) })
end

-- Standard "fade out the HUD after Done" closer. On success we keep the Done
-- frame on screen for ~80 render ticks (≈1.3 s @ 60 fps) so the user clearly
-- sees the operation finished before the HUD disappears; on error we close
-- immediately.
local function completeOpProgress(panel, status, after)
    if not panel then if after then pcall(after) end; return end
    if status == "OK" then
        pcall(panel.showDone)
        local t = 0
        local closeH
        closeH = function()
            t = t + 1
            if t >= 80 then
                Events.OnRenderTick.Remove(closeH)
                pcall(panel.close)
                if after then pcall(after) end
            end
        end
        Events.OnRenderTick.Add(closeH)
    else
        pcall(panel.close)
        if after then pcall(after) end
    end
end

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
    -- HUD: opens immediately so the user sees feedback during the watcher
    -- restore + (when in-game) the quit/restart round-trip. From the menu the
    -- panel is closed in the success branch below; from in-game the game is
    -- about to quit so it dies with the process either way.
    local panel = openOpProgress("UI_MSM_Progress_Loading", slot)
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
            if status ~= "OK" then
                if panel then pcall(panel.close) end
                if onDone then pcall(onDone, status) end
                return
            end
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
                -- HUD stays up until getCore():quit() tears the process down.
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
            -- Menu path: the new world will start drawing in a few frames; let
            -- the Done frame flash for the standard ~1.3s before tearing down.
            completeOpProgress(panel, "OK", nil)
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
    local panel = openOpProgress("UI_MSM_Progress_Deleting", slot)
    ManualSave.SignalBus.send("DELETE", { GMODE=gmode, WORLD=world, SLOT=slot },
        function(status, _)
            completeOpProgress(panel, status, function()
                if onDone then pcall(onDone, status) end
            end)
        end)
end

---@param gmode   string
---@param world   string
---@param oldSlot string
---@param newSlot string
---@param onDone  fun(status:string)?
function ManualSave.SaveManager.rename(gmode, world, oldSlot, newSlot, onDone)
    local panel = openOpProgress("UI_MSM_Progress_Renaming", newSlot)
    ManualSave.SignalBus.send("RENAME",
        { GMODE=gmode, WORLD=world, OLD_SLOT=oldSlot, NEW_SLOT=newSlot },
        function(status, _)
            if status == "OK" then
                ManualSave.MetaCache.copy(gmode, world, oldSlot, newSlot, false)
            end
            completeOpProgress(panel, status, function()
                if onDone then pcall(onDone, status) end
            end)
        end)
end

---@param gmode   string
---@param world   string
---@param oldSlot string
---@param newSlot string
---@param onDone  fun(status:string, result:table?)?
function ManualSave.SaveManager.clone(gmode, world, oldSlot, newSlot, onDone)
    local panel = openOpProgress("UI_MSM_Progress_Duplicating", newSlot)
    ManualSave.SignalBus.send("CLONE",
        { GMODE=gmode, WORLD=world, OLD_SLOT=oldSlot, NEW_SLOT=newSlot },
        function(status, result)
            if status == "OK" then
                ManualSave.MetaCache.copy(gmode, world, oldSlot, newSlot, true,
                    result and result.DATE)
            end
            completeOpProgress(panel, status, function()
                if onDone then pcall(onDone, status, result) end
            end)
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
