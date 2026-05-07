-- Core/MetaCache.lua
-- Reads and writes per-slot metadata files and the save index.
-- All I/O stays in the PZ user directory (getFileWriter / getFileReader).
--
-- Meta file path:  ManualSaves_Meta_<gmode>_<world>_<slot>.txt
-- Index file path: ManualSave_Index.txt   (written by .bat, read-only from Lua)
--
-- Meta file fields (all optional except the four identity fields):
--   GMODE, WORLD, SLOT, DATE, TYPE, MAP, MODS, ALIVE, DAY, PLAYTIME, SEED, SIZE
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
    w:write("MODS="  .. (d.MODS  or "")      .. "\r\n")
    w:write("ALIVE=" .. (d.ALIVE or "ALIVE") .. "\r\n")
    if d.DAY      then w:write("DAY="      .. d.DAY      .. "\r\n") end
    if d.PLAYTIME then w:write("PLAYTIME=" .. d.PLAYTIME .. "\r\n") end
    if d.SEED     then w:write("SEED="     .. d.SEED     .. "\r\n") end
    if d.SIZE     then w:write("SIZE="     .. d.SIZE     .. "\r\n") end
    if d.SOURCE   then w:write("SOURCE="   .. d.SOURCE   .. "\r\n") end
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
function ManualSave.MetaCache.copy(gmode, world, oldSlot, newSlot, freshDate, dateOverride)
    local meta = ManualSave.MetaCache.read(gmode, world, oldSlot)
    if not meta then
        print("[ManualSaveMod] MetaCache.copy: no meta for " .. oldSlot)
        return false
    end
    if freshDate then meta.DATE = dateOverride or os.date("%d %b %Y %H:%M") end
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

    pcall(function()
        local info = getSaveInfo(getWorld():getWorld())
        if info and info.mapName then d.MAP = info.mapName end
        if info and info.activeMods then
            local list = {}
            for i = 1, info.activeMods:getMods():size() do
                local id = info.activeMods:getMods():get(i - 1)
                local mi = getModInfoByID(id)
                table.insert(list, mi and mi:getName() or id)
            end
            d.MODS = table.concat(list, ", ")
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
        if p.isDead and p:isDead() then d.ALIVE = "DEAD" else d.ALIVE = "ALIVE" end
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
            local list = {}
            for i = 1, info.activeMods:getMods():size() do
                local id = info.activeMods:getMods():get(i - 1)
                local mi = getModInfoByID(id)
                table.insert(list, mi and mi:getName() or id)
            end
            if #list > 0 then meta.MODS = table.concat(list, ", "); changed = true end
        end
    end)

    -- Resolve MODS IDs to display names (works even without getSaveInfo)
    if meta.MODS and meta.MODS ~= "" then
        local ids = {}
        for id in meta.MODS:gmatch("[^,]+") do
            local s = id:match("^%s*(.-)%s*$")
            if s ~= "" then table.insert(ids, s) end
        end
        local resolved, anyImproved = {}, false
        for _, id in ipairs(ids) do
            local ok, mi = pcall(getModInfoByID, id)
            local name = (ok and mi and mi:getName()) or id
            if name ~= id then anyImproved = true end
            table.insert(resolved, name)
        end
        if anyImproved then
            meta.MODS = table.concat(resolved, ", ")
            changed = true
        end
    end

    if changed then ManualSave.MetaCache.write(gmode, world, slot, meta) end
end

print("[ManualSaveMod] Core/MetaCache.lua loaded.")
