-- Hooks/VanillaSafety.lua
-- Defensive monkey-patches around vanilla functions that crash when state is
-- partially missing. Patches global and MainScreen.* variants at boot.
--
-- B41 note: the getMissingMods null-deref bug we patch here is a B42-specific
-- code path (the MainScreen.getMissingMods we patch was introduced/rewritten
-- in B42). B41 has a different mod compatibility check and we have no
-- evidence of a similar crash there. Patching B41's MainScreen.getMissingMods
-- (if it exists at all) would be a no-op at best, risky at worst, so we skip
-- the install entirely on B41.
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

if ManualSave.IS_B41 then
    print("[ManualSaveMod] Hooks/VanillaSafety.lua: skipped (B41 build).")
    return
end

-- getMissingMods(saveInfo) crashes with
--   "attempted index: getMods of non-table: null"
-- when saveInfo.activeMods is null. PZ B42 hits this during
-- continueLatestSaveAux / checkSaveFile when latestSave.ini points at a save
-- folder that has been removed or has a malformed mods.txt. The mod's own
-- LOAD pipeline can land in this state too because it rebuilds the vanilla
-- save folder from a backup; if the backup was created before mods.txt
-- existed (very old saves) the rebuilt folder also lacks it.
--
-- The fix returns an empty "missing mods" list instead of crashing. The user
-- still sees PZ's normal "incompatible / use currently-enabled mods" dialog,
-- but the game doesn't go down with a Java stack trace.
--
-- PZ B42 exposes getMissingMods in TWO places, and we don't know in advance
-- which one continueLatestSaveAux actually resolves at the crash site:
--   - Global function `getMissingMods` (older builds, top-level in MainScreen.lua)
--   - `MainScreen.getMissingMods` (newer builds, as a method)
-- We patch both. Some unrelated paths (vanilla Load screen) call the global
-- form, others (continueLatestSaveAux) hit the table form. Patching both is
-- harmless when only one of them is real.
local function safeWrap(orig)
    return function(saveInfo)
        if not saveInfo or saveInfo.activeMods == nil then return {} end
        local ok, result = pcall(orig, saveInfo)
        if ok then return result end
        print("[ManualSaveMod] getMissingMods threw, returning empty list: " .. tostring(result))
        return {}
    end
end

-- Apply the patches at every "safe" moment: file load, OnGameBoot and
-- OnMainMenuEnter. MainScreen may not exist at file load time; the global
-- function form may not be defined until vanilla's MainScreen.lua has run.
-- Each branch installs a marker so we don't double-wrap on a second pass.
local function applyPatches()
    if type(getMissingMods) == "function" and not _G._msm_getMissingMods_patched then
        local _orig = getMissingMods
        getMissingMods = safeWrap(_orig)
        _G._msm_getMissingMods_patched = true
        print("[ManualSaveMod] Hooks/VanillaSafety.lua: global getMissingMods patched.")
    end
    if MainScreen and type(MainScreen.getMissingMods) == "function"
        and not MainScreen._msm_getMissingMods_patched then
        local _orig = MainScreen.getMissingMods
        MainScreen.getMissingMods = safeWrap(_orig)
        MainScreen._msm_getMissingMods_patched = true
        print("[ManualSaveMod] Hooks/VanillaSafety.lua: MainScreen.getMissingMods patched.")
    end
end

applyPatches()
Events.OnGameBoot.Add(applyPatches)
Events.OnMainMenuEnter.Add(applyPatches)

print("[ManualSaveMod] Hooks/VanillaSafety.lua loaded.")
