-- PostLoadFlagsHook.lua
-- Reads ManualSaves_PostLoad.txt after game start and applies recovery flags.
---@diagnostic disable: undefined-global

local POST_LOAD_FILE = "ManualSaves_PostLoad.txt"

local function readAndClearPostLoad()
    local r = getFileReader(POST_LOAD_FILE, true)
    if not r then return nil end
    local flags = {}
    while true do
        local line = r:readLine()
        if line == nil then break end
        line = line:match("^%s*(.-)%s*$")
        local k, v = line:match("^(.-)=(.+)$")
        if k == "FLAGS" and v then
            for token in v:gmatch("[^,]+") do
                local name, param = token:match("^([^=]+)=(.+)$")
                if name then
                    flags[name] = param
                else
                    flags[token] = true
                end
            end
        end
    end
    r:close()
    local w = getFileWriter(POST_LOAD_FILE, true, false)
    if w then w:close() end
    for _ in pairs(flags) do return flags end
    return nil
end

local function applyHeal(player)
    local bd = player:getBodyDamage()
    pcall(function() bd:setOverallBodyHealth(100) end)
    pcall(function() bd:setInfected(false) end)
    pcall(function()
        local parts = bd:getBodyParts()
        for i = 1, parts:size() do
            local bp = parts:get(i - 1)
            if bp then bp:RestoreToFullHealth() end
        end
    end)
end

local CLEAR_FLOATS = { 3, 5, 6, 8 } -- precipitation, fog, wind, clouds
local WEATHER_OVERRIDE_HOURS = 6    -- average weather period duration in PZ
local weatherReleaseHour = nil

local function releaseWeatherOverride()
    local gt = getGameTime()
    if gt and weatherReleaseHour and gt:getWorldAgeHours() < weatherReleaseHour then return end
    Events.EveryOneMinute.Remove(releaseWeatherOverride)
    weatherReleaseHour = nil
    local cm = getClimateManager()
    if not cm then return end
    pcall(function()
        for _, idx in ipairs(CLEAR_FLOATS) do
            local f = cm:getClimateFloat(idx)
            if f then f:setEnableAdmin(false) end
        end
        cm:transmitClientChangeAdminVars()
    end)
    print("[ManualSaveMod] PostLoad: RESET_WEATHER override released, natural weather resumed")
end

local function applyResetWeather()
    local cm = getClimateManager()
    if not cm then return end
    pcall(function() cm:stopWeatherAndThunder() end)
    pcall(function()
        for _, idx in ipairs(CLEAR_FLOATS) do
            local f = cm:getClimateFloat(idx)
            if f then f:setEnableAdmin(true); f:setAdminValue(0) end
        end
        cm:transmitClientChangeAdminVars()
    end)
    local gt = getGameTime()
    weatherReleaseHour = gt and (gt:getWorldAgeHours() + WEATHER_OVERRIDE_HOURS) or nil
    Events.EveryOneMinute.Add(releaseWeatherOverride)
end

local function applyResetTime(preset)
    local hour = 6
    if     preset == "midday"   then hour = 12
    elseif preset == "dusk"     then hour = 18
    elseif preset == "midnight" then hour = 0
    end
    local gt = getGameTime()
    if gt then pcall(function() gt:setTimeOfDay(hour) end) end
end

Events.OnGameStart.Add(function()
    local flags = readAndClearPostLoad()
    if not flags then return end
    local player = getPlayer()
    if not player then return end

    if flags.HEAL_PLAYER then
        pcall(applyHeal, player)
        print("[ManualSaveMod] PostLoad: HEAL_PLAYER applied")
    end
    if flags.RESET_WEATHER then
        pcall(applyResetWeather)
        print("[ManualSaveMod] PostLoad: RESET_WEATHER applied")
    end
    if flags.RESET_TIME then
        pcall(applyResetTime, flags.RESET_TIME)
        print("[ManualSaveMod] PostLoad: RESET_TIME applied (" .. tostring(flags.RESET_TIME) .. ")")
    end
end)

print("[ManualSaveMod] Hooks/PostLoadFlagsHook.lua loaded.")
