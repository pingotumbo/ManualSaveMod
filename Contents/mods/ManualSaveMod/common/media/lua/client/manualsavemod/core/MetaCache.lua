-- Core/MetaCache.lua
-- Reads and writes per-slot metadata files and the save index.
-- All I/O stays in the PZ user directory (getFileWriter / getFileReader).
--
-- Meta file path:  ManualSaves_Meta_<gmode>_<world>_<slot>.txt
-- Index file path: ManualSave_Index.txt   (written by .bat, read-only from Lua)
--
-- Meta file fields (all optional except the four identity fields):
--   GMODE, WORLD, SLOT, DATE, TYPE, MAP, MODS, DAY, PLAYTIME, SEED, SIZE
---@diagnostic disable: undefined-global

ManualSave           = ManualSave or {}
ManualSave.MetaCache = ManualSave.MetaCache or {}

local INDEX_FILE = "ManualSave_Index.txt"

local function safe(s)
    return (s or ""):gsub('[\\/:*?"<>|!]', "_"):gsub("%s+", "_")
end

local function metaPath(gmode, world, slot)
    return "ManualSaves_Meta_" .. safe(gmode) .. "_" .. safe(world) .. "_" .. safe(slot) .. ".txt"
end

-- Returns a list of all known saves from the index file (written by the .bat).
-- Each entry: { gameMode, world, slot }
---@return table[]
function ManualSave.MetaCache.listSaves()
    local r = getFileReader(INDEX_FILE, true)
    if not r then return {} end
    local saves, seen = {}, {}
    while true do
        local line = r:readLine()
        if line == nil then break end
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            local parts = {}
            for p in line:gmatch("[^|]+") do table.insert(parts, p) end
            if #parts >= 3 then
                local key = parts[1] .. "|" .. parts[2] .. "|" .. parts[3]
                if not seen[key] then
                    seen[key] = true
                    table.insert(saves, { gameMode=parts[1], world=parts[2], slot=parts[3] })
                end
            end
        end
    end
    r:close()
    return saves
end

-- Reads full metadata for one slot. Returns nil if the file doesn't exist.
---@param gmode string
---@param world string
---@param slot  string
---@return table?
function ManualSave.MetaCache.read(gmode, world, slot)
    local r = getFileReader(metaPath(gmode, world, slot), true)
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
    if not data.SLOT then return nil end
    return data
end

-- Writes (or overwrites) metadata for one slot.
-- data fields are all optional; identity (gmode/world/slot) always written.
---@param gmode string
---@param world string
---@param slot  string
---@param data  table
function ManualSave.MetaCache.write(gmode, world, slot, data)
    local w = getFileWriter(metaPath(gmode, world, slot), true, false)
    if not w then
        print("[ManualSaveMod] MetaCache: ERROR — could not write meta for " .. slot)
        return false
    end
    local d = data or {}
    w:write("DATE="  .. (d.DATE  or os.date("%d %b %Y %H:%M")) .. "\r\n")
    w:write("TYPE="  .. (d.TYPE  or "FULL")  .. "\r\n")
    w:write("GMODE=" .. gmode                .. "\r\n")
    w:write("WORLD=" .. world                .. "\r\n")
    w:write("SLOT="  .. slot                 .. "\r\n")
    w:write("MAP="   .. (d.MAP   or "")      .. "\r\n")
    w:write("MODS="    .. (d.MODS    or "") .. "\r\n")
    w:write("MOD_IDS=" .. (d.MOD_IDS or "") .. "\r\n")
    if d.DAY      then w:write("DAY="      .. d.DAY      .. "\r\n") end
    if d.PLAYTIME then w:write("PLAYTIME=" .. d.PLAYTIME .. "\r\n") end
    if d.SEED     then w:write("SEED="     .. d.SEED     .. "\r\n") end
    if d.SIZE     then w:write("SIZE="     .. d.SIZE     .. "\r\n") end
    if d.SOURCE   then w:write("SOURCE="   .. d.SOURCE   .. "\r\n") end
    -- Rich location / weather fields collected by collectLiveData. All optional;
    -- older meta files without them still parse fine because read() just picks
    -- up whatever k=v lines are present.
    if d.REGION        then w:write("REGION="        .. d.REGION        .. "\r\n") end
    if d.COORDS        then w:write("COORDS="        .. d.COORDS        .. "\r\n") end
    if d.INDOOR        then w:write("INDOOR="        .. d.INDOOR        .. "\r\n") end
    if d.HOUR_INGAME   then w:write("HOUR_INGAME="   .. d.HOUR_INGAME   .. "\r\n") end
    if d.MINUTE_INGAME then w:write("MINUTE_INGAME=" .. d.MINUTE_INGAME .. "\r\n") end
    if d.MONTH         then w:write("MONTH="         .. d.MONTH         .. "\r\n") end
    if d.DAY_OF_MONTH  then w:write("DAY_OF_MONTH="  .. d.DAY_OF_MONTH  .. "\r\n") end
    if d.YEAR          then w:write("YEAR="          .. d.YEAR          .. "\r\n") end
    if d.TEMPERATURE   then w:write("TEMPERATURE="   .. d.TEMPERATURE   .. "\r\n") end
    if d.PRECIPITATION then w:write("PRECIPITATION=" .. d.PRECIPITATION .. "\r\n") end
    if d.FOG           then w:write("FOG="           .. d.FOG           .. "\r\n") end
    if d.CLOUDS        then w:write("CLOUDS="        .. d.CLOUDS        .. "\r\n") end
    if d.WIND          then w:write("WIND="          .. d.WIND          .. "\r\n") end
    if d.RAINING       then w:write("RAINING="       .. d.RAINING       .. "\r\n") end
    if d.SNOWING       then w:write("SNOWING="       .. d.SNOWING       .. "\r\n") end
    w:close()
    return true
end

-- Copies metadata from oldSlot to newSlot (rename / clone).
-- freshDate=true replaces the DATE field with now (use for clone).
---@param gmode     string
---@param world     string
---@param oldSlot   string
---@param newSlot   string
---@param freshDate boolean?
-- modsData: nil = keep original, or table { MODS="...", MOD_IDS="..." } to override.
function ManualSave.MetaCache.copy(gmode, world, oldSlot, newSlot, freshDate, dateOverride, modsData)
    local meta = ManualSave.MetaCache.read(gmode, world, oldSlot)
    if not meta then
        print("[ManualSaveMod] MetaCache.copy: no meta for " .. oldSlot)
        return false
    end
    if freshDate then meta.DATE = dateOverride or os.date("%d %b %Y %H:%M") end
    if modsData then
        if modsData.MODS    ~= nil then meta.MODS    = modsData.MODS    end
        if modsData.MOD_IDS ~= nil then meta.MOD_IDS = modsData.MOD_IDS end
    end
    meta.SLOT = newSlot
    return ManualSave.MetaCache.write(gmode, world, newSlot, meta)
end

-- Moves metadata to a new world name (used after RENAME_WORLD).
-- The old file is left in place as a harmless leftover.
---@param gmode    string
---@param oldWorld string
---@param newWorld string
---@param slot     string
function ManualSave.MetaCache.move(gmode, oldWorld, newWorld, slot)
    local meta = ManualSave.MetaCache.read(gmode, oldWorld, slot)
    if not meta then
        print("[ManualSaveMod] MetaCache.move: no meta for " .. slot)
        return false
    end
    meta.WORLD = newWorld
    return ManualSave.MetaCache.write(gmode, newWorld, slot, meta)
end

-- Collects live game info for the currently loaded world.
-- Returns a partial data table ready to pass to MetaCache.write.
---@return table
function ManualSave.MetaCache.collectLiveData(saveType)
    local d = { TYPE = saveType or "FULL", DATE = os.date("%d %b %Y %H:%M") }

    -- MAP name comes from getSaveInfo(world). The mod list is read directly
    -- from the live game state via getActivatedMods() — the same source
    -- EditMods uses — because info.activeMods in recent PZ builds can return
    -- an empty/unbuilt structure during the save flow, causing 0-mod metas.
    pcall(function()
        local info = getSaveInfo(getWorld():getWorld())
        if info and info.mapName then d.MAP = info.mapName end
    end)
    pcall(function()
        local active = getActivatedMods()
        if not active or active:size() == 0 then return end
        local nameList, idList = {}, {}
        for i = 0, active:size() - 1 do
            local id = active:get(i)
            if type(id) == "string" and id ~= "" then
                local mi = getModInfoByID(id)
                table.insert(nameList, mi and mi:getName() or id)
                table.insert(idList, id)
            end
        end
        if #idList > 0 then
            d.MODS    = table.concat(nameList, ", ")
            d.MOD_IDS = table.concat(idList,   ", ")
        end
    end)

    pcall(function()
        local gt = getGameTime()
        if gt then d.DAY = tostring(gt:getDay()) end
    end)

    pcall(function()
        local p = getPlayer()
        if not p then return end
        local fn = p.getHoursSurvived or p.getNumHoursSurvived
        if fn then
            local total = fn(p)
            local days  = math.floor(total / 24)
            local hrs   = math.floor(total % 24)
            d.PLAYTIME  = days > 0 and string.format("%dd %dh", days, hrs) or string.format("%dh", hrs)
        end
    end)

    pcall(function()
        if WorldGenParams and WorldGenParams.INSTANCE then
            local s = WorldGenParams.INSTANCE:getSeedString()
            if s and s ~= "" then d.SEED = s; return end
        end
        local w = getWorld and getWorld()
        if w then
            if     w.getSeed    then d.SEED = tostring(w:getSeed())
            elseif w.getMapSeed then d.SEED = tostring(w:getMapSeed()) end
        end
    end)

    -- Player position + region. Coordinates land in COORDS as comma-separated
    -- "x,y,z" so we can split them again later without parsing nested fields.
    -- REGION is the human-readable name from getCurrentRegion() when the API
    -- is present; otherwise we leave it unset (consumers fall back to MAP).
    pcall(function()
        local p = getPlayer()
        if not p then return end
        local x = tonumber(p:getX()) or 0
        local y = tonumber(p:getY()) or 0
        local z = tonumber(p:getZ()) or 0
        d.COORDS = string.format("%d,%d,%d", math.floor(x), math.floor(y), math.floor(z))
        if p.getCurrentRegion then
            local r = p:getCurrentRegion()
            if r and r ~= "" then d.REGION = tostring(r) end
        end
        if p.getSquare then
            local sq = p:getSquare()
            if sq and sq.getBuilding then
                d.INDOOR = (sq:getBuilding() ~= nil) and "1" or "0"
            end
        end
    end)

    -- In-game date and time. PZ exposes hours / minutes / day / month / year
    -- on GameTime. We store them as separate plain integers so formatting
    -- stays a UI concern (12h vs 24h, locale, ...).
    pcall(function()
        local gt = getGameTime()
        if not gt then return end
        if gt.getHour          then d.HOUR_INGAME    = tostring(gt:getHour())          end
        if gt.getMinutes       then d.MINUTE_INGAME  = tostring(gt:getMinutes())       end
        if gt.getMonth         then d.MONTH          = tostring(gt:getMonth())         end
        if gt.getDay           then d.DAY_OF_MONTH   = tostring(gt:getDay())           end
        if gt.getYear          then d.YEAR           = tostring(gt:getYear())          end
    end)

    -- Weather snapshot. PZ ClimateManager exposes a handful of "intensity"
    -- accessors plus a temperature; we read whichever are defined and let the
    -- UI later collapse them into a single label (Clear/Rain/Fog/...).
    pcall(function()
        local cm = getClimateManager()
        if not cm then return end
        if cm.getTemperature        then d.TEMPERATURE     = string.format("%.1f", cm:getTemperature())        end
        if cm.getPrecipitationIntensity then d.PRECIPITATION = string.format("%.2f", cm:getPrecipitationIntensity()) end
        if cm.getFogIntensity       then d.FOG             = string.format("%.2f", cm:getFogIntensity())       end
        if cm.getCloudIntensity     then d.CLOUDS          = string.format("%.2f", cm:getCloudIntensity())     end
        if cm.getWindIntensity      then d.WIND            = string.format("%.2f", cm:getWindIntensity())      end
        if cm.isRaining and cm:isRaining() then d.RAINING  = "1" end
        if cm.isSnowing and cm:isSnowing() then d.SNOWING  = "1" end
    end)

    return d
end

-- Tries to enrich a native-imported save meta with live PZ API data.
-- Attempts getSaveInfo(world) for MAP name; resolves mod IDs to display names.
-- No-op if meta is missing or PZ API calls fail.
---@param gmode string
---@param world string
---@param slot  string
function ManualSave.MetaCache.tryEnrichNative(gmode, world, slot)
    local meta = ManualSave.MetaCache.read(gmode, world, slot)
    if not meta then return end
    local changed = false

    -- Try to get MAP name and named mod list from PZ
    pcall(function()
        local info = getSaveInfo(world)
        if not info then return end
        if info.mapName and info.mapName ~= "" and (not meta.MAP or meta.MAP == "") then
            meta.MAP = info.mapName
            changed = true
        end
        if info.activeMods and (not meta.MODS or meta.MODS == "") then
            local nameList, idList = {}, {}
            for i = 1, info.activeMods:getMods():size() do
                local id = info.activeMods:getMods():get(i - 1)
                local mi = getModInfoByID(id)
                table.insert(nameList, mi and mi:getName() or id)
                table.insert(idList, id)
            end
            if #nameList > 0 then
                meta.MODS    = table.concat(nameList, ", ")
                meta.MOD_IDS = table.concat(idList,   ", ")
                changed = true
            end
        end
    end)

    -- Resolve MODS (raw IDs -> display names); populate MOD_IDS if not yet set.
    -- Only runs when MODS has content and MOD_IDS is missing (native imports, old saves).
    if meta.MODS and meta.MODS ~= "" and (not meta.MOD_IDS or meta.MOD_IDS == "") then
        local rawIds = {}
        for id in meta.MODS:gmatch("[^,]+") do
            local s = id:match("^%s*(.-)%s*$")
            if s ~= "" then table.insert(rawIds, s) end
        end
        local names, anyImproved = {}, false
        for _, id in ipairs(rawIds) do
            local ok, mi = pcall(getModInfoByID, id)
            local name = (ok and mi and mi:getName()) or id
            if name ~= id then anyImproved = true end
            table.insert(names, name)
        end
        if anyImproved then
            meta.MOD_IDS = table.concat(rawIds, ", ")
            meta.MODS    = table.concat(names,  ", ")
            changed = true
        end
    end

    if changed then ManualSave.MetaCache.write(gmode, world, slot, meta) end
end

ManualSave.MOD_VERSION = "?"
ManualSave.MOD_NAME    = "Manual Save & Slot Manager"

print("[ManualSaveMod] Core/MetaCache.lua loaded.")
