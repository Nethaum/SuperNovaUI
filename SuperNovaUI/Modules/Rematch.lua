local addonName, SN = ...

--[[
    Rematch 5.3.1 fix for patch 12.1.

    Rematch reads an NPC's name from a tooltip, and in 12.1 that text is a "secret value": calling
    name:len() on it raises "attempt to index local 'name' (a secret string value)", which broke
    opening the pet journal.

    Works at runtime, without editing Rematch's files: every caller reaches the function through
    Rematch.targetInfo, so it is wrapped here. When the original raises, the NPC gets the same
    "Unknown (npc id N)" label Rematch already uses for names it cannot find, remembered so the
    tooltip is not scanned again on every refresh.
]]

local RematchModule = {
    installed = false,
}

local REMATCH_ADDON = "Rematch"

local function GetTargetInfo()
    local rematch = _G.Rematch
    local targetInfo = rematch and rematch.targetInfo
    if type(targetInfo) == "table" and type(targetInfo.GetNpcName) == "function" then
        return rematch, targetInfo
    end
end

local function GetNpcNumber(npcID)
    if type(npcID) == "string" then
        return tonumber(npcID:match("target:(%d+)"))
    end
    return npcID
end

function RematchModule:Install()
    if self.installed then
        return true
    end

    local rematch, targetInfo = GetTargetInfo()
    if not targetInfo then
        return false
    end

    local getNpcName = targetInfo.GetNpcName
    local unreadable = {}

    targetInfo.GetNpcName = function(info, npcID, ...)
        local number = GetNpcNumber(npcID)
        if number and unreadable[number] then
            return unreadable[number]
        end

        local ok, name = pcall(getNpcName, info, npcID, ...)
        if ok then
            return name
        end

        if type(number) ~= "number" then
            return name -- not an npc id: nothing sensible to show, keep Rematch's own failure
        end

        local label = string.format(rematch.localization["%s (npc id %d)"], UNKNOWN, number)
        unreadable[number] = label
        SN:Debug(self.name, "unreadable name for npc " .. number)
        return label
    end

    self.installed = true
    return true
end

function RematchModule:Initialize()
    if self:Install() then
        return
    end

    -- Rematch is not loaded yet: try again when it finishes loading
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(frame, _, loadedAddon)
        if loadedAddon == REMATCH_ADDON and RematchModule:Install() then
            frame:UnregisterAllEvents()
        end
    end)
end

function RematchModule:PrintStatus()
    local settings = SN:GetModuleSettings(self.name)
    if settings and settings.enabled == false then
        SN:Print("Rematch fix: disabled.")
    elseif self.installed then
        SN:Print("Rematch fix: active (NPC names that cannot be read show as Unknown).")
    elseif C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist(REMATCH_ADDON) then
        SN:Print("Rematch fix: Rematch is installed but not hooked (is it loaded and up to date?).")
    else
        SN:Print("Rematch fix: Rematch is not installed.")
    end
end

function RematchModule:HandleCommand()
    self:PrintStatus()
end

SN:RegisterModuleDefaults("rematch", { enabled = true })
SN:RegisterModule("rematch", RematchModule)
