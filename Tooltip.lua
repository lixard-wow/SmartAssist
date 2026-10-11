local addonName, ns = ...

local LDB    = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

local C = {
    bg         = { 0.06, 0.06, 0.06, 0.97 },
    border     = { 0.22, 0.22, 0.22, 1.00 },
    header     = { 0.09, 0.09, 0.09, 1.00 },
    row        = { 0.08, 0.08, 0.08, 1.00 },
    rowHover   = { 0.14, 0.14, 0.14, 1.00 },
    clearRow   = { 0.11, 0.06, 0.06, 1.00 },
    clearHover = { 0.19, 0.07, 0.07, 1.00 },
    footer     = { 0.05, 0.05, 0.05, 1.00 },
    divider    = { 0.18, 0.18, 0.18, 1.00 },
    accentRed  = { 0.75, 0.25, 0.25, 1.00 },
    textPri    = { 0.92, 0.91, 0.86, 1.00 },
    textMuted  = { 0.62, 0.62, 0.62, 1.00 },
    textDim    = { 0.38, 0.38, 0.38, 1.00 },
    textRed    = { 0.85, 0.42, 0.42, 1.00 },
    gold       = { 0.78, 0.66, 0.22, 1.00 },
}

local POPUP_W  = 214
local HEADER_H = 38
local ROW_H    = 26
local FOOTER_H = 24
local MAX_ROWS = 7
local ACCENT_W = 3
local PAD_LEFT = 14

local function Bg(f, col, bord)
    bord = bord or col
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(col[1], col[2], col[3], col[4] or 1)
    f:SetBackdropBorderColor(bord[1], bord[2], bord[3], bord[4] or 1)
end

local function Solid(parent, col, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
    return t
end

local function GetTargetLabel() return ns.GetTargetLabel() end

local popup
local isPrompt      = false
local hideCancelled = false

local function ScheduleHide()
    if isPrompt then return end
    hideCancelled = false
    C_Timer.After(0.18, function()
        if not hideCancelled and popup then
            popup:Hide()
        end
    end)
end

local function CancelHide()
    hideCancelled = true
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_H)
    Bg(row, C.row, C.row)
    row:Hide()

    local bar = Solid(row, C.gold, "OVERLAY")
    bar:SetWidth(ACCENT_W)
    bar:SetPoint("TOPLEFT",    row, "TOPLEFT",    1, 0)
    bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 0)
    bar:Hide()

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", row, "LEFT", PAD_LEFT, 0)
    lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)

    local arr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arr:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    arr:SetText("|cff333333>|r")

    local btn = CreateFrame("Button", nil, row)
    btn:SetAllPoints()

    return { frame = row, bar = bar, lbl = lbl, arr = arr, btn = btn }
end

local rows = {}
local statusLbl
local headerIcon

local function BuildPopup()
    local f = CreateFrame("Frame", "SmartAssistPopup", UIParent, "BackdropTemplate")
    f:SetWidth(POPUP_W)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    Bg(f, C.bg, C.border)
    f:Hide()
    f:SetScript("OnEnter", CancelHide)
    f:SetScript("OnLeave", ScheduleHide)

    local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
    hdr:SetHeight(HEADER_H)
    hdr:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -1)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    Bg(hdr, C.header, C.header)

    local hdrLine = Solid(hdr, C.gold, "OVERLAY")
    hdrLine:SetHeight(1)
    hdrLine:SetPoint("BOTTOMLEFT",  hdr, "BOTTOMLEFT",  0, 0)
    hdrLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)

    local ico = hdr:CreateTexture(nil, "ARTWORK")
    ico:SetSize(20, 20)
    ico:SetPoint("LEFT", hdr, "LEFT", 10, 0)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    headerIcon = ico

    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", ico, "RIGHT", 8, 1)
    title:SetTextColor(C.gold[1], C.gold[2], C.gold[3], 1)
    title:SetText("SmartAssist")

    local sub = hdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("LEFT", ico, "RIGHT", 8, -10)
    sub:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3], 1)
    sub:SetText(ns.GetSpellName and ns.GetSpellName() or "")
    f.subLbl = sub

    local closeBtn = CreateFrame("Button", nil, hdr)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -6, 0)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeTxt:SetAllPoints()
    closeTxt:SetJustifyH("CENTER")
    closeTxt:SetTextColor(C.gold[1], C.gold[2], C.gold[3], 1)
    closeTxt:SetText("X")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    closeBtn:SetScript("OnEnter", function()
        CancelHide()
        closeTxt:SetTextColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        ScheduleHide()
        closeTxt:SetTextColor(C.gold[1], C.gold[2], C.gold[3], 1)
    end)

    for i = 1, MAX_ROWS do
        rows[i] = MakeRow(f)
    end

    local warnRow = CreateFrame("Frame", nil, f, "BackdropTemplate")
    warnRow:SetHeight(ROW_H)
    warnRow:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, 0)
    warnRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, 0)
    Bg(warnRow, { 0.14, 0.09, 0.02, 1 }, { 0.14, 0.09, 0.02, 1 })
    local warnTxt = warnRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warnTxt:SetPoint("LEFT", warnRow, "LEFT", PAD_LEFT, 0)
    warnTxt:SetTextColor(1.0, 0.65, 0.10, 1)
    warnRow:Hide()
    f.warnRow = warnRow
    f.warnTxt = warnTxt

    f.clearSep = Solid(f, C.divider, "ARTWORK")
    f.clearSep:SetHeight(1)
    f.clearSep:Hide()

    tinsert(UISpecialFrames, "SmartAssistPopup")

    f.footerDiv = Solid(f, C.divider, "ARTWORK")
    f.footerDiv:SetHeight(1)
    f.footerDiv:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  1, FOOTER_H + 1)
    f.footerDiv:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, FOOTER_H + 1)

    local ftr = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.footer = ftr
    ftr:SetHeight(FOOTER_H)
    ftr:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  1, 1)
    ftr:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    Bg(ftr, C.footer, C.footer)

    local statusPfx = ftr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusPfx:SetPoint("LEFT", ftr, "LEFT", PAD_LEFT, 0)
    statusPfx:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3], 1)
    statusPfx:SetText("Target:")

    statusLbl = ftr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusLbl:SetPoint("LEFT", statusPfx, "RIGHT", 5, 0)
    statusLbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3], 1)

    return f
end

local function ShowPopup(anchorFrame)
    if InCombatLockdown() then return end
    if not popup then popup = BuildPopup() end

    if headerIcon and ns.GetSpellIconID then
        headerIcon:SetTexture(ns.GetSpellIconID())
    end
    if popup.subLbl and ns.GetSpellName then
        popup.subLbl:SetText(ns.GetSpellName())
    end

    local actions = {}
    local inGroup = (GetNumGroupMembers() > 0) or (UnitInRaid("player") ~= nil)

    if inGroup and ns.class ~= "PRIEST" then
        local lbl = IsInRaid() and "Set to Raid Tank" or "Set to Party Tank"
        table.insert(actions, {
            label     = lbl,
            accentCol = C.gold,
            fn        = function()
                local tank = ns.FindTank and ns.FindTank()
                if tank then
                    ns.SetTarget(tank)
                    print("|cffC8A838SmartAssist|r: Target set to " .. tank)
                else
                    print("|cffC8A838SmartAssist|r: No tank found in group")
                end
            end,
        })
    end

    if ns.class == "PRIEST" then
        table.insert(actions, {
            label     = "Save Target's Name",
            accentCol = C.gold,
            fn        = function()
                local name = UnitIsPlayer("target") and GetUnitName("target", true)
                if name and not (issecretvalue and issecretvalue(name)) then
                    ns.SetTarget(name)
                    print("|cffC8A838SmartAssist|r: Target set to " .. name)
                else
                    print("|cffC8A838SmartAssist|r: Target a player first")
                end
            end,
        })
    end

    table.insert(actions, { label = "Set to Target",           fn = function() ns.SetTarget("target")       end })
    table.insert(actions, { label = "Set to Target of Target", fn = function() ns.SetTarget("targettarget") end })
    table.insert(actions, { label = "Set to Focus",            fn = function() ns.SetTarget("focus")        end })

    if ns.class == "HUNTER" and UnitExists("pet") then
        table.insert(actions, { label = "Set to Pet", fn = function() ns.SetTarget("pet") end })
    end

    table.insert(actions, {
        label     = "Clear Target",
        isClear   = true,
        accentCol = C.accentRed,
        fn        = function() ns.ClearTarget() end,
    })

    local spellAvail = ns.IsSpellAvailable and ns.IsSpellAvailable()

    if not spellAvail then
        popup.warnRow:ClearAllPoints()
        popup.warnRow:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -(1 + HEADER_H + 1 + 1))
        popup.warnRow:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -(1 + HEADER_H + 1 + 1))
        popup.warnTxt:SetText("Not talented into " .. (ns.GetSpellName and ns.GetSpellName() or "spell"))
        popup.warnRow:Show()

        for i = 1, MAX_ROWS do rows[i].frame:Hide() end
        popup.clearSep:Hide()
        popup.footerDiv:Hide()
        if popup.footer then popup.footer:Hide() end

        popup:SetHeight(1 + HEADER_H + 1 + 1 + ROW_H + 4)

        popup:ClearAllPoints()
        if anchorFrame then
            local x = anchorFrame:GetCenter()
            if x and x > (GetScreenWidth() / 2) then
                popup:SetPoint("RIGHT", anchorFrame, "LEFT", -6, 0)
            else
                popup:SetPoint("LEFT", anchorFrame, "RIGHT", 6, 0)
            end
        else
            popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end

        popup:Show()
        ns.tooltip = popup
        return
    end

    popup.warnRow:Hide()
    popup.footerDiv:Show()
    if popup.footer then popup.footer:Show() end

    local nRows  = #actions
    local totalH = 1 + HEADER_H + 1 + 1 + (nRows * ROW_H) + 1 + FOOTER_H + 1
    popup:SetHeight(totalH)

    local rowY = -(1 + HEADER_H + 1 + 1)

    for i = 1, MAX_ROWS do
        local row    = rows[i]
        local action = actions[i]

        if action then
            local isClear   = action.isClear
            local bgNorm    = isClear and C.clearRow   or C.row
            local bgHov     = isClear and C.clearHover or C.rowHover
            local lblCol    = isClear and C.textRed    or C.textMuted
            local lblHovCol = isClear and { 1, 0.5, 0.5, 1 } or C.textPri
            local accentCol = action.accentCol or C.gold

            if i > 1 and isClear then
                popup.clearSep:ClearAllPoints()
                popup.clearSep:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, rowY)
                popup.clearSep:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, rowY)
                popup.clearSep:Show()
                rowY   = rowY - 1
                totalH = totalH + 1
                popup:SetHeight(totalH)
            end

            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, rowY)
            row.frame:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, rowY)
            row.frame:SetBackdropColor(bgNorm[1], bgNorm[2], bgNorm[3], 1)
            row.frame:SetBackdropBorderColor(bgNorm[1], bgNorm[2], bgNorm[3], 1)

            row.bar:SetColorTexture(accentCol[1], accentCol[2], accentCol[3], 1)
            row.bar:Hide()

            row.lbl:SetText(action.label)
            row.lbl:SetTextColor(lblCol[1], lblCol[2], lblCol[3], 1)

            row.arr:SetText("|cff2a2a2a>|r")

            row.btn:SetScript("OnClick", action.fn)
            row.btn:SetScript("OnEnter", function()
                CancelHide()
                row.frame:SetBackdropColor(bgHov[1], bgHov[2], bgHov[3], 1)
                row.frame:SetBackdropBorderColor(bgHov[1], bgHov[2], bgHov[3], 1)
                row.lbl:SetTextColor(lblHovCol[1], lblHovCol[2], lblHovCol[3], 1)
                row.arr:SetText("|cff" ..
                    string.format("%02x%02x%02x",
                        accentCol[1] * 255,
                        accentCol[2] * 255,
                        accentCol[3] * 255) .. ">|r")
                row.bar:Show()
            end)
            row.btn:SetScript("OnLeave", function()
                ScheduleHide()
                row.frame:SetBackdropColor(bgNorm[1], bgNorm[2], bgNorm[3], 1)
                row.frame:SetBackdropBorderColor(bgNorm[1], bgNorm[2], bgNorm[3], 1)
                row.lbl:SetTextColor(lblCol[1], lblCol[2], lblCol[3], 1)
                row.arr:SetText("|cff2a2a2a>|r")
                row.bar:Hide()
            end)

            row.frame:Show()
            rowY = rowY - ROW_H
        else
            row.frame:Hide()
        end
    end

    if statusLbl then
        statusLbl:SetText(GetTargetLabel())
    end

    popup:ClearAllPoints()
    if anchorFrame then
        local x = anchorFrame:GetCenter()
        if x and x > (GetScreenWidth() / 2) then
            popup:SetPoint("RIGHT", anchorFrame, "LEFT", -6, 0)
        else
            popup:SetPoint("LEFT", anchorFrame, "RIGHT", 6, 0)
        end
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    popup:Show()
    ns.tooltip = popup
end

function ns.RefreshTooltipText()
    if ns.dataObj then
        ns.dataObj.text = GetTargetLabel()
    end
    if statusLbl then
        statusLbl:SetText(GetTargetLabel())
    end
end

function ns.ShowTargetPrompt()
    isPrompt = true
    ShowPopup(nil)
end

function ns.InitTooltip()
    local iconPath = ({
        ROGUE  = "Interface\\Icons\\Ability_Rogue_TricksOftheTrade",
        HUNTER = "Interface\\Icons\\Ability_Hunter_Misdirection",
        PRIEST = "Interface\\Icons\\Spell_Holy_PowerInfusion",
    })[ns.class]

    ns.dataObj = LDB:NewDataObject("SmartAssist", {
        type    = "data source",
        text    = GetTargetLabel(),
        icon    = iconPath,
        OnClick = function(_, btn)
            if btn == "RightButton" then
                if ns.ToggleConfig then ns.ToggleConfig() end
            end
        end,
        OnEnter = function(frame)
            isPrompt = false
            CancelHide()
            ShowPopup(frame)
        end,
        OnLeave = ScheduleHide,
    })

    DBIcon:Register("SmartAssist", ns.dataObj, SmartAssistDB.minimap)
end
