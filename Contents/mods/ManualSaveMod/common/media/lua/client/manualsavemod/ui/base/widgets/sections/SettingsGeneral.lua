-- UI/Base/Widgets/Sections/SettingsGeneral.lua
-- General settings section: confirm toggles + thumbnail chooser.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- opts: { x, y, w, h }
function ManualSave.makeSettingsGeneral(parent, opts)
    local TH    = ManualSave.Theme
    local w     = opts.w
    local p     = ManualSave.makeScrollPanel(parent, {
        x=opts.x, y=opts.y, w=w, h=opts.h, border=false, bg={r=0,g=0,b=0,a=0},
    })
    local ROW_H = TH.FONT_HGT_SMALL * 2 + 18
    local cy    = TH.PAD

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_NavGeneral") end,
        r=TH.ACCENT_R, g=TH.ACCENT_G, b=TH.ACCENT_B, a=0.85,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2 + TH.GAP

    local rows = {
        { key="CONFIRM_LOAD",      titleKey="UI_MSM_Settings_ConfirmLoadTitle", descKey="UI_MSM_Settings_ConfirmLoadDesc" },
        { key="CONFIRM_DELETE",    titleKey="UI_MSM_Settings_ConfirmDelTitle",  descKey="UI_MSM_Settings_ConfirmDelDesc"  },
        { key="SHOW_WATCHER_WARN", titleKey="UI_MSM_Settings_WatcherWarnTitle", descKey="UI_MSM_Settings_WatcherWarnDesc" },
        { key="SHOW_PATCH_NOTES",  titleKey="UI_MSM_Settings_PatchNotesTitle", descKey="UI_MSM_Settings_PatchNotesDesc" },
    }
    -- Leave 8px on the right for the scrollbar gutter, otherwise the row eats
    -- the click on the bar.
    local rowW = w - 8
    for _, row in ipairs(rows) do
        local key = row.key
        local r = ManualSave.makeSettingsCheckRow(p, {
            x=0, y=cy, w=rowW, h=ROW_H,
            label    = getText(row.titleKey),
            desc     = getText(row.descKey),
            getValue = function() return ManualSave.Config.get(key) ~= "0" end,
            onToggle = function()
                ManualSave.Config.set(key, ManualSave.Config.get(key) == "0" and "1" or "0")
            end,
        })
        cy = cy + (r and r:getHeight() or ROW_H)
    end

    -- The last toggle row already draws its own bottom separator, so no extra
    -- divider here (avoids a doubled line + dead space before "Default name").
    cy = cy + TH.GAP

    -- Default save name: pre-fills the SaveScreen name field. Auto-increments
    -- to "Name (1)", "Name (2)", ... if a slot with the base name already
    -- exists. Stored as a plain string in Config; empty falls back to "Save"
    -- via the SaveScreen pre-fill helper.
    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_SaveNameTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2
    local descName = ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28, wrap=true,
        getText = function() return getText("UI_MSM_Settings_SaveNameDesc") end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
    })
    cy = cy + descName.panel:getHeight() + TH.GAP

    do
        local cur = ManualSave.Config.get("SAVE_NAME_DEFAULT")
        if not cur or cur == "" then
            cur = "Save"
            ManualSave.Config.set("SAVE_NAME_DEFAULT", cur)
        end
        ManualSave.makeTextInput(p, {
            x=14, y=cy, w=w-28, h=TH.BUTTON_HGT,
            value       = cur,
            placeholder = "Save",
            onChange    = function(text)
                ManualSave.Config.set("SAVE_NAME_DEFAULT", text or "")
            end,
        })
    end
    cy = cy + TH.BUTTON_HGT + TH.GAP

    -- Divider before "Save image"
    ManualSave.makePanel(p, {
        x=0, y=cy, w=w, h=1,
        bg={r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=0.4}, border=false,
    })
    cy = cy + 1 + TH.GAP

    ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28,
        getText = function() return getText("UI_MSM_Settings_SaveImageTitle") end,
        r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1,
    })
    cy = cy + TH.FONT_HGT_SMALL + 2
    local descImg = ManualSave.makeLabel(p, {
        x=14, y=cy, w=w-28, wrap=true,
        getText = function() return getText("UI_MSM_Settings_SaveImageDesc") end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.8,
    })
    cy = cy + descImg.panel:getHeight() + TH.GAP

    -- Screenshot capture is Windows-only for now: the Linux/macOS Watcher port
    -- doesn't have a portable way to grab the game window from outside PZ.
    -- On those systems we replace the radio + AI placeholder note with a
    -- single explanatory paragraph; saves are created without a thumbnail and
    -- the Lua side falls back to its built-in "no thumb" tile.
    local isWindows = true
    if ManualSave.Platform and ManualSave.Platform.refresh then
        ManualSave.Platform.refresh()
        isWindows = ManualSave.Platform.isWindows()
    end

    if isWindows then
        ManualSave.makeOptionCards(p, {
            x=14, y=cy, w=w-28,
            getValue = function() return ManualSave.Config.get("THUMB_SOURCE") end,
            onChange = function(val) ManualSave.Config.set("THUMB_SOURCE", val) end,
            cards = {
                { value="screenshot",  titleKey="UI_MSM_Settings_ThumbScreenshotTitle",
                  tex=getTexture("media/textures/MSM_ThumbPreview_Screenshot.png") },
                { value="placeholder", titleKey="UI_MSM_Settings_ThumbPlaceholderTitle",
                  tex=getTexture("media/textures/MSM_ThumbPreview_Placeholder.png") },
            },
        })
        cy = cy + 64 + 26 + TH.GAP   -- card body (~64) + internal title (~26) + bottom gap

        -- AI placeholder notice + Help link. The default thumbnail art is currently
        -- AI-generated; a "?" button jumps to the Help page that explains this and
        -- invites artists to contribute real art.
        local btnSz   = 22
        local aiLblW  = (w - 28) - btnSz - TH.GAP
        local aiLbl   = ManualSave.makeLabel(p, {
            x=14, y=cy + math.floor((btnSz - TH.FONT_HGT_SMALL) / 2), w=aiLblW, wrap=true,
            getText = function() return getText("UI_MSM_Settings_AINote") end,
            r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.75,
        })
        ManualSave.makeButton(p, {
            x = 14 + aiLblW + TH.GAP, y = cy, w = btnSz, h = btnSz,
            label = "?", style = "normal",
            onClick = function()
                if ManualSave.openHelpScreen then ManualSave.openHelpScreen("ai_placeholders") end
            end,
        })
        cy = cy + math.max(aiLbl.panel:getHeight(), btnSz) + TH.GAP
    else
        local warnLbl = ManualSave.makeLabel(p, {
            x=14, y=cy, w=w-28, wrap=true,
            getText = function() return getText("UI_MSM_Settings_ScreenshotNotAvailable") end,
            r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.9,
        })
        cy = cy + warnLbl.panel:getHeight() + TH.GAP
    end

    -- Declare the exact content height so the scroll range covers the cards
    -- (whose title is drawn below their panel bounds).
    if p.setContentHeight then p.setContentHeight(cy) end

    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsGeneral.lua loaded.")
