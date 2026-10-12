local addonName, SN = ...

local Compat = {
    installed = {},
}

-- toc field written into every addon we patched (see wow-addon-patches)
local PATCH_FIELD = "X-SuperNovaUI-Patch"

--[[
    Each shim restores a global that Blizzard removed while installed addons still call it.
    A shim only activates when the global is missing, so it never overrides Blizzard's own
    version or another addon's shim (for example FixRematch / !RematchCompat).

    Shim fields:
      name        - short name
      description - shown in the compatibility menu and in /snui compat status
      isMissing   - returns true when the global is absent
      install     - defines the global
]]
local SHIMS = {
    {
        name = "MouseIsOver",
        description = "MouseIsOver (removed in patch 12.1). Fixes Rematch 5.3.1 blank window, menus, drag and drop.",
        isMissing = function()
            return _G.MouseIsOver == nil
        end,
        install = function()
            -- same pass-through Blizzard shipped until 12.0.7 (idea credit: FixRematch / !RematchCompat, MIT)
            _G.MouseIsOver = function(region, topOffset, bottomOffset, leftOffset, rightOffset)
                return region:IsMouseOver(topOffset, bottomOffset, leftOffset, rightOffset)
            end
        end,
    },
    {
        name = "LE_BATTLE_PET_*",
        description = "LE_BATTLE_PET_WEATHER/ALLY/ENEMY (replaced by Enum.BattlePetOwner). Fixes tdBattlePetScript.",
        isMissing = function()
            return _G.LE_BATTLE_PET_ALLY == nil or _G.LE_BATTLE_PET_ENEMY == nil or _G.LE_BATTLE_PET_WEATHER == nil
        end,
        install = function()
            local owner = Enum and Enum.BattlePetOwner
            _G.LE_BATTLE_PET_WEATHER = _G.LE_BATTLE_PET_WEATHER or (owner and owner.Weather) or 0
            _G.LE_BATTLE_PET_ALLY = _G.LE_BATTLE_PET_ALLY or (owner and owner.Ally) or 1
            _G.LE_BATTLE_PET_ENEMY = _G.LE_BATTLE_PET_ENEMY or (owner and owner.Enemy) or 2
        end,
    },
}

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

function Compat:Initialize()
    for _, shim in ipairs(SHIMS) do
        if shim.isMissing() then
            shim.install()
            self.installed[shim.name] = true
            SN:Debug(self.name, "installed shim " .. shim.name)
        end
    end
end

-- list of shims with their state: "active" (installed by us) or "provided" (someone else already did)
function Compat:GetShimStates()
    local states = {}
    for _, shim in ipairs(SHIMS) do
        tinsert(states, {
            name = shim.name,
            description = shim.description,
            active = self.installed[shim.name] and true or false,
        })
    end
    return states
end

-- known addons that are installed, with: fixed (patched), enabled, problem
function Compat:GetAddonStates()
    local states = {}
    for _, known in ipairs(KNOWN_ADDONS) do
        if AddonExists(known.name) then
            tinsert(states, {
                name = known.name,
                problem = known.problem,
                enabled = IsAddonEnabled(known.name),
                fixed = GetMetadata(known.name, PATCH_FIELD) ~= nil,
            })
        end
    end
    return states
end

function Compat:PrintStatus()
    SN:Print("Compatibility shims:")
    for _, shim in ipairs(self:GetShimStates()) do
        SN:Print(string.format("- %s: %s", shim.description, shim.active and "active (provided by SuperNovaUI)" or "not needed (already provided)"))
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
