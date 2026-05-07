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
end

Events.OnGameBoot.Add(ManualSave.Theme.init)

print("[ManualSaveMod] UI/Base/Config/Theme.lua loaded.")
