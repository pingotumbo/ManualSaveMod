-- UI/Base/Widgets/Sections/ModScrollList.lua
-- Scrollable mod list with checkbox + icon badge row renderer for EditModsScreen.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave              = ManualSave or {}
ManualSave.EditModsScreen = ManualSave.EditModsScreen or {}

local function drawModRow(panel, item, x, y, w, h, isSelected, _)
    local TH = ManualSave.Theme
    local FHS = TH.FONT_HGT_SMALL
    local cr, cg, cb, ca
    if item.status == "missing" then
        cr, cg, cb, ca = TH.WARN_R, TH.WARN_G, TH.WARN_B, 1.0
    elseif item.inSave then
        cr, cg, cb, ca = TH.TEXT_R, TH.TEXT_G, TH.TEXT_B, 1.0
    else
        cr, cg, cb, ca = TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.55
    end

    -- Selected-row highlight (keyboard / gamepad cursor). Only draws when
    -- nav mode is active so mouse users don't see a permanent highlight.
    if isSelected and ManualSave.InputNav and ManualSave.InputNav.keyboardActive then
        panel:drawRect(x, y, w, h,
            TH.FOCUS_BG_A, TH.FOCUS_BG_R, TH.FOCUS_BG_G, TH.FOCUS_BG_B)
    end

    ManualSave.Draw.separator(panel, x, y + h - 1, w, 0.18)

    local cbSz = 13
    local cbX  = x + 8
    local cbY  = y + math.floor((h - cbSz) / 2)
    ManualSave.Draw.checkbox(panel, cbX, cbY, cbSz, item.checked)

    local bSz = 24
    local bX  = cbX + cbSz + 8
    local bY2 = y + math.floor((h - bSz) / 2)
    ManualSave.Draw.iconBadge(panel, bX, bY2, bSz, item.letter, item.icon, cr, cg, cb, ca)

    if item.status == "missing" then
        local bt  = getText("UI_MSM_EditMods_BadgeMissing")
        local btW = getTextManager():MeasureStringX(UIFont.Small, bt) + 10
        local btH = FHS + 4
        ManualSave.Draw.badge(panel, w - 14 - btW, y + math.floor((h - btH) / 2), bt, "warn")
    end

    local textX = bX + bSz + 6
    local nameY2, noteY2
    if item.note ~= "" then
        nameY2 = y + math.floor((h - FHS * 2 - 3) / 2)
        noteY2 = nameY2 + FHS + 3
    else
        nameY2 = y + math.floor((h - FHS) / 2)
    end
    panel:drawText(item.name, textX, nameY2, cr, cg, cb, ca, UIFont.Small)
    if item.note ~= "" then
        panel:drawText(item.note, textX, noteY2,
            TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.7 * ca, UIFont.Small)
    end
end

-- opts: { x, y, w, h, rowH }
function ManualSave.makeModScrollList(parent, opts)
    local TH = ManualSave.Theme
    ManualSave.EditModsScreen._scrollList = ManualSave.makeScrollList(parent, {
        x = opts.x, y = opts.y, w = opts.w, h = opts.h,
        rowH    = opts.rowH,
        items   = {},
        bg      = { r=TH.PANEL_R, g=TH.PANEL_G, b=TH.PANEL_B },
        drawRow = drawModRow,
        -- Mouse click toggles the checkbox (existing behaviour).
        onSelect = function(item, _)
            item.checked = not item.checked
            ManualSave.EditModsScreen.refreshList()
        end,
        -- Enter (or double-click) on the focused row toggles too — keyboard
        -- arrow navigation alone does NOT toggle (handled by separate onNavigate
        -- which we deliberately leave nil so arrow keys are silent).
        onActivate = function(item, _)
            item.checked = not item.checked
            ManualSave.EditModsScreen.refreshList()
        end,
    })
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/ModScrollList.lua loaded.")
