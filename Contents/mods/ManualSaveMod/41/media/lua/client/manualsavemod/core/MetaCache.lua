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

-- Attempts to source a clone parent from a slot name (handles "_copy",
-- "_copy_(2)", "_copy_(7)" etc.). Returns the stripped slot name, or nil if
-- the name does not look like a duplicate.
---@param slot string
---@return string?
local function parentSlotOfCopy(slot)
    if not slot then return nil end
    local stripped = slot:match("^(.*)_copy_%(%d+%)$") or slot:match("^(.*)_copy$")
    if stripped and stripped ~= "" then return stripped end
    return nil
end

-- Forward decl: read() may invoke repair() and repair() calls write().
local doRead
local doRepair

-- Reads full metadata for one slot. Returns nil if the file doesn't exist or
-- if it exists but is empty/malformed AND cannot be repaired from a parent.
---@param gmode string
---@param world string
---@param slot  string
---@return table?
function ManualSave.MetaCache.read(gmode, world, slot)
    local data, empty = doRead(gmode, world, slot)
    if data then return data end
    if not empty then return nil end
    -- File exists but produced no usable data (0 bytes or no SLOT field).
    -- The v1.6.0 Duplicate regression on Apocalypse + The Ark left a fleet
    -- of these on user disks; try to self-heal so old duplicates re-appear
    -- in the Load panel instead of being silently dropped.
    print(string.format(
        "[ManualSaveMod] MetaCache.read: empty/malformed meta for slot=%q world=%q gmode=%q -> attempting repair",
        slot, world, gmode))
    if not doRepair(gmode, world, slot) then return nil end
    data = doRead(gmode, world, slot)
    return data
end

doRead = function(gmode, world, slot)
    local r = getFileReader(metaPath(gmode, world, slot), true)
    if not r then return nil, false end
    local data = {}
    while true do
        local line = r:readLine()
        if line == nil then break end
        line = line:match("^%s*(.-)%s*$")
        local k, v = line:match("^(.-)=(.*)$")
        if k and v then data[k] = v end
    end
    r:close()
    -- "empty" covers both the literal 0-byte case and the "file has junk but
    -- no SLOT field" case: both are treated as unusable and trigger self-heal
    -- upstream.
    if not data.SLOT then return nil, true end
    return data, false
end

-- Writes a best-effort recovered meta file for `slot`. Returns true on success.
-- Strategy:
--   1) If `slot` looks like a duplicate ("..._copy", "..._copy_(N)"), copy
--      metadata from the parent slot (with DATE refreshed to "now") so the
--      duplicate inherits MAP/MODS/SEED/etc from the original.
--   2) Otherwise, write a minimal stub (identity fields + DATE=now). This
--      keeps the entry visible in the Load panel even if all detail is lost.
doRepair = function(gmode, world, slot)
    local parent = parentSlotOfCopy(slot)
    if parent then
        local parentMeta = doRead(gmode, world, parent)
        if parentMeta then
            parentMeta.SLOT = slot
            parentMeta.DATE = os.date("%d %b %Y %H:%M")
            if ManualSave.MetaCache.write(gmode, world, slot, parentMeta) then
                print(string.format(
                    "[ManualSaveMod] MetaCache.repair: rebuilt %q from parent %q",
                    slot, parent))
                return true
            end
        end
    end
    -- Last resort: minimal stub so the slot is at least visible.
    local stub = {
        DATE = os.date("%d %b %Y %H:%M"),
        TYPE = "FULL",
        MAP  = "",
        MODS = "",
    }
    if ManualSave.MetaCache.write(gmode, world, slot, stub) then
        print(string.format("[ManualSaveMod] MetaCache.repair: wrote stub for %q", slot))
        return true
    end
    return false
end

-- Writes (or overwrites) metadata for one slot.
-- Atomic-style: builds the entire file content as ONE string up-front, then
-- emits a SINGLE w:write() call. This avoids the v1.6.0 regression where a
-- mid-write crash (long MAP/MODS lines on some saves, e.g. The Ark in
-- Apocalypse) left the meta file truncated to 0 bytes: getFileWriter opens
-- the target in truncate mode, so a partial w:write sequence could exit the
-- function with the on-disk file at any size between 0 and the full payload.
-- Single-shot writes make the file either complete or untouched.
---@param gmode string
---@param world string
---@param slot  string
---@param data  table
function ManualSave.MetaCache.write(gmode, world, slot, data)
    local d     = data or {}
    local lines = {}
    local function add(k, v) lines[#lines + 1] = k .. "=" .. tostring(v or "") end
    add("DATE",    d.DATE or os.date("%d %b %Y %H:%M"))
    add("TYPE",    d.TYPE or "FULL")
    add("GMODE",   gmode)
    add("WORLD",   world)
    add("SLOT",    slot)
    add("MAP",     d.MAP or "")
    add("MODS",    d.MODS or "")
    add("MOD_IDS", d.MOD_IDS or "")
    if d.DAY        then add("DAY",        d.DAY)        end
    if d.PLAYTIME   then add("PLAYTIME",   d.PLAYTIME)   end
    if d.SEED       then add("SEED",       d.SEED)       end
    if d.SIZE       then add("SIZE",       d.SIZE)       end
    if d.SOURCE     then add("SOURCE",     d.SOURCE)     end
    if d.THUMB_FILE then add("THUMB_FILE", d.THUMB_FILE) end
    local payload = table.concat(lines, "\r\n") .. "\r\n"

    local w = getFileWriter(metaPath(gmode, world, slot), true, false)
    if not w then
        print("[ManualSaveMod] MetaCache.write: getFileWriter returned nil for " .. slot)
        return false
    end
    local ok, err = pcall(function() w:write(payload) end)
    w:close()
    if not ok then
        print(string.format(
            "[ManualSaveMod] MetaCache.write: w:write failed for slot=%q (%d bytes), err=%s",
            slot, #payload, tostring(err)))
        return false
    end
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
