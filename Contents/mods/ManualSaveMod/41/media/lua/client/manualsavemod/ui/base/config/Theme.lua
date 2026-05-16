-- UI/Base/Theme.lua
-- Central visual constants for ManualSaveMod.
-- All components read from ManualSave.Theme — never hardcode colours elsewhere.
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

---@class ManualSave.Theme
ManualSave.Theme = {

    -- ── Colours ───────────────────────────────────────────────────────────────

    -- Backgrounds
    BG_R     = 0.10,  BG_G     = 0.09,  BG_B     = 0.08,  -- main background
    PANEL_R  = 0.13,  PANEL_G  = 0.12,  PANEL_B  = 0.11,  -- card / inner panel

    -- Borders
    LINE_R   = 0.22,  LINE_G   = 0.20,  LINE_B   = 0.18,  -- default border

    -- Text
    TEXT_R   = 0.91,  TEXT_G   = 0.88,  TEXT_B   = 0.84,  -- primary text
    MUTED_R  = 0.54,  MUTED_G  = 0.51,  MUTED_B  = 0.46,  -- secondary / dimmed
    DIM_R    = 0.36,  DIM_G    = 0.34,  DIM_B    = 0.30,  -- labels / captions

    -- Accent (orange)
    ACCENT_R = 0.78,  ACCENT_G = 0.42,  ACCENT_B = 0.24,

    -- Danger (red)
    DANGER_R = 0.72,  DANGER_G = 0.29,  DANGER_B = 0.23,

    -- Native save tag (teal)
    NATIVE_R = 0.25,  NATIVE_G = 0.68,  NATIVE_B = 0.72,

    -- Warning (amber) — used for missing mods and caution states
    WARN_R   = 0.92,  WARN_G   = 0.78,  WARN_B   = 0.22,

    -- ── Overlay ───────────────────────────────────────────────────────────────

    OVERLAY_A      = 0.72,  -- alpha for modal blocking overlay
    OVERLAY_SOFT_A = 0.00,  -- alpha for non-blocking dialog backdrop (transparent)

    -- ── Typography ────────────────────────────────────────────────────────────

    -- Font height constants — computed at runtime in Theme.init()
    FONT_HGT_SMALL  = 0,
    FONT_HGT_MEDIUM = 0,
    FONT_HGT_LARGE  = 0,

    -- ── Spacing ───────────────────────────────────────────────────────────────

    PAD        = 14,   -- standard outer padding
    GAP        = 6,    -- gap between sibling elements
    BORDER_W   = 1,    -- border thickness

    -- ── Sizing ────────────────────────────────────────────────────────────────

    -- Computed at runtime in Theme.init()
    BUTTON_HGT = 0,
    ITEM_HGT   = 0,    -- save list row height (small + medium text + padding)
}

-- Text style definitions: name → {r,g,b,a,font,indent,rule,bar}
-- Used by makeTextBlock, makeScrollText, and other text renderers.
-- This centralizes all styling logic so translations adapt to any language.
---@class ManualSave.TextStyle
---@field r number
---@field g number
---@field b number
---@field a number
---@field font number  (UIFont.Small/Medium/Large)
---@field indent number  (pixels)
---@field rule boolean?  (draw horizontal rule after this line)
---@field bar table?  (left bar: {r,g,b} for callout styles)

---@type table<string, ManualSave.TextStyle>
ManualSave.Styles = {}

-- Called during Theme.init() to populate styles with computed font heights.
function ManualSave.Theme.initStyles()
    local T = ManualSave.Theme
    ManualSave.Styles = {
        header = {
            r = T.ACCENT_R, g = T.ACCENT_G, b = T.ACCENT_B, a = 0.95,
            font = UIFont.Small, indent = 0, rule = true,
        },
        sub = {
            r = T.TEXT_R, g = T.TEXT_G, b = T.TEXT_B, a = 1.0,
            font = UIFont.Small, indent = 0,
        },
        body = {
            r = T.TEXT_R, g = T.TEXT_G, b = T.TEXT_B, a = 0.80,
            font = UIFont.Small, indent = 8,
        },
        dim = {
            r = T.MUTED_R, g = T.MUTED_G, b = T.MUTED_B, a = 1.0,
            font = UIFont.Small, indent = 8,
        },
        warn = {
            r = T.DANGER_R, g = T.DANGER_G, b = T.DANGER_B, a = 0.9,
            font = UIFont.Small, indent = 8,
        },
        good = {
            r = 0.37, g = 0.63, b = 0.35, a = 0.9,
            font = UIFont.Small, indent = 8,
        },
        callout = {
            r = T.TEXT_R, g = T.TEXT_G, b = T.TEXT_B, a = 0.90,
            font = UIFont.Small, indent = 14,
            bar = { r = T.ACCENT_R, g = T.ACCENT_G, b = T.ACCENT_B },
        },
        callout_w = {
            r = T.DANGER_R, g = T.DANGER_G, b = T.DANGER_B, a = 0.85,
            font = UIFont.Small, indent = 14,
            bar = { r = T.DANGER_R, g = T.DANGER_G, b = T.DANGER_B },
        },
        callout_g = {
            r = 0.37, g = 0.63, b = 0.35, a = 0.85,
            font = UIFont.Small, indent = 14,
            bar = { r = 0.37, g = 0.63, b = 0.35 },
        },
        check = {
            r = T.TEXT_R, g = T.TEXT_G, b = T.TEXT_B, a = 0.80,
            font = UIFont.Small, indent = 16,
            bullet_color = { r = T.ACCENT_R, g = T.ACCENT_G, b = T.ACCENT_B },
        },
        gloss_t = {
            r = T.ACCENT_R, g = T.ACCENT_G, b = T.ACCENT_B, a = 1.0,
            font = UIFont.Small, indent = 0,
        },
        gloss_d = {
            r = T.MUTED_R, g = T.MUTED_G, b = T.MUTED_B, a = 0.90,
            font = UIFont.Small, indent = 8,
        },
    }
end

-- Called once before any UI is created (e.g. from the first Events.OnGameBoot).
-- Resolves font-dependent sizes that are only available after the game starts.
function ManualSave.Theme.init()
    local T  = ManualSave.Theme
    local tm = getTextManager()
    T.FONT_HGT_SMALL  = tm:getFontHeight(UIFont.Small)
    T.FONT_HGT_MEDIUM = tm:getFontHeight(UIFont.Medium)
    T.FONT_HGT_LARGE  = tm:getFontHeight(UIFont.Large)
    T.BUTTON_HGT      = T.FONT_HGT_SMALL + 10
    T.ITEM_HGT        = T.FONT_HGT_SMALL + T.FONT_HGT_MEDIUM + 18
    ManualSave.Theme.initStyles()
end

Events.OnGameBoot.Add(ManualSave.Theme.init)

print("[ManualSaveMod] UI/Base/Config/Theme.lua loaded.")
