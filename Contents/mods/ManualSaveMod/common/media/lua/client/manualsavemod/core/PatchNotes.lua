-- Core/PatchNotes.lua
-- Per-release content for the "What's New" popup. Edit highlights()/fixed()
-- and the matching EN/IT keys each time a new version ships.
-- All user-facing strings go through getText() — never hardcode here.
---@diagnostic disable: undefined-global

ManualSave            = ManualSave or {}
ManualSave.PatchNotes = ManualSave.PatchNotes or {}

-- Public links (browser / Steam overlay).
ManualSave.PatchNotes.WORKSHOP_ID         = "3721602150"
ManualSave.PatchNotes.WEBSITE_URL         = "https://steamcommunity.com/sharedfiles/filedetails/?id=3721602150"
ManualSave.PatchNotes.CHANGELOG_URL       = "https://steamcommunity.com/sharedfiles/filedetails/changelog/3721602150"
ManualSave.PatchNotes.ART_DISCUSSION_URL  = "https://steamcommunity.com/workshop/filedetails/discussion/3721602150/658233614222497792/"
-- TODO: replace with the URL of the dedicated Linux/macOS feedback thread
-- once it's created on the Workshop. Until then it falls back to the
-- generic discussions list for the mod.
ManualSave.PatchNotes.LINUX_FEEDBACK_URL  = "https://steamcommunity.com/workshop/filedetails/discussions/3721602150/"

-- Hardcoded source of truth for the popup badge.
--
-- We tried reading mod.info via getModFileReader, but PZ caches the entire
-- mod package at game-boot and never serves a fresh modversion until you
-- restart the game. That made the badge keep showing the previous version
-- even after a mod.info edit, so we fell back to a hardcoded constant.
--
-- !!! REMEMBER !!! When you bump mod.info modversion for a release, bump
-- this constant too. The optional check below logs a warning to console
-- when the two are out of sync so you catch the mistake at boot.
ManualSave.PatchNotes.VERSION = "1.6.0"

---@return string
function ManualSave.PatchNotes.version()
    return ManualSave.PatchNotes.VERSION or "?"
end

-- Boot-time safety net: log a warning if mod.info and the constant above
-- have drifted apart. Purely diagnostic; the constant always wins.
Events.OnGameBoot.Add(function()
    pcall(function()
        local r = getModFileReader("ManualSaveMod", "mod.info", false)
        if not r then return end
        local infoVer
        while true do
            local line = r:readLine()
            if not line then break end
            local x = line:match("^modversion=(.-)%s*$")
            if x and x ~= "" then infoVer = x; break end
        end
        r:close()
        if infoVer and infoVer ~= ManualSave.PatchNotes.VERSION then
            print(string.format(
                "[ManualSaveMod] WARNING: PatchNotes.VERSION (%s) != mod.info modversion (%s). Bump them in lock-step before release.",
                ManualSave.PatchNotes.VERSION, infoVer))
        end
    end)
end)

-- Loads a texture, returning nil if the file is missing (so cards fall back to
-- a text-only layout until art is dropped into media/textures/patchnotes/).
local function icon(name)
    local ok, t = pcall(getTexture, "media/textures/patchnotes/" .. name)
    if ok and t then return t end
    return nil
end

-- Hero highlights — up to 4 cards. { title, desc, tex? }.
-- Drop PNGs named h1.png..h4.png into media/textures/patchnotes/ to show icons.
---@return { title:string, desc:string, tex:any }[]
function ManualSave.PatchNotes.highlights()
    return {
        { title = getText("UI_MSM_Patch_H1_T"), desc = getText("UI_MSM_Patch_H1_D"), tex = icon("h1.png") },
        { title = getText("UI_MSM_Patch_H2_T"), desc = getText("UI_MSM_Patch_H2_D"), tex = icon("h2.png") },
        { title = getText("UI_MSM_Patch_H3_T"), desc = getText("UI_MSM_Patch_H3_D"), tex = icon("h3.png") },
        { title = getText("UI_MSM_Patch_H4_T"), desc = getText("UI_MSM_Patch_H4_D"), tex = icon("h4.png") },
    }
end

-- "Fixed in this update" — flat bullet list of single-line strings.
-- Add UI_MSM_Patch_FixN keys to EN/IT (and reference them here) whenever a
-- patch ships more or fewer fix lines than the previous one.
---@return string[]
function ManualSave.PatchNotes.fixed()
    return {
        getText("UI_MSM_Patch_Fix1"),
        getText("UI_MSM_Patch_Fix2"),
        getText("UI_MSM_Patch_Fix3"),
        getText("UI_MSM_Patch_Fix4"),
        getText("UI_MSM_Patch_Fix5"),
        getText("UI_MSM_Patch_Fix6"),
    }
end

print("[ManualSaveMod] Core/PatchNotes.lua loaded.")
