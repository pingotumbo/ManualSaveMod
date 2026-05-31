-- Core/PatchNotes.lua
-- Per-release content for the "What's New" popup. Edit highlights()/fixed()
-- and the matching EN/IT keys each time a new version ships.
-- All user-facing strings go through getText() — never hardcode here.
---@diagnostic disable: undefined-global

ManualSave            = ManualSave or {}
ManualSave.PatchNotes = ManualSave.PatchNotes or {}

-- Public links (browser / Steam overlay).
ManualSave.PatchNotes.WORKSHOP_ID   = "3721602150"
ManualSave.PatchNotes.WEBSITE_URL   = "https://steamcommunity.com/sharedfiles/filedetails/?id=3721602150"
ManualSave.PatchNotes.CHANGELOG_URL = "https://steamcommunity.com/sharedfiles/filedetails/changelog/3721602150"

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

-- Hero highlights — up to 4 cards. { title, desc }.
---@return { title:string, desc:string }[]
function ManualSave.PatchNotes.highlights()
    return {
        { title = getText("UI_MSM_Patch_H1_T"), desc = getText("UI_MSM_Patch_H1_D") },
        { title = getText("UI_MSM_Patch_H2_T"), desc = getText("UI_MSM_Patch_H2_D") },
        { title = getText("UI_MSM_Patch_H3_T"), desc = getText("UI_MSM_Patch_H3_D") },
        { title = getText("UI_MSM_Patch_H4_T"), desc = getText("UI_MSM_Patch_H4_D") },
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
