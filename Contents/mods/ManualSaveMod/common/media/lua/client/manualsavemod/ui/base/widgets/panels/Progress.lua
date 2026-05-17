-- UI/Base/Widgets/Panels/Progress.lua
-- Generic floating progress panel (poll-based, file-driven).
-- Reusable for any async file-copy or watcher operation.
--
-- opts = {
--   title   string?   panel title (default: UI_MSM_Progress_Title)
--   label   string?   subtitle line shown under the bar
--   onClose fun()?    called when the panel is dismissed
-- }
---@diagnostic disable: undefined-global, undefined-field, undefined-doc-name

ManualSave = ManualSave or {}

local PROGRESS_FILE = "ManualSave_Progress.txt"
local POLL_EVERY    = 6   -- read file every N frames (~10x/sec at 60fps)

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
    return { copied=copied, total=total }
end

---@param opts { title:string?, label:string?, onClose:fun()? }?
---@return { close: fun() }
function ManualSave.openProgressPanel(opts)
    opts = opts or {}
    local TH  = ManualSave.Theme
    local PAD = TH.PAD
    local GAP = TH.GAP
    local FHS = TH.FONT_HGT_SMALL
    local FHL = TH.FONT_HGT_LARGE

    local W      = 420
    local BAR_H  = 14
    local titleH = FHL + 22
    local bodyH  = PAD + FHS + GAP + BAR_H + GAP + FHS + PAD
    local H      = titleH + bodyH

    local copied      = 0
    local total       = 0
    local pct         = 0
    local frames      = 0
    local done        = false

    local d = ManualSave.makeFloatingPanel({
        w     = W,
        h     = H,
        title = opts.title or getText("UI_MSM_Progress_Title"),
    })
    local p = d.panel

    local labelY  = titleH + PAD
    local barY    = labelY + FHS + GAP
    local countY  = barY   + BAR_H + GAP
    local barX    = PAD
    local barW    = W - PAD * 2

    if opts.label then
        ManualSave.makeLabel(p, {
            x=PAD, y=labelY, w=W-PAD*2, h=FHS,
            text = opts.label,
            r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=0.9,
        })
    end

    local counterText = getText("UI_MSM_Progress_Preparing")
    ManualSave.makeLabel(p, {
        x=PAD, y=countY, w=W-PAD*2, h=FHS,
        getText = function() return counterText end,
        r=TH.MUTED_R, g=TH.MUTED_G, b=TH.MUTED_B, a=0.85,
    })

    local _basePre = p.prerender
    p.prerender = function(self2)
        if _basePre then _basePre(self2) end
        self2:drawRect(barX, barY, barW, BAR_H, 0.25,
            TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
        local fillW = math.floor(barW * pct)
        if fillW > 0 then
            self2:drawRect(barX, barY, fillW, BAR_H, 0.85,
                TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
        end
        self2:drawRectBorder(barX, barY, barW, BAR_H, 0.35,
            TH.LINE_R, TH.LINE_G, TH.LINE_B)
        local pctStr = math.floor(pct * 100) .. "%"
        local pctW   = getTextManager():MeasureStringX(UIFont.Small, pctStr)
        self2:drawText(pctStr, W - PAD - pctW, countY,
            TH.MUTED_R, TH.MUTED_G, TH.MUTED_B, 0.7, UIFont.Small)
    end

    local handler
    handler = function()
        if done then Events.OnRenderTick.Remove(handler); return end
        frames = frames + 1
        if frames % POLL_EVERY ~= 0 then return end
        local prog = readProgress()
        if prog then
            copied = prog.copied
            total  = prog.total
            pct    = (total > 0) and math.min(1, copied / total) or 0
            if total > 0 then
                counterText = getText("UI_MSM_Progress_Counter",
                    tostring(copied), tostring(total))
            else
                counterText = getText("UI_MSM_Progress_Preparing")
            end
        end
    end
    Events.OnRenderTick.Add(handler)

    d.onClose(function()
        done = true
        Events.OnRenderTick.Remove(handler)
        if opts.onClose then pcall(opts.onClose) end
    end)

    d.open()

    return {
        close = function() d.close() end,
    }
end

print("[ManualSaveMod] UI/Base/Widgets/Panels/Progress.lua loaded.")
