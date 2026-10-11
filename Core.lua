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
    target    = CLASS == "HUNTER" and "pet" or "focus",
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

local function WriteMacro()
    if InCombatLockdown() then
        ns.pendingMacro = true
        return
    end

    local name = SmartAssistDB.macroName or SPELL.name
    local body = BuildMacroText()
    local icon = ns.IsSpellAvailable() and SPELL.iconID or ICON_UNAVAILABLE
    local idx  = GetMacroIndexByName(name)

    if idx == 0 then
        local result = CreateMacro(name, icon, body, nil)
        if not result then
            print("|cffC8A838SmartAssist|r: Could not create macro \"" .. name .. "\" — macro limit reached (max 18 general macros).")
        end
    else
        EditMacro(idx, name, icon, body)
    end
end

ns.WriteMacro = WriteMacro

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

local function Notify(msg)
    print("|cffC8A838SmartAssist|r: " .. msg)
end

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
        WriteMacro()

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

    elseif event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" then
        if not InCombatLockdown() then
            WriteMacro()
            if ns.RefreshTooltipText then ns.RefreshTooltipText() end
        end
    end
end)

SLASH_SMARTASSIST1 = "/smartassist"
SlashCmdList["SMARTASSIST"] = function()
    if ns.ToggleConfig then ns.ToggleConfig() end
end
