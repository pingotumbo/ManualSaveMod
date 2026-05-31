-- UI/Base/Widgets/Elements/SectionHeader.lua
-- Standardised sub-section label and danger-zone separator for panel layouts.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- Dim-coloured sub-section label (e.g. "Save Actions", "World Actions").
-- opts: { x?, y, w, text }
-- Returns height consumed (use to advance cy).
function ManualSave.makeSectionSubHeader(parent, opts)
    local TH = ManualSave.Theme
    local h  = TH.FONT_HGT_SMALL + 4
    ManualSave.makeLabel(parent, {
        x=opts.x or 0, y=opts.y, w=opts.w, h=h,
        text  = opts.text,
        textY = 2,
        r=TH.DIM_R, g=TH.DIM_G, b=TH.DIM_B, a=0.8,
    })
    return h
end

-- Danger-zone block: thin red separator line + red label.
-- Visually signals the start of destructive/irreversible options.
-- opts: { x?, y, w, labelKey }
-- Returns height consumed (use to advance cy).
function ManualSave.makeDangerSeparator(parent, opts)
    local TH  = ManualSave.Theme
    local x   = opts.x or 0

    ManualSave.makePanel(parent, {
        x=x, y=opts.y, w=opts.w, h=1,
        bg={ r=TH.DANGER_R * 0.7, g=TH.DANGER_G * 0.4, b=TH.DANGER_B * 0.35, a=0.9 },
        border=false,
    })
    ManualSave.makeLabel(parent, {
        x=x, y=opts.y + 1 + 6, w=opts.w,
        getText = function() return getText(opts.labelKey) end,
        r=TH.DANGER_R, g=TH.DANGER_G, b=TH.DANGER_B, a=0.85,
    })

    return 1 + 6 + TH.FONT_HGT_SMALL + 2
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/SectionHeader.lua loaded.")
