-- UI/Base/Widgets/Panels/Progress.lua
-- Fixed-position bare HUD for copy/save progress.
-- Sits bottom-centre above the hotbar, no background, no panel chrome.
-- Returns { close: fun(), showDone: fun(), inject: fun(copied, total) }
---@diagnostic disable: undefined-global

ManualSave = ManualSave or {}

-- Set to true to show a cycling demo on game start (remove when done testing)
local PROGRESS_TEST_MODE = false

local PROGRESS_FILE = "ManualSave_Progress.txt"
local POLL_EVERY    = 6   -- read file every N frames (~10x/sec at 60fps)
local SPINNER_FPS = 12  -- frames between Spiffo frame advance

local SPINNER_FRAMES = {
    "media/textures/MSM_SpiffoHammer_01_WindUp.png",
    "media/textures/MSM_SpiffoHammer_02_MidSwing.png",
    "media/textures/MSM_SpiffoHammer_03_Strike.png",
    "media/textures/MSM_SpiffoHammer_04_Rest.png",
}
local SPINNER_DONE = "media/textures/MSM_SpiffoHammer_05_Done.png"

local HUD_W_DEFAULT = 432
local PAD_RIGHT     = 14
local BAR_H         = 3

-- ── Progress file reader ──────────────────────────────────────────────────────

local function formatBytes(b)
    if b >= 1073741824 then
        return string.format("%.2f GB", b / 1073741824)
    elseif b >= 1048576 then
        return string.format("%.1f MB", b / 1048576)
    elseif b >= 1024 then
        return string.format("%.0f KB", b / 1024)
    else
        return b .. " B"
    end
end

local function readProgress()
    local r = getFileReader(PROGRESS_FILE, true)
    if not r then return nil end
    local data = {}
    while true do
        local line = r:readLine()
        if line == nil then break end
        line = line:match("^%s*(.-)%s*$")
        local k, v = line:match("^(.-)=(.+)$")
        if k and v then data[k] = v end
    end
    r:close()
    local copied = tonumber(data.COPIED)
    local total  = tonumber(data.TOTAL)
    if not copied or not total then return nil end
    return { copied=copied, total=total, started=tonumber(data.STARTED) }
end

-- ── openProgressPanel ─────────────────────────────────────────────────────────

-- opts.width   number?   HUD width in pixels (default 432)
-- opts.x       number?   ignored (position is derived from HUD_POS_X / HUD_POS_Y)
-- opts.label   string?   slot name shown in HUD
-- opts.onClose fun?
---@param opts { width:number?, x:number?, label:string?, onClose:fun()? }?
---@return { close: fun(), showDone: fun(), inject: fun(number, number) }
function ManualSave.openProgressPanel(opts)
    opts = opts or {}

    local cfg = ManualSave.Config
    local style   = cfg and cfg.get("SPINNER_STYLE") or "spiffo"
    local posX    = tonumber(cfg and cfg.get("HUD_POS_X") or "0.500") or 0.500
    local posY    = tonumber(cfg and cfg.get("HUD_POS_Y") or "0.880") or 0.880
    local hudHiddenFlag = (cfg and cfg.get("HUD_HIDDEN") or "0") == "1"

    -- Layout derived from size setting
    local sprSz = math.max(24, math.min(128, tonumber(cfg and cfg.get("SPINNER_SIZE_PX")) or 64))
    local hudH  = sprSz + 16

    local W        = opts.width or HUD_W_DEFAULT
    local sprX     = 14
    local sprY     = math.floor((hudH - sprSz) / 2)
    local sprGap   = 12
    local contentX = (style ~= "none") and (sprX + sprSz + sprGap) or sprX
    local contentW = W - contentX - PAD_RIGHT
    local labelY   = math.floor((hudH - 24) / 2)
    local barY     = labelY + 14 + 7

    -- Spiffo textures (only loaded when needed)
    local spinnerTexs = {}
    if style == "spiffo" then
        for _, path in ipairs(SPINNER_FRAMES) do
            table.insert(spinnerTexs, getTexture(path))
        end
    end
    local spinnerDoneTex = getTexture(SPINNER_DONE)
    local nFrames = math.max(1, #spinnerTexs)

    -- State
    local copied        = 0
    local total         = 0
    local pct           = 0
    local frames        = 0
    local done          = false
    local showDoneFrame = false
    local spinnerIdx    = 1
    local counterText   = getText("UI_MSM_Progress_Preparing")
    local speedText     = ""
    local startedEpoch  = nil

    ManualSave._progressActive = true
    if ManualSave.UI then pcall(ManualSave.UI.evalConditions) end

    -- ── Hidden mode: no panel, tracking only ─────────────────────────────────

    if hudHiddenFlag then
        local handler
        handler = function()
            if done then Events.OnRenderTick.Remove(handler); return end
            frames = frames + 1
            if frames % POLL_EVERY ~= 0 then return end
            local prog = readProgress()
            if prog then
                copied = prog.copied; total = prog.total
                pct    = (total > 0) and math.min(1, copied / total) or 0
            end
        end
        Events.OnRenderTick.Add(handler)

        return {
            close = function()
                done = true
                ManualSave._progressActive = false
                if ManualSave.UI then pcall(ManualSave.UI.evalConditions) end
                Events.OnRenderTick.Remove(handler)
                if opts.onClose then pcall(opts.onClose) end
            end,
            showDone = function() end,
            inject   = function(c, t)
                copied = c; total = t
                pct    = (t > 0) and math.min(1, c / t) or 0
            end,
        }
    end

    -- ── Visible panel ─────────────────────────────────────────────────────────

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local hudX = math.max(0, math.min(screenW - W,   math.floor(screenW * posX - W   / 2)))
    local hudY = math.max(0, math.min(screenH - hudH, math.floor(screenH * posY - hudH / 2)))

    local panel = ISPanel:new(hudX, hudY, W, hudH)
    panel.drawBackground = false
    panel.drawBorder     = false

    panel.prerender = function(self2)
        -- Spinner
        if style == "spiffo" then
            local tex = showDoneFrame and spinnerDoneTex or spinnerTexs[spinnerIdx]
            if tex then
                self2:drawTextureScaled(tex, sprX, sprY, sprSz, sprSz, 1)
            end
        end

        -- Slot label (white) with 1px drop shadow
        local labelText = opts.label or ""
        self2:drawText(labelText, contentX + 1, labelY + 1, 0, 0, 0, 0.75, UIFont.Small)
        self2:drawText(labelText, contentX,     labelY,     1, 1, 1, 1,    UIFont.Small)

        -- Counter text (dim, right-aligned) with drop shadow
        if counterText ~= "" then
            local ctW = getTextManager():MeasureStringX(UIFont.Small, counterText)
            local ctX = W - PAD_RIGHT - ctW
            self2:drawText(counterText, ctX + 1, labelY + 1, 0,    0,    0,    0.75, UIFont.Small)
            self2:drawText(counterText, ctX,     labelY,     0.84, 0.80, 0.76, 0.70, UIFont.Small)
        end

        -- Progress bar background
        self2:drawRect(contentX, barY, contentW, BAR_H, 0.55, 0, 0, 0)

        -- Progress bar fill
        local fillW = math.floor(contentW * pct)
        if fillW > 0 then
            if showDoneFrame then
                self2:drawRect(contentX, barY, fillW, BAR_H, 0.85, 0.37, 0.63, 0.35)
            else
                self2:drawRect(contentX, barY, fillW, BAR_H, 0.85, 0.77, 0.48, 0.24)
            end
        end

        -- Speed / ETA line below bar
        if speedText ~= "" then
            local speedY = barY + BAR_H + 6
            self2:drawText(speedText, contentX + 1, speedY + 1, 0,    0,    0,    0.75, UIFont.Small)
            self2:drawText(speedText, contentX,     speedY,     0.84, 0.80, 0.76, 0.55, UIFont.Small)
        end
    end

    panel:initialise()
    panel:instantiate()
    panel:addToUIManager()

    local handler
    handler = function()
        if done then Events.OnRenderTick.Remove(handler); return end
        frames = frames + 1

        if frames % SPINNER_FPS == 0 then
            spinnerIdx = (spinnerIdx % nFrames) + 1
        end

        if frames % POLL_EVERY ~= 0 then return end
        local prog = readProgress()
        if prog then
            copied = prog.copied
            total  = prog.total
            if prog.started and not startedEpoch then startedEpoch = prog.started end
            pct = (total > 0) and math.min(1, copied / total) or 0
            if total > 0 then
                counterText = formatBytes(copied) .. " / " .. formatBytes(total)
                if startedEpoch and copied > 0 then
                    local elapsed = os.time() - startedEpoch
                    if elapsed > 0 then
                        local speedBps = copied / elapsed
                        local spdStr   = formatBytes(math.floor(speedBps)) .. "/s"
                        local eta      = (speedBps > 0 and total > copied)
                            and math.ceil((total - copied) / speedBps) or nil
                        speedText = eta and (spdStr .. "  |  " .. eta .. "s") or spdStr
                    end
                end
            else
                counterText = getText("UI_MSM_Progress_Preparing")
                speedText   = ""
            end
        end
    end
    Events.OnRenderTick.Add(handler)

    local function closePanel()
        done = true
        ManualSave._progressActive = false
        if ManualSave.UI then pcall(ManualSave.UI.evalConditions) end
        Events.OnRenderTick.Remove(handler)
        pcall(function() panel:removeFromUIManager() end)
        if opts.onClose then pcall(opts.onClose) end
    end

    local function showDone()
        showDoneFrame = true
        pct       = 1
        speedText = ""
        if total > 0 then
            counterText = formatBytes(total) .. " / " .. formatBytes(total)
        end
    end

    local function inject(c, t)
        copied      = c
        total       = t
        pct         = t > 0 and math.min(1, c / t) or 0
        counterText = t > 0
            and (formatBytes(c) .. " / " .. formatBytes(t))
            or  getText("UI_MSM_Progress_Preparing")
    end

    return { close=closePanel, showDone=showDone, inject=inject }
end

-- ── Test mode ─────────────────────────────────────────────────────────────────
-- Cycling demo: preparing → copying → done (>1s) → repeat.
-- Flip PROGRESS_TEST_MODE to false (top of file) when done testing.

if PROGRESS_TEST_MODE then
    local DEMO_TOTAL = 2 * 1024 * 1024 * 1024
    local DEMO_PREP  = 30
    local DEMO_COPY  = 180
    local DEMO_DONE  = 80

    local function runDemo()
        local p = ManualSave.openProgressPanel({ label = "TestSave_01" })
        local f = 0
        local loopH
        loopH = function()
            f = f + 1
            if f <= DEMO_PREP then
                -- preparing
            elseif f <= DEMO_PREP + DEMO_COPY then
                local c = math.floor((f - DEMO_PREP) / DEMO_COPY * DEMO_TOTAL)
                p.inject(c, DEMO_TOTAL)
            elseif f == DEMO_PREP + DEMO_COPY + 1 then
                p.inject(DEMO_TOTAL, DEMO_TOTAL)
                p.showDone()
            elseif f > DEMO_PREP + DEMO_COPY + DEMO_DONE then
                Events.OnRenderTick.Remove(loopH)
                p.close()
                runDemo()
            end
        end
        Events.OnRenderTick.Add(loopH)
    end

    Events.OnGameStart.Add(runDemo)
    Events.OnMainMenuEnter.Add(runDemo)
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Progress.lua loaded.")
