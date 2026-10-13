local addonName, ns = ...

local Theme = ns.Theme

local configFrame
local macroNameBox
local targetDisplay
local locationDisplay
local dragButton
local toggles = {}

function ns.CreateMacroDragButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("LeftButtonUp")
    Theme.Box(b, "well", "accent", "buttonRadius")
    local ico = b:CreateTexture(nil, "ARTWORK")
    ico:SetPoint("TOPLEFT", 3, -3)
    ico:SetPoint("BOTTOMRIGHT", -3, 3)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(ico)
    hl:SetColorTexture(1, 1, 1, 0.15)

    local function Pick()
        if InCombatLockdown() then return end
        local idx = ns.FindMacro(ns.GetMacroName(), SmartAssistDB.perCharacter)
        if idx == 0 then
            ns.WriteMacro()
            idx = ns.FindMacro(ns.GetMacroName(), SmartAssistDB.perCharacter)
        end
        if idx ~= 0 then PickupMacro(idx) end
    end
    b:SetScript("OnDragStart", Pick)
    b:SetScript("OnClick", Pick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.GetMacroName(), 1, 1, 1)
        GameTooltip:AddLine("Drag onto an action bar slot.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function b.Refresh()
        ico:SetTexture(ns.IsSpellAvailable() and ns.GetSpellIconID() or 134400)
    end
    b.Refresh()
    return b
end

function ns.SetMinimapShown(v)
    SmartAssistDB.minimap.hide = not v
    local dbi = LibStub and LibStub("LibDBIcon-1.0", true)
    if dbi then
        if v then dbi:Show("SmartAssist") else dbi:Hide("SmartAssist") end
    end
end

local FRAME_W  = 360
local HEADER_H = 42
local PAD      = 14
local CHECK_W  = 16
local ROW_H    = 24
local FIELD_H  = 26

local function AddSection(parent, text, y)
    local lbl = Theme.Text(parent, "heading", nil, "heading")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    lbl:SetText(text)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD, y - 18)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, y - 18)
    Theme.Skin(function(_, C) line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1) end)
end

local function CreateToggle(parent, labelText, getter, setter)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    local cb = Theme.Check(row, CHECK_W, function(self) setter(self:GetChecked()) end)
    cb:SetPoint("LEFT", row, "LEFT", 2, 0)
    cb:SetChecked(getter())

    local lbl = Theme.Text(row, "body", 12, "muted")
    lbl:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    lbl:SetText(labelText)

    row:SetScript("OnClick", function() cb:Click() end)
    row:SetScript("OnEnter", function() Theme.SetColor(lbl, "text") end)
    row:SetScript("OnLeave", function() Theme.SetColor(lbl, "muted") end)
    cb:HookScript("OnEnter", function() Theme.SetColor(lbl, "text") end)
    cb:HookScript("OnLeave", function() Theme.SetColor(lbl, "muted") end)

    row.Refresh = function() cb:SetChecked(getter()) end
    return row
end

local function TextButton(parent, text, width, onClick)
    return Theme.TextButton(parent, text, width, FIELD_H, onClick)
end

local function BuildConfigFrame()
    local f = CreateFrame("Frame", "SmartAssistConfigFrame", UIParent)
    f:SetWidth(FRAME_W)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:Hide()
    Theme.Window(f, HEADER_H)
    tinsert(UISpecialFrames, "SmartAssistConfigFrame")

    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -70, 0)
    drag:SetHeight(HEADER_H)
    drag:EnableMouse(true)
    drag:SetScript("OnMouseDown", function() f:StartMoving() end)
    drag:SetScript("OnMouseUp",   function() f:StopMovingOrSizing() end)

    local ico = f:CreateTexture(nil, "ARTWORK")
    ico:SetSize(22, 22)
    ico:SetPoint("LEFT", f, "TOPLEFT", 12, -HEADER_H / 2)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ico:SetTexture(ns.GetSpellIconID and ns.GetSpellIconID())
    f.icon = ico

    local title = Theme.Text(f, "title", nil, "title")
    title:SetPoint("BOTTOMLEFT", ico, "RIGHT", 8, 0)
    Theme.SetTitle(title, "SmartAssist")

    local sub = Theme.Text(f, "body", 11, "muted")
    sub:SetPoint("TOPLEFT", ico, "RIGHT", 8, -1)
    sub:SetText(ns.GetSpellName and ns.GetSpellName() or "")
    f.subLbl = sub

    local btnSize = HEADER_H - 18
    local closeBtn = Theme.IconButton(f, "icon_close", btnSize, function() f:Hide() end, "Close")
    closeBtn:SetPoint("RIGHT", f, "TOPRIGHT", -10, -HEADER_H / 2)

    local themeBtn = Theme.IconButton(f, "icon_gear", btnSize, function() Theme.Next() end,
        function() return "Theme: " .. Theme.T.name .. "\nClick for the next theme" end)
    themeBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)

    local y = -(HEADER_H + 14)

    AddSection(f, "MACRO", y)
    y = y - 32

    local nameLbl = Theme.Text(f, "body", 12, "muted")
    nameLbl:SetPoint("LEFT", f, "TOPLEFT", PAD, y - FIELD_H / 2)
    nameLbl:SetText("Name:")

    local inputBg = CreateFrame("Frame", nil, f)
    inputBg:SetSize(170, FIELD_H)
    inputBg:SetPoint("LEFT", nameLbl, "RIGHT", 8, 0)
    local _, inputEdge = Theme.Box(inputBg, "field", "border", "buttonRadius")

    macroNameBox = CreateFrame("EditBox", nil, inputBg)
    macroNameBox:SetPoint("TOPLEFT", inputBg, "TOPLEFT", 4, -2)
    macroNameBox:SetPoint("BOTTOMRIGHT", inputBg, "BOTTOMRIGHT", -4, 2)
    macroNameBox:SetAutoFocus(false)
    macroNameBox:SetMaxLetters(32)
    macroNameBox:SetTextInsets(4, 4, 0, 0)
    Theme.Skin(function(T, C)
        Theme.SetFont(macroNameBox, T.fonts.body, 12)
        macroNameBox:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        Theme.Tint(inputEdge, macroNameBox:HasFocus() and C.accent or C.border)
    end)

    local function ApplyMacroName()
        if InCombatLockdown() then
            macroNameBox:SetText(SmartAssistDB.macroName or "")
            macroNameBox:ClearFocus()
            return
        end
        local val = macroNameBox:GetText():match("^%s*(.-)%s*$")
        if val and val ~= "" then
            local oldIdx = ns.FindMacro(SmartAssistDB.macroName or "", SmartAssistDB.perCharacter)
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
    macroNameBox:SetScript("OnEditFocusGained", function() Theme.Tint(inputEdge, Theme.C.accent) end)
    macroNameBox:SetScript("OnEditFocusLost", function() Theme.Tint(inputEdge, Theme.C.border) end)

    local applyBtn = TextButton(f, "Apply", 60, ApplyMacroName)
    applyBtn:SetPoint("LEFT", inputBg, "RIGHT", 6, 0)

    y = y - FIELD_H - 10

    local tgtLbl = Theme.Text(f, "body", 12, "muted")
    tgtLbl:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    tgtLbl:SetText("Current target:")

    targetDisplay = Theme.Text(f, "strong", 12, "accent")
    targetDisplay:SetPoint("LEFT", tgtLbl, "RIGHT", 6, 0)

    y = y - 24

    local locLbl = Theme.Text(f, "body", 12, "muted")
    locLbl:SetPoint("LEFT", f, "TOPLEFT", PAD, y - FIELD_H / 2)
    locLbl:SetText("Saved in:")

    locationDisplay = Theme.Text(f, "strong", 12, "text")
    locationDisplay:SetPoint("LEFT", locLbl, "RIGHT", 6, 0)

    local switchBtn = TextButton(f, "Switch", 60, function()
        ns.SetMacroLocation(not SmartAssistDB.perCharacter)
    end)
    switchBtn:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, y - FIELD_H / 2)

    y = y - FIELD_H - 10

    dragButton = ns.CreateMacroDragButton(f, 36)
    dragButton:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)

    local dragTitle = Theme.Text(f, "strong", 12, "text")
    dragTitle:SetPoint("TOPLEFT", dragButton, "TOPRIGHT", 10, -3)
    dragTitle:SetText("Drag onto your action bar")
    local dragSub = Theme.Text(f, "body", 11, "muted")
    dragSub:SetPoint("TOPLEFT", dragTitle, "BOTTOMLEFT", 0, -3)
    dragSub:SetText("Or click it, then click a bar slot.")

    y = y - 36 - 14

    if ns.class ~= "PRIEST" then
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
        y = y - ROW_H

        if ns.class == "HUNTER" then
            local petToggle = CreateToggle(f,
                "Auto-set pet when leaving group",
                function() return SmartAssistDB.autopet end,
                function(v) SmartAssistDB.autopet = v end
            )
            petToggle:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
            petToggle:SetWidth(FRAME_W - PAD * 2)
            table.insert(toggles, petToggle)
            y = y - ROW_H
        end

        y = y - 14
    end

    AddSection(f, "MINIMAP", y)
    y = y - 28

    local minimapToggle = CreateToggle(f,
        "Show minimap button",
        function() return not SmartAssistDB.minimap.hide end,
        ns.SetMinimapShown
    )
    minimapToggle:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    minimapToggle:SetWidth(FRAME_W - PAD * 2)
    table.insert(toggles, minimapToggle)
    y = y - ROW_H - 14

    AddSection(f, "HELP", y)
    y = y - 32

    local guideBtn = TextButton(f, "Open setup guide", 130, function()
        f:Hide()
        if ns.ShowWizard then ns.ShowWizard() end
    end)
    guideBtn:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    y = y - FIELD_H - PAD

    f:SetHeight(-y)
    return f
end

function ns.RefreshConfigDisplay()
    if not configFrame or not configFrame:IsShown() then return end

    if macroNameBox and not macroNameBox:HasFocus() then
        macroNameBox:SetText(SmartAssistDB.macroName or "")
    end

    if targetDisplay then
        targetDisplay:SetText(ns.GetTargetLabel())
    end

    if locationDisplay then
        locationDisplay:SetText(ns.MacroTabName())
    end

    if dragButton then dragButton.Refresh() end

    if configFrame.icon and ns.GetSpellIconID then
        configFrame.icon:SetTexture(ns.GetSpellIconID())
    end

    for _, tog in ipairs(toggles) do
        tog.Refresh()
    end
end

ns.RefreshUI = function()
    ns.RefreshConfigDisplay()
    if ns.RefreshWizard then ns.RefreshWizard() end
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
