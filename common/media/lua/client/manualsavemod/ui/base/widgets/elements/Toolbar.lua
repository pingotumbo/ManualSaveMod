-- UI/Base/Elements/Toolbar.lua
-- Horizontal row of toggle-buttons (filter chips) and/or action buttons.
-- Each item is either a toggle (mutually exclusive group or independent) or
-- a plain action button. Adds itself to parent automatically.
---@diagnostic disable: undefined-global, undefined-doc-name, undefined-field

ManualSave = ManualSave or {}

-- Creates a toolbar and adds it to parent.
--
-- opts:
--   x, y      number
--   w, h      number
--   gap       number?   space between buttons (default TH.GAP)
--   items     table[]   ordered list of button descriptors:
--     { id:string, label:string, kind:"toggle"|"action", group:string?, active:boolean? }
--       id     — unique identifier returned by callbacks
--       label  — button text
--       kind   — "toggle": stays active/inactive; "action": fires and resets
--       group  — if set, activating this item deactivates all others in the same group
--       active — initial state for toggles (default false)
--   onToggle  fun(id:string, active:boolean)?  called when a toggle changes state
--   onAction  fun(id:string)?                  called when an action button is clicked
--
---@param parent ISPanel
---@param opts { x:number, y:number, w:number, h:number, gap:number?, items:table[], onToggle:fun(id:string,active:boolean)?, onAction:fun(id:string)? }
---@return { panel:ISPanel, setActive:fun(id:string,v:boolean), getActive:fun(id:string):boolean, setEnabled:fun(id:string,v:boolean) }
function ManualSave.makeToolbar(parent, opts)
    local TH  = ManualSave.Theme
    local gap = opts.gap or TH.GAP

    -- State table keyed by id
    local state   = {}   -- [id] = { active=bool, enabled=bool, item=descriptor }
    local btnMap  = {}   -- [id] = ISButton

    for _, item in ipairs(opts.items) do
        state[item.id] = {
            active  = item.active or false,
            enabled = true,
            item    = item,
        }
    end

    local p = ISPanel:new(opts.x, opts.y, opts.w, opts.h)
    p.backgroundColor = { r=0, g=0, b=0, a=0 }
    p.borderColor     = { r=0, g=0, b=0, a=0 }
    p:initialise()
    p:instantiate()

    -- Layout: divide width evenly if no explicit widths, else use label-fit
    local totalGap = gap * math.max(0, #opts.items - 1)
    local btnW = math.floor((opts.w - totalGap) / math.max(1, #opts.items))

    local cx = 0
    for _, item in ipairs(opts.items) do
        local id = item.id
        local function handleClick(_)
            local s = state[id]
            if not s or not s.enabled then return end
            if item.kind == "toggle" then
                if item.group then
                    -- Sticky group: clicking an active item keeps it active and re-fires
                    -- the callback (caller can detect direction toggle from same id).
                    -- Clicking an inactive item activates it and deactivates peers.
                    if not s.active then
                        for _, other in ipairs(opts.items) do
                            if other.group == item.group and other.id ~= id then
                                state[other.id].active = false
                            end
                        end
                        s.active = true
                    end
                    if opts.onToggle then pcall(opts.onToggle, id, true) end
                else
                    local newActive = not s.active
                    s.active = newActive
                    if opts.onToggle then pcall(opts.onToggle, id, newActive) end
                end
            else
                if opts.onAction then pcall(opts.onAction, id) end
            end
        end

        local btn = ISButton:new(cx, 0, btnW, opts.h, item.label, p, handleClick)
        btn:initialise()
        btn:instantiate()
        btn.backgroundColor          = { r=0, g=0, b=0, a=0 }
        btn.backgroundColorMouseOver = { r=1, g=1, b=1, a=0.05 }
        btn.borderColor = { r=TH.LINE_R, g=TH.LINE_G, b=TH.LINE_B, a=1 }
        btn.textColor   = { r=TH.TEXT_R, g=TH.TEXT_G, b=TH.TEXT_B, a=1 }

        local capturedId = id
        btn.render = function(self2)
            local s = state[capturedId]
            local alpha    = (s and s.enabled) and 1.0 or 0.28
            local isActive = s and s.active

            local over = false
            pcall(function() over = self2:isMouseOver() end)
            if over and (s and s.enabled) then
                if isActive then
                    self2:drawRect(0, 0, self2.width, self2.height, 0.10,
                        TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B)
                else
                    self2:drawRect(0, 0, self2.width, self2.height, 0.06, 1, 1, 1)
                end
            end

            local bA = alpha
            local bR, bG, bB = TH.LINE_R, TH.LINE_G, TH.LINE_B
            if isActive then
                bR, bG, bB = TH.ACCENT_R, TH.ACCENT_G, TH.ACCENT_B
            end
            self2:drawRectBorder(0, 0, self2.width, self2.height, bA, bR, bG, bB)

            local tR = isActive and TH.ACCENT_R or TH.MUTED_R
            local tG = isActive and TH.ACCENT_G or TH.MUTED_G
            local tB = isActive and TH.ACCENT_B or TH.MUTED_B

            local fh   = getTextManager():getFontHeight(UIFont.Small)
            local tw   = getTextManager():MeasureStringX(UIFont.Small, self2:getTitle())
            local arrowDir = isActive and item.arrowFn and item.arrowFn()
            local arrowW = arrowDir and 9 or 0   -- 5px triangle + 4px gap
            local totalW = tw + arrowW
            local tx = math.floor((self2.width - totalW) / 2)
            self2:drawText(
                self2:getTitle(),
                tx,
                math.floor((self2.height - fh) / 2),
                tR, tG, tB, alpha, UIFont.Small)
            if arrowDir then
                ManualSave.Draw.sortArrow(self2,
                    tx + tw + 4,
                    math.floor((self2.height - 4) / 2),
                    arrowDir == "up", tR, tG, tB, alpha)
            end
        end

        p:addChild(btn)
        btnMap[id] = btn
        cx = cx + btnW + gap
    end

    if parent then parent:addChild(p) end

    local obj = { panel = p }

    ---@param id string
    ---@param v boolean
    function obj.setActive(id, v)
        if state[id] then state[id].active = v end
    end

    ---@param id string
    ---@return boolean
    function obj.getActive(id)
        return state[id] and state[id].active or false
    end

    ---@param id string
    ---@param v boolean
    function obj.setEnabled(id, v)
        if state[id] then
            state[id].enabled = v
            if btnMap[id] then btnMap[id]:setEnable(v) end
        end
    end

    return obj
end

print("[ManualSaveMod] UI/Base/Widgets/Elements/Toolbar.lua loaded.")
