--[[
    !SuperNovaUI_Compat

    The leading "!" makes the game load this addon before the others. Some addons call the
    removed functions while they are loading (for example when an item is already cached), so
    the shims have to exist before them.

    Each shim restores a global that Blizzard removed. It only activates when the global is
    missing, so it never overrides Blizzard's own version or another addon's shim
    (for example FixRematch / !RematchCompat).

    Shim fields:
      name        - short name
      description - shown in the SuperNovaUI compatibility menu
      isMissing   - returns true when the global is absent
      install     - defines the global

    The SuperNovaUI addon reads the result through the global SuperNovaUICompat.
]]

local Compat = {}
_G.SuperNovaUICompat = Compat

-- Old item globals that moved to C_Item (11.0.2 deprecated them, later patches removed them).
-- old global -> C_Item function with the same arguments and return values.
-- A global is only restored when it is missing AND the C_Item function exists, so a name
-- that does not exist in a given client is simply skipped.
local ITEM_GLOBALS = {
    GetItemInfo = "GetItemInfo",
    GetItemInfoInstant = "GetItemInfoInstant",
    GetItemCount = "GetItemCount",
    GetDetailedItemLevelInfo = "GetDetailedItemLevelInfo",
    GetItemSpell = "GetItemSpell",
    GetItemGem = "GetItemGem",
    GetItemFamily = "GetItemFamily",
    GetItemUniqueness = "GetItemUniqueness",
    GetItemClassInfo = "GetItemClassInfo",
    GetItemSubClassInfo = "GetItemSubClassInfo",
    GetItemIcon = "GetItemIconByID",
    IsUsableItem = "IsUsableItem",
    IsEquippedItem = "IsEquippedItem",
    IsEquippableItem = "IsEquippableItem",
    IsConsumableItem = "IsConsumableItem",
    IsItemInRange = "IsItemInRange",
}

local function HasMissingItemGlobals()
    for globalName, apiName in pairs(ITEM_GLOBALS) do
        if _G[globalName] == nil and C_Item and C_Item[apiName] then
            return true
        end
    end
    return false
end

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
    {
        name = "GetItemInfo",
        description = "Item globals moved to C_Item (GetItemInfo, GetItemInfoInstant, GetItemCount, GetDetailedItemLevelInfo, ...). Fixes ClassCodex, CraftInfoAnywhere and others.",
        isMissing = HasMissingItemGlobals,
        install = function()
            -- same arguments and return values as the C_Item functions the globals forwarded to
            for globalName, apiName in pairs(ITEM_GLOBALS) do
                if _G[globalName] == nil and C_Item and C_Item[apiName] then
                    _G[globalName] = C_Item[apiName]
                end
            end
        end,
    },
}

local states = {}

for _, shim in ipairs(SHIMS) do
    local state = { name = shim.name, description = shim.description, active = false }

    if shim.isMissing() then
        state.active = pcall(shim.install)
    end

    tinsert(states, state)
end

-- list of { name, description, active }; active means this addon defined the global
function Compat:GetShimStates()
    return states
end
