local addonName, ns = ...

local LDB    = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")
local Theme  = ns.Theme

local POPUP_W  = 224
local HEADER_H = 42
local ROW_H    = 24
local FOOTER_H = 28
local MAX_ROWS = 10
local ACCENT_W = 3
local INSET    = 8
local GAP      = 6

local popup
local isPrompt      = false
local hideCancelled = false

local function ScheduleHide()
    if isPrompt then return end
    hideCancelled = false
    C_Timer.After(0.18, function()
        if not hideCancelled and popup and not popup:IsMouseOver() then
            popup:Hide()
        end
    end)
end

local function CancelHide()
    hideCancelled = true
end

local function PaintRow(r)
    local C = Theme.C
    local action = r.action
    if not action then return end
    local lit = r.btn:IsMouseOver()
    local fillKey = action.isClear and "dangerFill" or "hover"
    Theme.Tint(r.fill, C[fillKey], (lit or action.isClear) and 1 or 0)
    local accent = C[action.accentKey or "accent"]
    r.accent:SetColorTexture(accent[1], accent[2], accent[3], 1)
    r.accent:SetShown(lit)
    if action.isClear then
        Theme.SetColor(r.lbl, "danger")
    else
        Theme.SetColor(r.lbl, lit and "text" or "muted")
    end
    r.arrow:SetText(lit and Theme.Code(action.accentKey or "accent") .. ">|r" or "")
end

local function MakeRow(parent)
    local r = {}
    r.btn = CreateFrame("Button", nil, parent)
    r.btn:SetHeight(ROW_H)
    r.btn:Hide()
    r.fill = Theme.Box(r.btn, "hover", "hover", "buttonRadius")
    r.btn.edge:Hide()

    r.accent = r.btn:CreateTexture(nil, "ARTWORK")
    r.accent:SetWidth(ACCENT_W)
    r.accent:SetPoint("TOPLEFT",    r.btn, "TOPLEFT",    0, -3)
    r.accent:SetPoint("BOTTOMLEFT", r.btn, "BOTTOMLEFT", 0, 3)
    r.accent:Hide()

    r.lbl = Theme.Text(r.btn, "body", 12, "muted")
    r.lbl:SetPoint("LEFT", r.btn, "LEFT", 10, 0)

    r.arrow = Theme.Text(r.btn, "strong", 12, "accent")
    r.arrow:SetPoint("RIGHT", r.btn, "RIGHT", -8, 0)

    r.btn:SetScript("OnEnter", function()
        CancelHide()
        PaintRow(r)
    end)
    r.btn:SetScript("OnLeave", function()
        PaintRow(r)
        ScheduleHide()
    end)
    r.btn:SetScript("OnClick", function()
        if r.action then r.action.fn() end
    end)

    Theme.Skin(function() PaintRow(r) end)
    return r
end

local rows = {}
local statusLbl
local headerIcon

local function BuildPopup()
    local f = CreateFrame("Frame", "SmartAssistPopup", UIParent)
    f:SetWidth(POPUP_W)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    f:SetScript("OnEnter", CancelHide)
    f:SetScript("OnLeave", ScheduleHide)
    f:SetScript("OnHide", function() isPrompt = false end)
    Theme.Window(f, HEADER_H)

    local ico = f:CreateTexture(nil, "ARTWORK")
    ico:SetSize(22, 22)
    ico:SetPoint("LEFT", f, "TOPLEFT", 12, -HEADER_H / 2)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    headerIcon = ico

    local title = Theme.Text(f, "title", nil, "title")
    title:SetPoint("BOTTOMLEFT", ico, "RIGHT", 8, 0)
    Theme.SetTitle(title, "SmartAssist")

    local sub = Theme.Text(f, "body", 11, "muted")
    sub:SetPoint("TOPLEFT", ico, "RIGHT", 8, -1)
    f.subLbl = sub

    local btnSize = HEADER_H - 18
    local closeBtn = Theme.IconButton(f, "icon_close", btnSize, function() f:Hide() end, "Close")
    closeBtn:SetPoint("RIGHT", f, "TOPRIGHT", -10, -HEADER_H / 2)
    closeBtn:HookScript("OnEnter", CancelHide)
    closeBtn:HookScript("OnLeave", ScheduleHide)

    local themeBtn = Theme.IconButton(f, "icon_gear", btnSize, function() Theme.Next() end,
        function() return "Theme: " .. Theme.T.name .. "\nClick for the next theme" end)
    themeBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    themeBtn:HookScript("OnEnter", CancelHide)
    themeBtn:HookScript("OnLeave", ScheduleHide)

    for i = 1, MAX_ROWS do
        rows[i] = MakeRow(f)
    end

    local warnRow = CreateFrame("Frame", nil, f)
    warnRow:SetHeight(ROW_H)
    warnRow:SetPoint("TOPLEFT",  f, "TOPLEFT",  INSET, -(HEADER_H + GAP))
    warnRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -INSET, -(HEADER_H + GAP))
    Theme.Box(warnRow, "warnFill", "warnFill", "buttonRadius")
    local warnTxt = Theme.Text(warnRow, "strong", 12, "warn")
    warnTxt:SetPoint("LEFT", warnRow, "LEFT", 10, 0)
    warnRow:Hide()
    f.warnRow = warnRow
    f.warnTxt = warnTxt

    f.clearSep = f:CreateTexture(nil, "ARTWORK")
    f.clearSep:SetHeight(1)
    f.clearSep:Hide()
    Theme.Skin(function(_, C) f.clearSep:SetColorTexture(C.line[1], C.line[2], C.line[3], 1) end)

    local footDiv = f:CreateTexture(nil, "ARTWORK")
    footDiv:SetHeight(1)
    footDiv:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  INSET, FOOTER_H)
    footDiv:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -INSET, FOOTER_H)
    Theme.Skin(function(_, C) footDiv:SetColorTexture(C.line[1], C.line[2], C.line[3], 1) end)
    f.footerDiv = footDiv

    local statusPfx = Theme.Text(f, "heading", nil, "muted")
    statusPfx:SetPoint("LEFT", f, "BOTTOMLEFT", INSET + 4, FOOTER_H / 2)
    statusPfx:SetText("Target:")
    f.statusPfx = statusPfx

    statusLbl = Theme.Text(f, "strong", 12, "accent")
    statusLbl:SetPoint("LEFT", statusPfx, "RIGHT", 5, 0)

    tinsert(UISpecialFrames, "SmartAssistPopup")
    return f
end

local function Anchor(anchorFrame)
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
            label = lbl,
            fn    = function()
                local tank = ns.FindTank and ns.FindTank()
                if tank then
                    ns.SetTarget(tank)
                    ns.Notify("Target set to " .. tank)
                else
                    ns.Notify("No tank found in group")
                end
            end,
        })
    end

    if ns.class == "PRIEST" then
        for _, name in ipairs(ns.GetGroupDamagers()) do
            table.insert(actions, {
                label = "Set to " .. name,
                fn    = function()
                    ns.SetTarget(name)
                    ns.Notify("Target set to " .. name)
                end,
            })
        end
        table.insert(actions, { label = "Save Target's Name", fn = ns.SaveTargetName })
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
        accentKey = "danger",
        fn        = function() ns.ClearTarget() end,
    })

    local spellAvail = ns.IsSpellAvailable and ns.IsSpellAvailable()

    if not spellAvail then
        popup.warnTxt:SetText("Not talented into " .. (ns.GetSpellName and ns.GetSpellName() or "spell"))
        popup.warnRow:Show()
        for i = 1, MAX_ROWS do
            rows[i].action = nil
            rows[i].btn:Hide()
        end
        popup.clearSep:Hide()
        popup.footerDiv:Hide()
        popup.statusPfx:Hide()
        statusLbl:Hide()
        popup:SetHeight(HEADER_H + GAP + ROW_H + GAP + 2)
        Anchor(anchorFrame)
        popup:Show()
        ns.tooltip = popup
        return
    end

    popup.warnRow:Hide()
    popup.footerDiv:Show()
    popup.statusPfx:Show()
    statusLbl:Show()
    popup.clearSep:Hide()

    local rowY = -(HEADER_H + GAP)

    for i = 1, MAX_ROWS do
        local r      = rows[i]
        local action = actions[i]
        r.action = action

        if action then
            if i > 1 and action.isClear then
                rowY = rowY - GAP / 2
                popup.clearSep:ClearAllPoints()
                popup.clearSep:SetPoint("TOPLEFT",  popup, "TOPLEFT",  INSET, rowY)
                popup.clearSep:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -INSET, rowY)
                popup.clearSep:Show()
                rowY = rowY - 1 - GAP / 2
            end

            r.btn:ClearAllPoints()
            r.btn:SetPoint("TOPLEFT",  popup, "TOPLEFT",  INSET, rowY)
            r.btn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -INSET, rowY)
            r.lbl:SetText(action.label)
            r.btn:Show()
            PaintRow(r)
            rowY = rowY - ROW_H
        else
            r.btn:Hide()
        end
    end

    popup:SetHeight(-rowY + GAP + 1 + FOOTER_H)
    statusLbl:SetText(ns.GetTargetLabel())

    Anchor(anchorFrame)
    popup:Show()
    ns.tooltip = popup
end

function ns.RefreshTooltipText()
    if ns.dataObj then
        ns.dataObj.text = ns.GetTargetLabel()
    end
    if statusLbl then
        statusLbl:SetText(ns.GetTargetLabel())
    end
end

function ns.ShowTargetPrompt()
    isPrompt = true
    ShowPopup(nil)
end

function ns.InitTooltip()
    Theme.Load()

    local iconPath = ({
        ROGUE  = "Interface\\Icons\\Ability_Rogue_TricksOftheTrade",
        HUNTER = "Interface\\Icons\\Ability_Hunter_Misdirection",
        PRIEST = "Interface\\Icons\\Spell_Holy_PowerInfusion",
    })[ns.class]

    ns.dataObj = LDB:NewDataObject("SmartAssist", {
        type    = "data source",
        text    = ns.GetTargetLabel(),
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
