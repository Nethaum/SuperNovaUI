local addonName, SN = ...

local Compat = {
    installed = {},
}

--[[
    Each shim restores a global that Blizzard removed while installed addons still call it.
    A shim only activates when the global is missing, so it never overrides Blizzard's own
    version or another addon's shim (for example FixRematch / !RematchCompat).

    Shim fields:
      description - shown in /snui compat
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

function Compat:Initialize()
    for _, shim in ipairs(SHIMS) do
        if shim.isMissing() then
            shim.install()
            self.installed[shim.name] = true
            SN:Debug(self.name, "installed shim " .. shim.name)
        end
    end
end

function Compat:PrintStatus()
    SN:Print("Compatibility shims:")

    for _, shim in ipairs(SHIMS) do
        local state
        if self.installed[shim.name] then
            state = "active (provided by SuperNovaUI)"
        else
            state = "not needed (already provided)"
        end

        SN:Print(string.format("- %s: %s", shim.description, state))
    end
end

function Compat:HandleCommand()
    self:PrintStatus()
end

SN:RegisterModuleDefaults("compat", { enabled = true })
SN:RegisterModule("compat", Compat)
