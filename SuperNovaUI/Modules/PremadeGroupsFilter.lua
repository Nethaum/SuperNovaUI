local addonName, SN = ...

--[[
    Premade Groups Filter tweak: "Party Fit" also hides groups that already have a member with
    my class and specialization.

    Works at runtime, without editing PGF's files. PGF exposes its internal table as
    PremadeGroupsFilter.Debug and calls the two functions below through that table, so wrapping
    them is enough:
      PGF.PutSearchResultMemberInfos(resultID, info, env)  fills env.hasmyspec for one group
      PGF.HasRemainingSlotsForLocalPlayerPartyRoles(...)   becomes env.partyfit for the same group
    PGF calls them back to back for each group, so the value remembered from the first one belongs
    to the group the second one is asked about.
]]

local PGFModule = {
    installed = false, -- PGF's functions are wrapped (the wrappers stay for the whole session)
    running = false,   -- the tweak is on: the wrappers only change PGF's answer while this is true
}

local PGF_ADDON = "PremadeGroupsFilter"

local TOOLTIP_KEY = "dialog.partyfit.tooltip"
local TOOLTIP_TEXT = "Show only groups that still have slots for all your party members roles and do not already have someone with your class and specialization. Also works if you are alone."

local function GetPGF()
    local pgf = _G.PremadeGroupsFilter
    return pgf and pgf.Debug or nil
end

local function IsReady(pgf)
    return type(pgf) == "table"
        and type(pgf.PutSearchResultMemberInfos) == "function"
        and type(pgf.HasRemainingSlotsForLocalPlayerPartyRoles) == "function"
end

function PGFModule:Install()
    if self.installed then
        return true
    end

    local pgf = GetPGF()
    if not IsReady(pgf) then
        return false
    end

    local hasMySpec = false

    local putMemberInfos = pgf.PutSearchResultMemberInfos
    pgf.PutSearchResultMemberInfos = function(resultID, searchResultInfo, env)
        local results = { putMemberInfos(resultID, searchResultInfo, env) }
        hasMySpec = type(env) == "table" and env.hasmyspec == true
        return unpack(results)
    end

    local hasRemainingSlots = pgf.HasRemainingSlotsForLocalPlayerPartyRoles
    pgf.HasRemainingSlotsForLocalPlayerPartyRoles = function(...)
        if not PGFModule.running then
            return hasRemainingSlots(...)
        end

        return hasRemainingSlots(...) and not hasMySpec
    end

    if type(pgf.L) == "table" then
        self.originalTooltip = pgf.L[TOOLTIP_KEY]
    end

    self.installed = true
    self:ApplyTooltip()
    SN:Debug(self.name, "Party Fit wrapped")
    return true
end

-- Party Fit's tooltip describes the extra rule only while the tweak is on.
function PGFModule:ApplyTooltip()
    local pgf = GetPGF()

    if self.installed and pgf and type(pgf.L) == "table" then
        pgf.L[TOOLTIP_KEY] = self.running and TOOLTIP_TEXT or self.originalTooltip
    end
end

function PGFModule:SetEnabled(enabled)
    self.running = enabled
    self:ApplyTooltip()
end

function PGFModule:GetStatusDetail()
    if self.installed then
        return "active"
    end

    return "warning", {
        enUS = "Premade Groups Filter is installed but not hooked yet (is it loaded and up to date?)",
        ptBR = "O Premade Groups Filter está instalado, mas ainda não foi alcançado (está carregado e atualizado?)",
    }
end

function PGFModule:Initialize()
    self.running = true

    if self:Install() then
        return
    end

    -- PGF is not loaded yet (or not installed): try again when it finishes loading
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(frame, _, loadedAddon)
        if loadedAddon == PGF_ADDON and PGFModule:Install() then
            frame:UnregisterAllEvents()
        end
    end)
end

function PGFModule:PrintStatus()
    local settings = SN:GetModuleSettings(self.name)
    if settings and settings.enabled == false then
        SN:Print("Premade Groups Filter tweak: disabled.")
    elseif self.installed then
        SN:Print("Premade Groups Filter tweak: active (Party Fit also hides groups with my class and specialization).")
    elseif C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist(PGF_ADDON) then
        SN:Print("Premade Groups Filter tweak: PGF is installed but not hooked (is it loaded and up to date?).")
    else
        SN:Print("Premade Groups Filter tweak: Premade Groups Filter is not installed.")
    end
end

function PGFModule:HandleCommand()
    self:PrintStatus()
end

PGFModule.info = {
    category = "groups",
    kind = "fix",
    requiresAddon = PGF_ADDON,
    order = 1,
    name = { enUS = "Premade Groups Filter", ptBR = "Premade Groups Filter" },
    desc = {
        enUS = "Makes \"Party Fit\" also hide groups that already have your class and specialization.",
        ptBR = "Faz o \"Party Fit\" também esconder grupos que já têm a sua classe e especialização.",
    },
    help = { "/snui pgf - show the Premade Groups Filter tweak (Party Fit) state" },
    GetStatus = function(module)
        return module:GetStatusDetail()
    end,
}

SN:RegisterModuleDefaults("pgf", { enabled = true })
SN:RegisterModule("pgf", PGFModule)
