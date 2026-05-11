-- UI/Screens/MoreScreen.lua
-- Detailed save inspector shown when "More" is clicked in LoadScreen.
-- Pure assembler: all logic lives in base/widgets/sections/.
---@diagnostic disable: undefined-global, undefined-doc-name, inject-field, undefined-field, duplicate-set-field

ManualSave            = ManualSave or {}
ManualSave.MoreScreen = ManualSave.MoreScreen or {}

local _coverObj   = nil
local _mapExpand  = nil
local _modsExpand = nil

function ManualSave.openMoreScreen()
    if _coverObj then return end
    local ls = ManualSave.LoadScreen
    if not ls._p or not ls._state or not ls._state.selected then return end

    local TH       = ManualSave.Theme
    local st       = ls._state
    local m        = st.selected
    local dims     = ls._dims
    local contentH = dims.h - dims.titleH - dims.footerH

    local _prevBat = nil
    _coverObj = ManualSave.makeCoverPanel(ls._p, {
        x=0, y=dims.titleH, w=dims.w, h=contentH,
        bg={ r=TH.BG_R, g=TH.BG_G, b=TH.BG_B, a=1 }, border=false,
        hideTargets = {
            ls._detailPanel,
            ls._btnLoad  and ls._btnLoad.btn,
            ls._actBtns  and ls._actBtns.rename.btn,
            ls._actBtns  and ls._actBtns.clone.btn,
            ls._actBtns  and ls._actBtns.delete.btn,
        },
        update = function(_)
            local bat = ManualSave.SignalBus.isBatAlive()
            if bat ~= _prevBat then
                _prevBat = bat
                if ManualSave.UI and ManualSave.UI.evalConditions then
                    ManualSave.UI.evalConditions()
                end
            end
        end,
    })
    local cover = _coverObj.panel
    cover:bringToTop()

    local bannerH = 110
    local cy      = bannerH + TH.GAP

    ManualSave.makeSaveBanner(cover, { w=dims.w, h=bannerH, save=m, thumb=st.selectedThumb })

    local cols = ManualSave.makeTwoColumnLayout(cover, {
        x=TH.PAD, y=cy, w=dims.w - TH.PAD*2,
        h=contentH - cy - TH.PAD, splitRatio=0.44,
    })

    local y = 0
    y = y + ManualSave.makeSaveFileSection(cols.left,  { y=y, w=cols.leftW,  save=m })
    y = y + TH.GAP
    y = y + ManualSave.makeWorldStateSection(cols.left, { y=y, w=cols.leftW, save=m })
    y = y + TH.GAP
    local exp = ManualSave.makeMapModsLists(cols.left, { y=y, w=cols.leftW, save=m, mods=st.selectedMods })
    _mapExpand  = exp.mapExpand
    _modsExpand = exp.modsExpand

    local ry = 0
    ry = ry + ManualSave.makeSaveActions(cols.right,    { y=ry, w=cols.rightW, save=m, st=st })
    ry = ry + TH.GAP
    ManualSave.makeRecoveryFlags(cols.right, { y=ry, w=cols.rightW, save=m, st=st })

    ManualSave.UI.evalConditions()
    ls._btnMore.setLabel(getText("UI_MSM_Load_BtnListReturn"))
    ls._btnMore.btn.onclick = function(_) ManualSave.closeMoreScreen() end
end

function ManualSave.closeMoreScreen()
    if _mapExpand  then _mapExpand.close();  _mapExpand  = nil end
    if _modsExpand then _modsExpand.close(); _modsExpand = nil end

    local ls = ManualSave.LoadScreen
    if not _coverObj then return end
    _coverObj.destroy()
    _coverObj = nil

    if ls._btnMore then
        ls._btnMore.setLabel(getText("UI_MSM_Load_BtnMore"))
        ls._btnMore.btn.onclick = function(_) ManualSave.openMoreScreen() end
    end
end

print("[ManualSaveMod] UI/Screens/MoreScreen.lua loaded.")
