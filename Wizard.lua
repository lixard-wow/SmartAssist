local addonName, ns = ...

local Theme = ns.Theme

local W        = 460
local H        = 500
local HEADER_H = 42
local FOOTER_H = 52
local PAD      = 20
local CONTENT  = W - PAD * 2
local FIELD_H  = 26

local wizard
local pages     = {}
local refresh   = {}
local current   = 1
local backBtn, nextBtn, stepLbl

local function Paragraph(page, prev, gap, text, role, size, colorKey)
    local fs = Theme.Text(page, role or "body", size or 12, colorKey or "text")
    fs:SetWordWrap(true)
    fs:SetJustifyV("TOP")
    fs:SetWidth(CONTENT)
    fs:SetSpacing(2)
    if prev then
        fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -(gap or 8))
    else
        fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    end
    fs:SetText(text)
    return fs
end

local function Heading(page, prev, gap, text)
    return Paragraph(page, prev, gap, text, "heading", 15, "heading")
end

local function Label(page, prev, gap, text)
    return Paragraph(page, prev, gap, text, "heading", 12, "muted")
end

local function TextButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, FIELD_H)
    local fill, edge = Theme.Box(b, "button", "buttonBorder", "buttonRadius")
    local lbl = Theme.Text(b, "button", 12, "buttonText")
    lbl:SetPoint("CENTER")
    lbl:SetJustifyH("CENTER")
    lbl:SetText(text)
    b.label = lbl
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function()
        Theme.Tint(fill, Theme.C.buttonHover)
        Theme.Tint(edge, Theme.C.accent)
    end)
    b:SetScript("OnLeave", function()
        Theme.Tint(fill, Theme.C.button)
        Theme.Tint(edge, Theme.C.buttonBorder)
    end)
    return b
end

local function Choice(page, prev, gap, label, desc, isOn, onPick)
    local row = CreateFrame("Button", nil, page)
    row:SetSize(CONTENT, desc and 36 or 22)
    row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -(gap or 6))

    local cb = Theme.Check(row, 16, function(self)
        onPick(self:GetChecked())
        if ns.RefreshWizard then ns.RefreshWizard() end
    end)
    cb:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -3)

    local lbl = Theme.Text(row, "strong", 12, "text")
    lbl:SetPoint("TOPLEFT", cb, "TOPRIGHT", 10, 0)
    lbl:SetText(label)
    row.label = lbl

    local d
    if desc then
        d = Theme.Text(row, "body", 11, "muted")
        d:SetWordWrap(true)
        d:SetJustifyV("TOP")
        d:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -3)
        d:SetWidth(CONTENT - 30)
        d:SetText(desc)
    end

    row:SetScript("OnClick", function() cb:Click() end)
    refresh[#refresh + 1] = function()
        cb:SetChecked(isOn())
        if d then row:SetHeight(math.ceil(lbl:GetStringHeight() + d:GetStringHeight()) + 8) end
    end
    return row
end

local function Radio(page, prev, gap, label, desc, getter, value, setter)
    return Choice(page, prev, gap, label, desc,
        function() return getter() == value end,
        function() setter(value) end)
end

local function Toggle(page, prev, gap, label, desc, getter, setter)
    return Choice(page, prev, gap, label, desc, getter, function(v) setter(v) end)
end

local function NewPage()
    local p = CreateFrame("Frame", nil, wizard)
    p:SetPoint("TOPLEFT", wizard, "TOPLEFT", PAD, -(HEADER_H + 18))
    p:SetPoint("BOTTOMRIGHT", wizard, "BOTTOMRIGHT", -PAD, FOOTER_H)
    p:Hide()
    pages[#pages + 1] = p
    return p
end

local function Spell()
    return ns.GetSpellName()
end

local function PlayerName()
    return UnitName("player") or "this character"
end

local function BuildWelcome()
    local p = NewPage()
    local spell = Spell()
    local h = Heading(p, nil, 0, "Welcome to SmartAssist")

    local who
    if ns.class == "HUNTER" then
        who = "your tank in a group, your pet when you're solo, or your focus or target"
    elseif ns.class == "ROGUE" then
        who = "your tank, your focus or your target"
    else
        who = "a player you've saved by name, your focus or your target"
    end

    local a = Paragraph(p, h, 12, "SmartAssist makes one " .. spell .. " macro for "
        .. PlayerName() .. " and keeps it up to date. Press it and " .. spell .. " goes to " .. who .. ".")

    local b = Paragraph(p, a, 10, "You never edit the macro yourself. When you change who it's aimed at, SmartAssist rewrites it for you, and your action bar button keeps working.")

    local c
    if ns.class == "HUNTER" then
        c = Paragraph(p, b, 10, "When you join a group it can find the tank by itself, and when you leave it can switch back to your pet. If the player you picked isn't around, the macro uses your pet, then your target.")
    elseif ns.class == "ROGUE" then
        c = Paragraph(p, b, 10, "When you join a group it can find the tank by itself. If the player you picked isn't around, the macro uses your target.")
    else
        c = Paragraph(p, b, 10, "Power Infusion goes on a damage dealer, so SmartAssist doesn't pick the tank for you. To save a player, target them, hover the minimap button and choose Save Target's Name. If the player you picked isn't around, the macro uses your target.")
    end

    Paragraph(p, c, 16, "This guide takes about a minute. It shows once for each " .. (ns.class == "HUNTER" and "Hunter" or ns.class == "ROGUE" and "Rogue" or "Priest")
        .. ", and you can open it again any time with /smartassist setup.", "body", 11, "muted")
end

local function BuildBehaviour()
    local p = NewPage()
    local db = function() return SmartAssistDB end
    local getTarget = function() return db().target end

    local h = Heading(p, nil, 0, "How should it behave?")
    local l = Label(p, h, 14, "AIM " .. Spell():upper() .. " AT")

    local last
    if ns.class == "HUNTER" then
        last = Radio(p, l, 8, "Your pet", "Best when you play solo.", getTarget, "pet", ns.SetTarget)
        last = Radio(p, last, 4, "Your focus", "Whoever you've set as your focus.", getTarget, "focus", ns.SetTarget)
        last = Radio(p, last, 4, "Your target", "Whoever you have targeted when you press it.", getTarget, "target", ns.SetTarget)
    else
        last = Radio(p, l, 8, "Your focus", "Whoever you've set as your focus.", getTarget, "focus", ns.SetTarget)
        last = Radio(p, last, 4, "Your target", "Whoever you have targeted when you press it.", getTarget, "target", ns.SetTarget)
        last = Radio(p, last, 4, "Your target's target", "Handy when you target the boss and the tank is holding it.", getTarget, "targettarget", ns.SetTarget)
    end

    local now = Theme.Text(p, "body", 11, "muted")
    now:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 30, -4)
    refresh[#refresh + 1] = function() now:SetText("Right now: " .. ns.GetTargetLabel()) end
    local anchor = CreateFrame("Frame", nil, p)
    anchor:SetSize(1, 1)
    anchor:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -16)

    local l2 = Label(p, anchor, 10, "AUTOMATIC")
    last = l2
    if ns.class ~= "PRIEST" then
        last = Toggle(p, last, 8, "Find the tank when I join a group",
            "Aims the macro at the group's tank as soon as you join.",
            function() return db().autotank end,
            function(v) db().autotank = v end)
        if ns.class == "HUNTER" then
            last = Toggle(p, last, 4, "Switch back to my pet when I leave",
                "Aims the macro at your pet again once the group ends.",
                function() return db().autopet end,
                function(v) db().autopet = v end)
        end
    end
    Toggle(p, last, 4, "Show the minimap button",
        "Hover it for the quick menu, right-click it for settings. Without it, type /smartassist.",
        function() return not db().minimap.hide end,
        ns.SetMinimapShown)
end

local function BuildMacro()
    local p = NewPage()
    local h = Heading(p, nil, 0, "Your macro")

    local nameLine = Paragraph(p, h, 12, "")
    refresh[#refresh + 1] = function()
        nameLine:SetText("Your macro is called " .. Theme.Code("accent") .. ns.GetMacroName()
            .. "|r. You can rename it later in the settings.")
    end

    local l = Label(p, nameLine, 16, "WHERE SHOULD IT BE SAVED?")
    local getPer = function() return SmartAssistDB.perCharacter and true or false end
    local first = Radio(p, l, 8, ns.MacroTabName(true),
        "Only " .. PlayerName() .. " sees it. Recommended, because each character aims it at its own pet, focus or tank.",
        getPer, true, ns.SetMacroLocation)
    local second = Radio(p, first, 8, ns.MacroTabName(false),
        "Shared by every character on your account. Uses one of your general macro slots.",
        getPer, false, ns.SetMacroLocation)

    local l2 = Label(p, second, 16, "WHAT'S INSIDE")
    local well = CreateFrame("Frame", nil, p)
    well:SetSize(CONTENT, 54)
    well:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -8)
    Theme.Box(well, "well", "border", "buttonRadius")
    local body = Theme.Text(well, "body", 11, "text")
    body:SetWordWrap(true)
    body:SetJustifyV("TOP")
    body:SetPoint("TOPLEFT", well, "TOPLEFT", 10, -9)
    body:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -10, 6)
    refresh[#refresh + 1] = function() body:SetText(ns.BuildMacroText()) end

    Paragraph(p, well, 8, "SmartAssist keeps this up to date for you, so there's no need to change it.", "body", 11, "muted")
end

local function BuildBar()
    local p = NewPage()
    local h = Heading(p, nil, 0, "Put it on your action bar")

    local drag = CreateFrame("Button", nil, p)
    drag:SetSize(44, 44)
    drag:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -14)
    drag:RegisterForDrag("LeftButton")
    drag:RegisterForClicks("LeftButtonUp")
    Theme.Box(drag, "well", "accent", "buttonRadius")
    local ico = drag:CreateTexture(nil, "ARTWORK")
    ico:SetPoint("TOPLEFT", 3, -3)
    ico:SetPoint("BOTTOMRIGHT", -3, 3)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local hl = drag:CreateTexture(nil, "HIGHLIGHT")
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
    drag:SetScript("OnDragStart", Pick)
    drag:SetScript("OnClick", Pick)
    drag:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.GetMacroName(), 1, 1, 1)
        GameTooltip:AddLine("Drag onto an action bar slot.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    drag:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local dragTitle = Theme.Text(p, "strong", 13, "text")
    dragTitle:SetPoint("TOPLEFT", drag, "TOPRIGHT", 12, -4)
    dragTitle:SetText("Drag this icon onto any action bar slot")
    local dragSub = Theme.Text(p, "body", 11, "muted")
    dragSub:SetPoint("TOPLEFT", dragTitle, "BOTTOMLEFT", 0, -4)
    dragSub:SetText("Or click it, then click the slot you want.")

    local anchor = CreateFrame("Frame", nil, p)
    anchor:SetSize(1, 1)
    anchor:SetPoint("TOPLEFT", drag, "BOTTOMLEFT", 0, 0)

    local l = Label(p, anchor, 18, "OR FIND IT IN THE MACRO WINDOW")
    local s1 = Paragraph(p, l, 8, "1.  Press Escape and choose Macros, or type /macro.")
    local s2 = Paragraph(p, s1, 6, "")
    local s3 = Paragraph(p, s2, 6, "")
    refresh[#refresh + 1] = function()
        local accent = Theme.Code("accent")
        s2:SetText("2.  Click the " .. accent .. ns.MacroTabName() .. "|r tab at the top.")
        s3:SetText("3.  Drag " .. accent .. ns.GetMacroName() .. "|r onto your action bar.")
        ico:SetTexture(ns.IsSpellAvailable() and ns.GetSpellIconID() or 134400)
    end

    local open = TextButton(p, "Open Macros", 120, function()
        if InCombatLockdown() then return end
        if ShowMacroFrame then ShowMacroFrame() end
        local tab = SmartAssistDB.perCharacter and MacroFrameTab2 or MacroFrameTab1
        if tab and tab:IsShown() then tab:Click() end
    end)
    open:SetPoint("TOPLEFT", s3, "BOTTOMLEFT", 0, -12)

    local status = Theme.Text(p, "strong", 12, "muted")
    status:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -18)
    status:SetWidth(CONTENT)
    status:SetWordWrap(true)

    local warn = Theme.Text(p, "body", 11, "warn")
    warn:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -8)
    warn:SetWidth(CONTENT)
    warn:SetWordWrap(true)

    refresh[#refresh + 1] = function()
        if ns.IsMacroOnBar() then
            status:SetText("Found it on your action bar. You're good to go.")
            Theme.SetColor(status, "accent")
        else
            status:SetText("Not on your action bars yet.")
            Theme.SetColor(status, "muted")
        end
        if ns.IsSpellAvailable() then
            warn:SetText("")
        else
            warn:SetText("You haven't learned " .. Spell() .. " yet. The button shows a question mark until you take the talent, then it works on its own.")
        end
    end
end

local function BuildDone()
    local p = NewPage()
    local h = Heading(p, nil, 0, "You're all set")
    local a = Paragraph(p, h, 12, "Press your new button and " .. Spell() .. " goes where you aimed it.")

    local l = Label(p, a, 16, "CHANGING WHO IT'S AIMED AT")
    local b1 = Paragraph(p, l, 8, "-  Hover the minimap button for the quick menu. The name at the bottom shows who the macro is aimed at right now.")
    local b2
    if ns.class == "PRIEST" then
        b2 = Paragraph(p, b1, 6, "-  To pick a specific player, target them and choose Save Target's Name.")
    else
        b2 = Paragraph(p, b1, 6, "-  In a group, choose Set to Party Tank (or Raid Tank) to aim it at the tank straight away.")
    end
    local b3 = Paragraph(p, b2, 6, "-  Right-click the minimap button, or type /smartassist, for settings.")

    local l2 = Label(p, b3, 16, "GOOD TO KNOW")
    local c1 = Paragraph(p, l2, 8, "-  The macro can't change during combat. Anything you pick mid-fight is applied as soon as combat ends.")
    local c2 = Paragraph(p, c1, 6, "-  Click the sliders button at the top of any SmartAssist window to change its look.")
    Paragraph(p, c2, 6, "-  Type /smartassist setup to see this guide again.")
end

local function ShowPage(i)
    current = math.max(1, math.min(i, #pages))
    for n, p in ipairs(pages) do p:SetShown(n == current) end
    backBtn:SetShown(current > 1)
    nextBtn.label:SetText(current == #pages and "Done" or "Next")
    stepLbl:SetText("Step " .. current .. " of " .. #pages)
    ns.RefreshWizard()
end

function ns.RefreshWizard()
    if not wizard or not wizard:IsShown() then return end
    for _, fn in ipairs(refresh) do fn() end
end

local function BuildWizard()
    local f = CreateFrame("Frame", "SmartAssistWizard", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:Hide()
    Theme.Window(f, HEADER_H)
    tinsert(UISpecialFrames, "SmartAssistWizard")
    wizard = f

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
    ico:SetTexture(ns.GetSpellIconID())

    local title = Theme.Text(f, "title", nil, "title")
    title:SetPoint("BOTTOMLEFT", ico, "RIGHT", 8, 0)
    Theme.SetTitle(title, "SmartAssist")

    local sub = Theme.Text(f, "body", 11, "muted")
    sub:SetPoint("TOPLEFT", ico, "RIGHT", 8, -1)
    sub:SetText("Setup for " .. PlayerName())

    local btnSize = HEADER_H - 18
    local closeBtn = Theme.IconButton(f, "icon_close", btnSize, function() f:Hide() end, "Close")
    closeBtn:SetPoint("RIGHT", f, "TOPRIGHT", -10, -HEADER_H / 2)

    local themeBtn = Theme.IconButton(f, "icon_sliders", btnSize, function() Theme.Next() end,
        function() return "Theme: " .. Theme.T.name .. "\nClick for the next theme" end)
    themeBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)

    local footLine = f:CreateTexture(nil, "ARTWORK")
    footLine:SetHeight(1)
    footLine:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  PAD, FOOTER_H)
    footLine:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOTER_H)
    Theme.Skin(function(_, C) footLine:SetColorTexture(C.line[1], C.line[2], C.line[3], 1) end)

    nextBtn = TextButton(f, "Next", 90, function()
        if current == #pages then
            f:Hide()
        else
            ShowPage(current + 1)
        end
    end)
    nextBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 13)

    backBtn = TextButton(f, "Back", 90, function() ShowPage(current - 1) end)
    backBtn:SetPoint("RIGHT", nextBtn, "LEFT", -8, 0)

    stepLbl = Theme.Text(f, "body", 11, "muted")
    stepLbl:SetPoint("LEFT", f, "BOTTOMLEFT", PAD, 13 + FIELD_H / 2)

    BuildWelcome()
    BuildBehaviour()
    BuildMacro()
    BuildBar()
    BuildDone()

    f:SetScript("OnHide", function()
        SmartAssistDB.wizardDone = true
        f:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
    end)
    f:SetScript("OnShow", function()
        f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    end)
    f:SetScript("OnEvent", function() ns.RefreshWizard() end)
end

function ns.ShowWizard()
    if not wizard then BuildWizard() end
    if ns.tooltip then ns.tooltip:Hide() end
    wizard:Show()
    ShowPage(1)
end
