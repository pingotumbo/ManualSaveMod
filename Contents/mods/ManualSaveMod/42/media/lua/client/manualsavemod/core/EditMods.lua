-- Core/EditMods.lua
-- Mod list building for EditModsScreen: installed mod enumeration, save reconciliation.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave          = ManualSave or {}
ManualSave.EditMods = ManualSave.EditMods or {}

local function firstAlpha(str)
    for i = 1, #str do
        local c = str:sub(i, i)
        if c:match("[%a]") then return c:upper() end
    end
    return "?"
end

-- Sort key: strips leading [tag] groups so "[B42] Home Inventory" sorts as "home inventory".
function ManualSave.EditMods.sortKey(name)
    local s = name:lower()
    local prev
    repeat
        prev = s
        s = s:match("^%s*%[.-%]%s*(.*)") or s
    until s == prev
    return s ~= "" and s or name:lower()
end

-- Builds the unified mod list and tag list for a save record.
-- Mutates save.MOD_IDS when auto-migrating from old display-name format.
-- Returns { allMods, allTags }
-- allMods entry: { id, name, letter, icon, tags, installed, inSave, checked, status, note }
function ManualSave.EditMods.buildModList(save)
    local installedData   = {}
    local displayToRealId = {}

    local function addModById(id)
        local info = getModInfoByID(id)
        local name = info and info:getName() or id
        local icon = nil
        local tags = {}
        if info then
            local iconKey = info:getIcon()
            if iconKey and iconKey ~= "" then icon = getTexture(iconKey) end
            pcall(function()
                local reader = getModFileReader(id, "mod.info", false)
                if reader then
                    while true do
                        local line = reader:readLine()
                        if line == nil then break end
                        local tagStr = line:match("^tags=(.*)$")
                        if tagStr then
                            for tag in (tagStr .. ","):gmatch("([^,]+),") do
                                local t = tag:match("^%s*(.-)%s*$")
                                if t ~= "" and not t:match("^Build %d") then
                                    table.insert(tags, t)
                                end
                            end
                            break
                        end
                    end
                    reader:close()
                end
            end)
        end
        installedData[id]     = { name = name, icon = icon, tags = tags }
        displayToRealId[name] = id
    end

    -- Try getMods() first (all installed mods, active or not).
    -- Fall back to getActivatedMods() if getMods is unavailable or returns nothing.
    local usedGetMods = false
    if type(getMods) == "function" then
        pcall(function()
            local mods = getMods()
            if mods and mods:size() > 0 then
                usedGetMods = true
                for i = 0, mods:size() - 1 do
                    local id = mods:get(i)
                    if type(id) == "string" and id ~= "" then addModById(id) end
                end
            end
        end)
    end
    if not usedGetMods then
        pcall(function()
            local active = getActivatedMods()
            for i = 0, active:size() - 1 do
                local id = active:get(i)
                if type(id) == "string" and id ~= "" then addModById(id) end
            end
        end)
    end

    local saveModIds = {}
    local saveIdSet  = {}
    local hasMOD_IDS = save.MOD_IDS and save.MOD_IDS ~= ""
    local idSource   = hasMOD_IDS and save.MOD_IDS
                    or (save.MODS and save.MODS ~= "") and save.MODS
                    or ""
    for raw in (idSource .. ","):gmatch("([^,]+),") do
        local token = raw:match("^%s*(.-)%s*$")
        if token ~= "" then
            local id = hasMOD_IDS and token or (displayToRealId[token] or token)
            if not saveIdSet[id] then
                table.insert(saveModIds, id)
                saveIdSet[id] = true
            end
        end
    end

    -- Auto-migrate: persist resolved MOD_IDS when save only has display names.
    local hasInstalled = false
    for _ in pairs(installedData) do hasInstalled = true; break end
    if not hasMOD_IDS and hasInstalled and #saveModIds > 0 then
        local resolvedStr = table.concat(saveModIds, ", ")
        local gmode = save.GMODE or save.gameMode
        local world = save.WORLD or save.world
        local slot  = save.slot
        pcall(function()
            local meta = ManualSave.MetaCache.read(gmode, world, slot)
            if meta and (not meta.MOD_IDS or meta.MOD_IDS == "") then
                meta.MOD_IDS = resolvedStr
                ManualSave.MetaCache.write(gmode, world, slot, meta)
            end
        end)
        save.MOD_IDS = resolvedStr
    end

    local allMods = {}
    local seenIds = {}

    for id, dat in pairs(installedData) do
        local inSave = saveIdSet[id] == true
        seenIds[id]  = true
        table.insert(allMods, {
            id        = id,
            name      = dat.name,
            letter    = firstAlpha(dat.name),
            icon      = dat.icon,
            tags      = dat.tags,
            installed = true,
            inSave    = inSave,
            checked   = inSave,
            status    = "ok",
            note      = "",
        })
    end

    for _, id in ipairs(saveModIds) do
        if not seenIds[id] then
            table.insert(allMods, {
                id        = id,
                name      = id,
                letter    = firstAlpha(id),
                icon      = nil,
                tags      = {},
                installed = false,
                inSave    = true,
                checked   = true,
                status    = "missing",
                note      = getText("UI_MSM_EditMods_NotInstalled"),
            })
        end
    end

    local allTags = {}
    local tagSet  = {}
    for _, m in ipairs(allMods) do
        for _, t in ipairs(m.tags or {}) do
            if not tagSet[t] then tagSet[t] = true; table.insert(allTags, t) end
        end
    end
    table.sort(allTags)

    return { allMods = allMods, allTags = allTags }
end

print("[ManualSaveMod] Core/EditMods.lua loaded.")
