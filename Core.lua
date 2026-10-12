local addonName, ns = ...

local _, CLASS = UnitClass("player")
local CLASS_SPELLS = {
    HUNTER = { id = 34477, name = "Misdirection",        iconID = 136153 },
    ROGUE  = { id = 57934, name = "Tricks of the Trade", iconID = 458452 },
    PRIEST = { id = 10060, name = "Power Infusion",      iconID = 135939 },
}

local CLASS_SPELL = CLASS_SPELLS[CLASS]
if not CLASS_SPELL then return end
ns.class = CLASS

local SPELL_ID = CLASS_SPELL.id

local function ResolveSpell(id)
    local info = C_Spell.GetSpellInfo(id)
    return {
        name   = (info and info.name)   or CLASS_SPELL.name,
        iconID = (info and info.iconID) or CLASS_SPELL.iconID,
    }
end

local SPELL            = ResolveSpell(SPELL_ID)
local ICON_UNAVAILABLE = 134400

ns.GetSpellName     = function() return SPELL.name   end
ns.GetSpellIconID   = function() return SPELL.iconID end
ns.IsSpellAvailable = function()
    if CLASS == "ROGUE" then return true end
    return C_SpellBook.IsSpellKnown(SPELL_ID)
end

local function UnitLabel(label, unit)
    local name = UnitExists(unit) and UnitName(unit)
    if not name or (issecretvalue and issecretvalue(name)) then return label end
    return label .. ": " .. name
end

ns.GetTargetLabel = function()
    local db = SmartAssistDB
    local t  = db.target or ""
    if     t == "pet"          then return db.petname ~= "" and db.petname or "Pet"
    elseif t == "target"       then return UnitLabel("Target", "target")
    elseif t == "targettarget" then return UnitLabel("Target of Target", "targettarget")
    elseif t == "focus"        then return UnitLabel("Focus", "focus")
    elseif t == ""             then return "None"
    else                            return t
    end
end

local DEFAULTS = {
    target    = CLASS == "HUNTER" and "pet" or CLASS == "PRIEST" and "" or "focus",
    petname   = "",
    macroName = CLASS_SPELL.name,
    minimap   = { hide = false },
    autotank  = CLASS ~= "PRIEST",
    autopet   = CLASS == "HUNTER" and true or false,
}

local function InitDB()
    SmartAssistDB = SmartAssistDB or {}
    for k, v in pairs(DEFAULTS) do
        if SmartAssistDB[k] == nil then
            SmartAssistDB[k] = type(v) == "table" and CopyTable(v) or v
        end
    end
    SmartAssistDB.minimap = SmartAssistDB.minimap or CopyTable(DEFAULTS.minimap)
end

local function UpdatePetName()
    if CLASS ~= "HUNTER" then return end
    local name = UnitName("pet")
    if name and name ~= UNKNOWNOBJECT then
        SmartAssistDB.petname = name
    end
end

ns.UpdatePetName = UpdatePetName

local function BuildMacroText()
    local db        = SmartAssistDB
    local target    = db.target or ""
    local spell     = SPELL.name
    local hasPet    = CLASS == "HUNTER" and UnitExists("pet")
    local available = ns.IsSpellAvailable()

    local showtooltip = available and ("#showtooltip " .. spell) or "#showtooltip"

    if target == "pet" then
        return showtooltip .. "\n/cast [@pet,nodead][] " .. spell
    end

    local cond
    if     target == "focus"        then cond = "[@focus,nodead]"
    elseif target == "target"       then cond = "[@target,nodead]"
    elseif target == "targettarget" then cond = "[@targettarget,nodead]"
    elseif target ~= ""             then cond = "[@" .. target .. ",nodead]"
    end

    if not cond then
        return showtooltip .. "\n/cast [] " .. spell
    end

    if hasPet then
        return showtooltip .. "\n/cast " .. cond .. "[@pet,nodead][] " .. spell
    else
        return showtooltip .. "\n/cast " .. cond .. "[] " .. spell
    end
end

ns.BuildMacroText = BuildMacroText

local ACCOUNT_MAX = MAX_ACCOUNT_MACROS or 120
local CHAR_MAX    = MAX_CHARACTER_MACROS or 18

local function GetMacroName()
    return SmartAssistDB.macroName or SPELL.name
end

ns.GetMacroName = GetMacroName

local function FindMacro(name, perChar)
    local numAccount, numChar = GetNumMacros()
    local first, last = 1, numAccount or 0
    if perChar then
        first, last = ACCOUNT_MAX + 1, ACCOUNT_MAX + (numChar or 0)
    end
    for i = first, last do
        if GetMacroInfo(i) == name then return i end
    end
    return 0
end

ns.FindMacro = FindMacro

ns.MacroTabName = function(perChar)
    if perChar == nil then perChar = SmartAssistDB.perCharacter end
    if perChar then
        return (CHARACTER_SPECIFIC_MACROS or "%s Specific Macros"):format(UnitName("player"))
    end
    return GENERAL_MACROS or "General Macros"
end

ns.IsMacroOnBar = function()
    local name = GetMacroName()
    for slot = 1, 180 do
        if GetActionInfo(slot) == "macro" and GetActionText(slot) == name then
            return true
        end
    end
    return false
end

local function WriteMacro()
    if InCombatLockdown() then
        ns.pendingMacro = true
        return
    end

    local perChar = SmartAssistDB.perCharacter and true or false
    local name    = GetMacroName()
    local body    = BuildMacroText()
    local icon    = ns.IsSpellAvailable() and SPELL.iconID or ICON_UNAVAILABLE
    local idx     = FindMacro(name, perChar)

    if idx == 0 then
        local result = CreateMacro(name, icon, body, perChar)
        if not result then
            print(ns.Theme.Code("accent") .. "SmartAssist|r: Could not create macro \"" .. name .. "\" because "
                .. ns.MacroTabName(perChar) .. " is full (" .. (perChar and CHAR_MAX or ACCOUNT_MAX) .. " max).")
        end
    else
        EditMacro(idx, name, icon, body)
    end
end

ns.WriteMacro = WriteMacro

local function ResolveMacroLocation()
    if SmartAssistDB.perCharacter ~= nil then return end
    SmartAssistDB.perCharacter = FindMacro(GetMacroName(), false) == 0
end

local function SetMacroLocation(perChar)
    perChar = perChar and true or false
    if (SmartAssistDB.perCharacter and true or false) == perChar then return true end
    if InCombatLockdown() then
        print(ns.Theme.Code("accent") .. "SmartAssist|r: You can't move the macro during combat.")
        return false
    end
    local name = GetMacroName()
    SmartAssistDB.perCharacter = perChar
    WriteMacro()
    if FindMacro(name, perChar) == 0 then
        SmartAssistDB.perCharacter = not perChar
        return false
    end
    local old = FindMacro(name, not perChar)
    if old ~= 0 then DeleteMacro(old) end
    if ns.RefreshConfigDisplay then ns.RefreshConfigDisplay() end
    return true
end

ns.SetMacroLocation = SetMacroLocation

local function SetTarget(unitOrName)
    SmartAssistDB.target = unitOrName
    WriteMacro()
    if ns.tooltip              then ns.tooltip:Hide()         end
    if ns.RefreshTooltipText   then ns.RefreshTooltipText()   end
    if ns.RefreshConfigDisplay then ns.RefreshConfigDisplay() end
end

local function ClearTarget()
    SetTarget("")
end

ns.SetTarget   = SetTarget
ns.ClearTarget = ClearTarget

local function FindTank()
    local count = GetNumGroupMembers()
    if count == 0 then return nil end

    local prefix = IsInRaid() and "raid" or "party"
    local firstRoleTank
    local fallbackName, fallbackHP

    for i = 1, count do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name and UnitIsConnected(unit) then
            if GetPartyAssignment("MAINTANK", unit) then
                return name
            end
            if not firstRoleTank and UnitGroupRolesAssigned(unit) == "TANK" then
                firstRoleTank = name
            end
            if not firstRoleTank then
                for _, role in ipairs({ UnitGetAvailableRoles(unit) }) do
                    if role == "TANK" then
                        local hp = UnitHealthMax(unit)
                        if not fallbackHP or hp > fallbackHP then
                            fallbackHP   = hp
                            fallbackName = name
                        end
                        break
                    end
                end
            end
        end
    end

    return firstRoleTank or fallbackName
end

ns.FindTank = FindTank

local function ReadableName(unit)
    local name = GetUnitName(unit, true)
    if not name or (issecretvalue and issecretvalue(name)) then return nil end
    return name
end

ns.GetGroupDamagers = function()
    local list = {}
    if IsInRaid() then return list end
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        if UnitIsConnected(unit) and UnitGroupRolesAssigned(unit) == "DAMAGER" then
            local name = ReadableName(unit)
            if name then list[#list + 1] = name end
        end
    end
    return list
end

ns.IsNamedTarget = function(t)
    t = t or SmartAssistDB.target or ""
    return t ~= "" and t ~= "pet" and t ~= "target" and t ~= "targettarget" and t ~= "focus"
end

local function Notify(msg)
    print(ns.Theme.Code("accent") .. "SmartAssist|r: " .. msg)
end

ns.SaveTargetName = function()
    local name = UnitIsPlayer("target") and ReadableName("target")
    if name then
        SetTarget(name)
        Notify("Target set to " .. name)
        return name
    end
    Notify("Target a player first")
end

ns.Notify = Notify

local function ApplyAutoTank()
    local tank = FindTank()
    if tank and tank ~= SmartAssistDB.target then
        SetTarget(tank)
        Notify("Target set to " .. tank)
    end
end

local function ApplyAutoPet()
    if CLASS ~= "HUNTER" then return end
    if not UnitExists("pet") then return end
    UpdatePetName()
    SetTarget("pet")
    Notify("Target set to pet")
end

local inGroup           = false
local waitAccum         = 0
local WAIT_SEC          = 1.5
local pendingZonePrompt = false

local waitFrame = CreateFrame("Frame")
waitFrame:Hide()
waitFrame:SetScript("OnUpdate", function(self, elapsed)
    waitAccum = waitAccum + elapsed
    if waitAccum < WAIT_SEC then return end
    self:Hide()
    waitAccum = 0

    local nowIn = (GetNumGroupMembers() > 0) or (UnitInRaid("player") ~= nil)

    if nowIn and not inGroup then
        inGroup = true
        if SmartAssistDB.autotank then ApplyAutoTank() end
    elseif nowIn and inGroup then
        if SmartAssistDB.autotank then ApplyAutoTank() end
    elseif not nowIn and inGroup then
        inGroup = false
        if SmartAssistDB.autopet then ApplyAutoPet() end
    end

    if pendingZonePrompt then
        pendingZonePrompt = false
        local t = SmartAssistDB.target or ""
        local noTarget = (t == "") or (t == "pet" and not UnitExists("pet"))
        if noTarget and ns.ShowTargetPrompt then
            ns.ShowTargetPrompt()
        end
    end
end)

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")

evtFrame:SetScript("OnEvent", function(self, event, arg1)

    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")

        InitDB()
        inGroup = (GetNumGroupMembers() > 0) or (UnitInRaid("player") ~= nil)
        if CLASS == "HUNTER" and UnitExists("pet") then UpdatePetName() end

        if ns.InitTooltip then ns.InitTooltip() end
        if ns.InitConfig  then ns.InitConfig()  end

        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("UNIT_PET")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("PLAYER_FOCUS_CHANGED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_TALENT_UPDATE")
        self:RegisterEvent("SPELLS_CHANGED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        inGroup = (GetNumGroupMembers() > 0) or (UnitInRaid("player") ~= nil)
        if CLASS == "HUNTER" and UnitExists("pet") then UpdatePetName() end
        if inGroup then
            pendingZonePrompt = true
            waitAccum = 0
            waitFrame:Show()
        end
        ResolveMacroLocation()
        WriteMacro()
        if not SmartAssistDB.wizardDone and not ns.wizardQueued then
            ns.wizardQueued = true
            C_Timer.After(3, function()
                if InCombatLockdown() then
                    ns.wizardPending = true
                elseif ns.ShowWizard then
                    ns.ShowWizard()
                end
            end)
        end

    elseif event == "UNIT_PET" then
        if arg1 ~= "player" or CLASS ~= "HUNTER" then return end
        if UnitExists("pet") then
            UpdatePetName()
            if SmartAssistDB.target == "pet" then WriteMacro() end
        end
        if ns.RefreshTooltipText then ns.RefreshTooltipText() end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if SmartAssistDB.target == "target" then
            if not InCombatLockdown() then WriteMacro() end
            if ns.RefreshTooltipText then ns.RefreshTooltipText() end
        end

    elseif event == "PLAYER_FOCUS_CHANGED" then
        if SmartAssistDB.target == "focus" then
            if not InCombatLockdown() then WriteMacro() end
            if ns.RefreshTooltipText then ns.RefreshTooltipText() end
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        waitAccum = 0
        waitFrame:Show()

    elseif event == "PLAYER_REGEN_DISABLED" then
        if ns.tooltip then ns.tooltip:Hide() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.pendingMacro then
            ns.pendingMacro = false
            WriteMacro()
        end
        if ns.wizardPending then
            ns.wizardPending = false
            if ns.ShowWizard then ns.ShowWizard() end
        end

    elseif event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" then
        if not InCombatLockdown() then
            WriteMacro()
            if ns.RefreshTooltipText then ns.RefreshTooltipText() end
        end
    end
end)

SLASH_SMARTASSIST1 = "/smartassist"
SlashCmdList["SMARTASSIST"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "resetguide" then
        SmartAssistDB.wizardDone = nil
        Notify("The setup guide will show again after you /reload.")
        return
    end
    if msg == "setup" or msg == "guide" then
        if InCombatLockdown() then
            ns.wizardPending = true
        elseif ns.ShowWizard then
            ns.ShowWizard()
        end
        return
    end
    if ns.ToggleConfig then ns.ToggleConfig() end
end
