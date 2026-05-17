-- UI/Base/Widgets/Sections/SettingsWidgets.lua
-- Shared row widgets used across Settings sections.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- Checkbox toggle row: checkbox + title + description + bottom separator.
-- opts: { x?, y, w, h?, label, desc, getValue, onToggle }
function ManualSave.makeSettingsCheckRow(parent, opts)
    local TH    = ManualSave.Theme
    local FHS   = TH.FONT_HGT_SMALL
    local ROW_H = opts.h or (FHS * 2 + 28)
    local cbSz  = 13
    local cbX   = 14
    local cbY   = 4 + math.floor((FHS - cbSz) / 2)
    local textX = cbX + cbSz + 8
    local label = opts.label or ""
    local desc  = opts.desc  or ""
    return ManualSave.makePanel(parent, {
        x=opts.x or 0, y=opts.y, w=opts.w, h=ROW_H,
        bg={ r=0, g=0, b=0, a=0 }, border=false,
        prerender = function(fc)
            local TH2  = ManualSave.Theme
            local isOn = opts.getValue and opts.getValue()
            local over = false
            pcall(function() over = fc:isMouseOver() end)
            if over then
                fc:drawRect(0, 0, fc.width, fc.height - 1, 0.04, 1, 1, 1)
            end
            fc:drawRect(0, fc.height - 1, fc.width, 1,
                0.3, TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
            ManualSave.Draw.checkbox(fc, cbX, cbY, cbSz, isOn)
            local tR, tG, tB, tA
            if isOn then
                tR, tG, tB, tA = TH2.TEXT_R, TH2.TEXT_G, TH2.TEXT_B, 1.0
            else
                tR, tG, tB, tA = TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B, 0.85
            end
            fc:drawText(label, textX, 4, tR, tG, tB, tA, UIFont.Small)
            fc:drawText(desc, textX, 4 + TH2.FONT_HGT_SMALL + 3,
                TH2.DIM_R, TH2.DIM_G, TH2.DIM_B, 0.65, UIFont.Small)
        end,
        onMouseDown = function()
            if opts.onToggle then opts.onToggle() end
            return true
        end,
    })
end

-- Row with title on the left and a segmented toolbar on the right.
-- Compact (single-line) when opts.descKey is nil.
-- opts: { x?, y, w, h?, titleKey, descKey?, key, items, onPreview? }
-- items: array of { id, labelKey, value }
function ManualSave.makeSettingToolbar(parent, opts)
    local TH      = ManualSave.Theme
    local compact = not opts.descKey
    local ROW_H   = opts.h or (compact
        and (TH.BUTTON_HGT + 12)
        or  (TH.FONT_HGT_SMALL * 2 + TH.BUTTON_HGT + 32))

    local p = ISPanel:new(opts.x or 0, opts.y, opts.w, ROW_H)
    p.backgroundColor = { r=0, g=0, b=0, a=0 }
    p.borderColor     = { r=0, g=0, b=0, a=0 }
    p:initialise()
    p:instantiate()

    p.prerender = function(self2)
        ISPanel.prerender(self2)
        local TH2    = ManualSave.Theme
        local titleY = compact
            and math.floor((self2.height - TH2.FONT_HGT_SMALL) / 2)
            or  12
        self2:drawRect(0, self2.height - 1, self2.width, 1,
            0.3, TH2.LINE_R, TH2.LINE_G, TH2.LINE_B)
        self2:drawText(getText(opts.titleKey), 14, titleY,
            TH2.TEXT_R, TH2.TEXT_G, TH2.TEXT_B, 1, UIFont.Small)
        if not compact then
            self2:drawText(getText(opts.descKey), 14, titleY + TH2.FONT_HGT_SMALL + 4,
                TH2.MUTED_R, TH2.MUTED_G, TH2.MUTED_B, 0.8, UIFont.Small)
        end
    end

    local curVal  = ManualSave.Config.get(opts.key)
    local tbItems = {}
    for _, it in ipairs(opts.items) do
        table.insert(tbItems, {
            id     = it.id,
            label  = getText(it.labelKey),
            kind   = "toggle",
            group  = "ss_" .. opts.key,
            active = (curVal == it.value),
        })
    end
    local tbH = TH.BUTTON_HGT
    local tbW = math.floor(opts.w * 0.55)
    local tbX = opts.w - 14 - tbW
    local tbY = compact
        and math.floor((ROW_H - tbH) / 2)
        or  (ROW_H - tbH - 10)

    ManualSave.makeToolbar(p, {
        x=tbX, y=tbY, w=tbW, h=tbH,
        items    = tbItems,
        onToggle = function(id)
            for _, it in ipairs(opts.items) do
                if it.id == id then
                    if opts.onPreview then opts.onPreview(it.value) end
                    ManualSave.Config.set(opts.key, it.value)
                    break
                end
            end
        end,
    })

    if parent then parent:addChild(p) end
    return p
end

print("[ManualSaveMod] UI/Base/Widgets/Sections/SettingsWidgets.lua loaded.")
