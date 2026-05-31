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

-- Resolves the running mod version from mod.info (same source as HelpScreen).
---@return string
function ManualSave.PatchNotes.version()
    if ManualSave.MOD_VERSION and ManualSave.MOD_VERSION ~= "?" then
        return ManualSave.MOD_VERSION
    end
    pcall(function()
        local r = getModFileReader("ManualSaveMod", "mod.info", false)
        if not r then return end
        while true do
            local line = r:readLine()
            if not line then break end
            local v = line:match("^modversion=(.-)%s*$")
            if v and v ~= "" then ManualSave.MOD_VERSION = v; break end
        end
        r:close()
    end)
    return ManualSave.MOD_VERSION or "?"
end

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
---@return string[]
function ManualSave.PatchNotes.fixed()
    return {
        getText("UI_MSM_Patch_Fix1"),
        getText("UI_MSM_Patch_Fix2"),
        getText("UI_MSM_Patch_Fix3"),
    }
end

print("[ManualSaveMod] Core/PatchNotes.lua loaded.")
