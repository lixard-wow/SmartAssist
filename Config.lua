local addonName, ns = ...

local C = {
    bg         = { 0.06, 0.06, 0.06, 0.98 },
    titleBar   = { 0.08, 0.08, 0.08, 1.00 },
    border     = { 0.22, 0.22, 0.22, 1.00 },
    divider    = { 0.28, 0.28, 0.28, 1.00 },
    gold       = { 0.78, 0.66, 0.22, 1.00 },
    textPri    = { 0.92, 0.91, 0.86, 1.00 },
    textMuted  = { 0.70, 0.70, 0.70, 1.00 },
    fieldBg    = { 0.10, 0.10, 0.10, 1.00 },
    fieldBord  = { 0.30, 0.30, 0.30, 1.00 },
    closeNorm  = { 0.15, 0.15, 0.15, 1.00 },
    closeHover = { 0.50, 0.10, 0.10, 1.00 },
    closeBord  = { 0.30, 0.30, 0.30, 1.00 },
    closeHBord = { 0.80, 0.20, 0.20, 1.00 },
}

local function UC(c) return c[1], c[2], c[3], c[4] or 1 end

local function ApplyBackdrop(frame, bg, bord)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(bord[1], bord[2], bord[3], bord[4] or 1)
end

local function AddSection(parent, text, yOff)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOff)
    lbl:SetTextColor(UC(C.gold))
    lbl:SetText(text)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  12, yOff - 16)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOff - 16)
    line:SetColorTexture(C.divider[1], C.divider[2], C.divider[3], 1)
end

local function CreateToggle(parent, labelText, getter, setter)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(20)

    local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(14, 14)
    box:SetPoint("LEFT", row, "LEFT", 0, 0)
    ApplyBackdrop(box, C.fieldBg, C.fieldBord)

    local fill = box:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("TOPLEFT",     box, "TOPLEFT",     2, -2)
    fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2,  2)
    fill:SetColorTexture(UC(C.gold))
    fill:SetShown(getter())

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
    lbl:SetText(labelText)
    lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)

    local btn = CreateFrame("Button", nil, row)
    btn:SetAllPoints(row)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function()
        local v = not getter()
        setter(v)
        fill:SetShown(v)
    end)
    btn:SetScript("OnEnter", function()
        lbl:SetTextColor(C.textPri[1], C.textPri[2], C.textPri[3], 1)
    end)
    btn:SetScript("OnLeave", function()
        lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
    end)

    row.Refresh = function() fill:SetShown(getter()) end

    return row
end

local configFrame
local macroNameBox
local targetDisplay
local toggles = {}

local FRAME_W = 360
local FRAME_H = 306
local PAD     = 12

local function BuildConfigFrame()
    local f = CreateFrame("Frame", "SmartAssistConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    ApplyBackdrop(f, C.bg, C.border)
    f:Hide()

    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    ApplyBackdrop(titleBar, C.titleBar, C.border)
    titleBar:SetScript("OnMouseDown", function() f:StartMoving()        end)
    titleBar:SetScript("OnMouseUp",   function() f:StopMovingOrSizing() end)

    local titleTxt = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleTxt:SetPoint("LEFT", titleBar, "LEFT", PAD, 0)
    titleTxt:SetText("SmartAssist")
    titleTxt:SetTextColor(UC(C.gold))

    local closeBox = CreateFrame("Frame", nil, titleBar, "BackdropTemplate")
    closeBox:SetSize(24, 24)
    closeBox:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    ApplyBackdrop(closeBox, C.closeNorm, C.closeBord)

    local closeX = closeBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeX:SetAllPoints()
    closeX:SetText("X")
    closeX:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)

    local closeBtn = CreateFrame("Button", nil, closeBox)
    closeBtn:SetAllPoints()
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    closeBtn:SetScript("OnEnter", function()
        closeBox:SetBackdropColor(C.closeHover[1], C.closeHover[2], C.closeHover[3], 1)
        closeBox:SetBackdropBorderColor(C.closeHBord[1], C.closeHBord[2], C.closeHBord[3], 1)
        closeX:SetTextColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeBox:SetBackdropColor(C.closeNorm[1], C.closeNorm[2], C.closeNorm[3], 1)
        closeBox:SetBackdropBorderColor(C.closeBord[1], C.closeBord[2], C.closeBord[3], 1)
        closeX:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
    end)

    local y = -48

    AddSection(f, "MACRO", y)
    y = y - 26

    local nameLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLbl:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    nameLbl:SetText("Name:")
    nameLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)

    local inputBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    inputBg:SetSize(150, 24)
    inputBg:SetPoint("LEFT", nameLbl, "RIGHT", 8, 0)
    ApplyBackdrop(inputBg, C.fieldBg, C.fieldBord)

    macroNameBox = CreateFrame("EditBox", nil, inputBg)
    macroNameBox:SetSize(142, 20)
    macroNameBox:SetPoint("CENTER", inputBg, "CENTER", 0, 0)
    macroNameBox:SetAutoFocus(false)
    macroNameBox:SetMaxLetters(32)
    macroNameBox:SetFontObject(GameFontHighlightSmall)
    macroNameBox:SetTextColor(C.textPri[1], C.textPri[2], C.textPri[3], 1)
    macroNameBox:SetTextInsets(4, 4, 0, 0)

    local function ApplyMacroName()
        if InCombatLockdown() then
            macroNameBox:SetText(SmartAssistDB.macroName or "")
            macroNameBox:ClearFocus()
            return
        end
        local val = macroNameBox:GetText():match("^%s*(.-)%s*$")
        if val and val ~= "" then
            local oldIdx = GetMacroIndexByName(SmartAssistDB.macroName or "")
            SmartAssistDB.macroName = val
            if oldIdx and oldIdx ~= 0 then
                EditMacro(oldIdx, val, nil, nil)
            end
            ns.WriteMacro()
        else
            macroNameBox:SetText(SmartAssistDB.macroName or "")
        end
        macroNameBox:ClearFocus()
    end

    macroNameBox:SetScript("OnEscapePressed", function(self)
        self:SetText(SmartAssistDB.macroName or "")
        self:ClearFocus()
    end)
    macroNameBox:SetScript("OnEnterPressed", ApplyMacroName)
    macroNameBox:SetScript("OnEditFocusGained", function()
        inputBg:SetBackdropBorderColor(UC(C.gold))
    end)
    macroNameBox:SetScript("OnEditFocusLost", function()
        inputBg:SetBackdropBorderColor(C.fieldBord[1], C.fieldBord[2], C.fieldBord[3], 1)
    end)

    local applyBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    applyBox:SetSize(46, 24)
    applyBox:SetPoint("LEFT", inputBg, "RIGHT", 6, 0)
    ApplyBackdrop(applyBox, C.fieldBg, C.fieldBord)

    local applyTxt = applyBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    applyTxt:SetAllPoints()
    applyTxt:SetText("Apply")
    applyTxt:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)

    local applyBtn = CreateFrame("Button", nil, applyBox)
    applyBtn:SetAllPoints()
    applyBtn:SetScript("OnClick", ApplyMacroName)
    applyBtn:SetScript("OnEnter", function()
        applyBox:SetBackdropBorderColor(UC(C.gold))
        applyTxt:SetTextColor(UC(C.gold))
    end)
    applyBtn:SetScript("OnLeave", function()
        applyBox:SetBackdropBorderColor(C.fieldBord[1], C.fieldBord[2], C.fieldBord[3], 1)
        applyTxt:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
    end)

    y = y - 32

    local tgtLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tgtLbl:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    tgtLbl:SetText("Current target:")
    tgtLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)

    targetDisplay = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetDisplay:SetPoint("LEFT", tgtLbl, "RIGHT", 6, 0)
    targetDisplay:SetTextColor(C.textPri[1], C.textPri[2], C.textPri[3], 1)

    y = y - 38

    if ns.class == "PRIEST" then
        f:SetHeight(FRAME_H - 54)
    else
        AddSection(f, "AUTOMATION", y)
        y = y - 28

        local tankToggle = CreateToggle(f,
            "Auto-set tank when joining group",
            function() return SmartAssistDB.autotank end,
            function(v) SmartAssistDB.autotank = v end
        )
        tankToggle:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        tankToggle:SetWidth(FRAME_W - PAD * 2)
        table.insert(toggles, tankToggle)
        y = y - 26
    end

    if ns.class == "HUNTER" then
        local petToggle = CreateToggle(f,
            "Auto-set pet when leaving group",
            function() return SmartAssistDB.autopet end,
            function(v) SmartAssistDB.autopet = v end
        )
        petToggle:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        petToggle:SetWidth(FRAME_W - PAD * 2)
        table.insert(toggles, petToggle)
        y = y - 26
    end

    y = y - 12

    AddSection(f, "MINIMAP", y)
    y = y - 28

    local minimapToggle = CreateToggle(f,
        "Show minimap button",
        function() return not SmartAssistDB.minimap.hide end,
        function(v)
            SmartAssistDB.minimap.hide = not v
            local dbi = LibStub and LibStub("LibDBIcon-1.0", true)
            if dbi then
                if v then dbi:Show("SmartAssist") else dbi:Hide("SmartAssist") end
            end
        end
    )
    minimapToggle:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    minimapToggle:SetWidth(FRAME_W - PAD * 2)
    table.insert(toggles, minimapToggle)

    return f
end

function ns.RefreshConfigDisplay()
    if not configFrame or not configFrame:IsShown() then return end

    if macroNameBox then
        macroNameBox:SetText(SmartAssistDB.macroName or "")
    end

    if targetDisplay then
        targetDisplay:SetText(ns.GetTargetLabel())
    end

    for _, tog in ipairs(toggles) do
        tog.Refresh()
    end
end

function ns.InitConfig()
    configFrame = BuildConfigFrame()
end

function ns.ToggleConfig()
    if not configFrame then return end
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        if macroNameBox then
            macroNameBox:SetText(SmartAssistDB.macroName or "")
        end
        configFrame:Show()
        ns.RefreshConfigDisplay()
    end
end
