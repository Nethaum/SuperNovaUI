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
    installed = false,
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
        return hasRemainingSlots(...) and not hasMySpec
    end

    if type(pgf.L) == "table" then
        pgf.L[TOOLTIP_KEY] = TOOLTIP_TEXT
    end

    self.installed = true
    SN:Debug(self.name, "Party Fit wrapped")
    return true
end

function PGFModule:Initialize()
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

SN:RegisterModuleDefaults("pgf", { enabled = true })
SN:RegisterModule("pgf", PGFModule)
