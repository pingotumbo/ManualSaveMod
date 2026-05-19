-- UI/Base/InputNav/KeyRepeat.lua
-- Throttled keyboard auto-repeat for navigation keys (arrows, Tab).
-- Uses PZ's Events.OnKeyKeepPressed (fires every tick while key is held) and
-- throttles to: fire nothing for the first INITIAL_DELAY_MS, then re-fire the
-- key every INTERVAL_MS while still held. Completely isolated from the main
-- InputNav dispatch — only calls ManualSave.InputNav.handleKey(key).
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- Three-stage hold model:
--   stage 1 (0 - INITIAL_DELAY_MS):      no repeat, only the initial press fires
--   stage 2 (INITIAL_DELAY_MS - FAST_AT): repeat at INTERVAL_SLOW_MS cadence
--   stage 3 (>= FAST_AT):                repeat at INTERVAL_FAST_MS cadence
-- This gives a "click once, then accelerate" feel without a hard step into
-- fast repeat: the user has time to release before runaway speeds kick in.
local INITIAL_DELAY_MS = 200
local FAST_AT          = 1000
local INTERVAL_SLOW_MS = 100
local INTERVAL_FAST_MS = 20

-- Per-key state: when the key was first held + when we last fired it.
-- A key disappears from this table on key release.
local heldSince = {}
local lastFire  = {}

-- Robust millisecond clock: PZ returns a Java long that Kahlua cannot subtract
-- directly, so wrap through tonumber. Falls back to 0 if the API is missing.
local function nowMs()
    if not getTimestampMs then return 0 end
    local ok, t = pcall(getTimestampMs)
    if not ok then return 0 end
    return tonumber(t) or 0
end

local function isRepeatable(key)
    return key == Keyboard.KEY_UP
        or key == Keyboard.KEY_DOWN
        or key == Keyboard.KEY_LEFT
        or key == Keyboard.KEY_RIGHT
        or key == Keyboard.KEY_TAB
end

-- OnKeyStartPressed fires once when a key transitions from up to down.
-- We snapshot the press time so the throttle in OnKeyKeepPressed knows when
-- the initial delay ends.
local function onKeyStart(key)
    if not isRepeatable(key) then return end
    local t = nowMs()
    heldSince[key] = t
    lastFire[key]  = t  -- initial OnKeyPressed already fired the action
end

-- OnKeyKeepPressed fires every tick while the key is held. We re-fire the
-- navigation after the initial delay, at the SLOW interval until FAST_AT, then
-- at the FAST interval (stage 3).
local function onKeyKeep(key)
    if not isRepeatable(key) then return end
    local start = heldSince[key]
    if not start then return end
    local t = nowMs()
    local held = t - start
    if held < INITIAL_DELAY_MS then return end             -- stage 1: nothing yet
    local interval = (held >= FAST_AT) and INTERVAL_FAST_MS or INTERVAL_SLOW_MS
    if t - (lastFire[key] or 0) < interval then return end
    lastFire[key] = t
    if ManualSave.InputNav and ManualSave.InputNav.handleKey then
        ManualSave.InputNav.handleKey(key)
    end
end

local function onKeyReleased(key)
    heldSince[key] = nil
    lastFire[key]  = nil
end

-- Guard each registration: events may be missing on older PZ builds.
if Events.OnKeyStartPressed and Events.OnKeyStartPressed.Add then
    Events.OnKeyStartPressed.Add(onKeyStart)
end
if Events.OnKeyKeepPressed and Events.OnKeyKeepPressed.Add then
    Events.OnKeyKeepPressed.Add(onKeyKeep)
end
if Events.OnKeyReleased and Events.OnKeyReleased.Add then
    Events.OnKeyReleased.Add(onKeyReleased)
end

print("[ManualSaveMod] UI/Base/InputNav/KeyRepeat.lua loaded.")
