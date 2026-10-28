local addonName, SN = ...

local Compat = {}

-- toc field written into every addon we patched (see wow-addon-patches)
local PATCH_FIELD = "X-SuperNovaUI-Patch"

--[[
    Addons that need a fix file by file (a shim cannot repair them).
    An addon counts as fixed when its .toc carries X-SuperNovaUI-Patch.
]]
local KNOWN_ADDONS = {
    {
        name = "tdBattlePetScript",
        problem = "Original version fails on 12.x: options panel, removed constants and a removed font.",
    },
    {
        name = "tdBattlePetScript_Rematch",
        problem = "Written for Rematch 4. Needs a Rematch 5 version to attach scripts to teams.",
    },
    {
        name = "RematchElvUISkin",
        problem = "Skin for Rematch 4. Does not match the Rematch 5 window.",
    },
    {
        name = "RematchCelestialTournament",
        problem = "Replaces Rematch 4 internals that no longer exist.",
    },
    {
        name = "RematchNextTarget",
        problem = "Replaces Rematch 4 internals that no longer exist.",
    },
    {
        name = "Rematch",
        problem = "5.3.1 raises an error reading NPC names (secret values, patch 12.1).",
        -- fixed at runtime by the SuperNovaUI module of this name instead of by a patched file
        fixedByModule = "rematch",
    },
}

--[[
    Behaviour tweaks SuperNovaUI applies to other addons at runtime (they are not compatibility
    fixes, so they are listed apart). Each one is a SuperNovaUI module that sets `installed`
    once it hooked the other addon.
]]
local TWEAKS = {
    {
        module = "pgf",
        addon = "PremadeGroupsFilter",
        description = "Premade Groups Filter: Party Fit also hides groups with my class and specialization.",
    },
}

local function GetMetadata(addon, field)
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local ok, value = pcall(getMetadata, addon, field)
    return ok and value or nil
end

local function AddonExists(addon)
    if C_AddOns and C_AddOns.DoesAddOnExist then
        return C_AddOns.DoesAddOnExist(addon)
    end

    local getInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    local ok, name = pcall(getInfo, addon)
    return ok and name ~= nil
end

local function IsAddonEnabled(addon)
    local getState = C_AddOns and C_AddOns.GetAddOnEnableState or GetAddOnEnableState
    local ok, state = pcall(getState, addon)
    return not ok or state == nil or state > 0
end

-- The shims live in the companion addon !SuperNovaUI_Compat (it loads first, see its Shims.lua).
-- Returns its list of { name, description, active }, or nil when the companion is not installed.
function Compat:GetShimStates()
    local shared = _G.SuperNovaUICompat
    return shared and shared:GetShimStates() or nil
end

-- tweaks with a state: "active", "disabled", "not hooked" (addon present but not reached) or "not installed"
function Compat:GetTweakStates()
    local states = {}
    for _, tweak in ipairs(TWEAKS) do
        local module = SN:GetModule(tweak.module)
        local settings = SN:GetModuleSettings(tweak.module)
        local state
        if not AddonExists(tweak.addon) then
            state = "not installed"
        elseif settings and settings.enabled == false then
            state = "disabled"
        elseif module and module.installed then
            state = "active"
        else
            state = "not hooked"
        end

        tinsert(states, { name = tweak.module, description = tweak.description, state = state })
    end
    return states
end

-- known addons that are installed, with: fixed (patched), enabled, problem
function Compat:GetAddonStates()
    local states = {}
    for _, known in ipairs(KNOWN_ADDONS) do
        if AddonExists(known.name) then
            local fixed
            if known.fixedByModule then
                local module = SN:GetModule(known.fixedByModule)
                fixed = module ~= nil and module.installed == true
            else
                fixed = GetMetadata(known.name, PATCH_FIELD) ~= nil
            end

            tinsert(states, {
                name = known.name,
                problem = known.problem,
                enabled = IsAddonEnabled(known.name),
                fixed = fixed,
            })
        end
    end
    return states
end

function Compat:PrintStatus()
    local shims = self:GetShimStates()
    if shims then
        SN:Print("Compatibility shims:")
        for _, shim in ipairs(shims) do
            SN:Print(string.format("- %s: %s", shim.description, shim.active and "active (provided by !SuperNovaUI_Compat)" or "not needed (already provided)"))
        end
    else
        SN:Print("Compatibility shims: companion addon !SuperNovaUI_Compat is not installed, so they are inactive.")
    end

    SN:Print("Tweaks:")
    for _, tweak in ipairs(self:GetTweakStates()) do
        SN:Print(string.format("- %s: %s", tweak.description, tweak.state))
    end

    local addons = self:GetAddonStates()
    SN:Print("Addons that need a fix:")
    if #addons == 0 then
        SN:Print("- none of the known addons is installed")
        return
    end

    for _, addon in ipairs(addons) do
        SN:Print(string.format("- %s: %s", addon.name, addon.fixed and "fixed" or "NEEDS FIX"))
    end
end

-- /snui compat          opens the menu
-- /snui compat status   prints the state in the chat
function Compat:HandleCommand(command)
    if command == "status" then
        self:PrintStatus()
    elseif self.TogglePanel then
        self:TogglePanel()
    else
        self:PrintStatus()
    end
end

SN:RegisterModuleDefaults("compat", { enabled = true })
SN:RegisterModule("compat", Compat)
