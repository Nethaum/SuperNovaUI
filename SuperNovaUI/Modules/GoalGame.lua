local addonName, SN = ...

--[[
    Profession goal: what the game says.

    Reads the open profession window, the professions the character has, the recipes it knows (with the colour the game gives
    each one) and the merchant window. Names come from the game, in the player's language; only ids are compared.
]]

local Goals = SN.ProfessionGoal

-- The game's own names for how useful a recipe is, best first.
local TIER_ORDER = { optimal = 1, medium = 2, easy = 3 }

local TIER_NAMES = {
    optimal = { enUS = "orange: always raises your level", ptBR = "laranja: sempre sobe o nível" },
    medium = { enUS = "yellow: usually raises your level", ptBR = "amarela: costuma subir o nível" },
    easy = { enUS = "green: sometimes raises your level", ptBR = "verde: às vezes sobe o nível" },
}

-- The key of the open profession: its id from the game's skill line, and the tier when the line has a parent (the
-- "Khaz Algar Cooking" of the Cooking line). Remembered, so the name is matched by id later.
function Goals:RememberOpenProfession(info)
    local parent = tonumber(info.parentProfessionID)
    local line = parent or tonumber(info.professionID)
    local id = line and self:IdOfLine(line)

    if not id then
        return
    end

    local tier = parent and tonumber(info.professionID)
    self:RememberKey(info.professionName, tier and tier ~= parent and (id .. ":" .. tier) or id)
end

-- The profession window that is open: name, current skill and the highest skill this rank allows. nil when none is open.
-- The game has two APIs for this (the classic TradeSkill functions and C_TradeSkillUI); whichever exists is used.
function Goals:ReadProfession()
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)

        if ok and type(info) == "table" and type(info.professionName) == "string" and info.professionName ~= ""
            and type(info.skillLevel) == "number" and info.skillLevel > 0 then
            self:RememberOpenProfession(info)
            return info.professionName, info.skillLevel, info.maxSkillLevel or info.skillLevel
        end
    end

    if GetTradeSkillLine then
        local ok, name, rank, maxRank = pcall(GetTradeSkillLine)

        if ok and type(name) == "string" and name ~= "" and name ~= "UNKNOWN" and type(rank) == "number" then
            return name, rank, maxRank or rank
        end
    end

    return nil
end

-- The professions the character has, without any window open: { [name] = highest skill }. Needs GetProfessions (modern
-- clients); without it the page learns them as the player opens each window.
function Goals:ReadKnownProfessions()
    local known = {}

    if GetProfessions and GetProfessionInfo then
        local ok, first, second, archaeology, fishing, cooking = pcall(GetProfessions)

        if ok then
            for _, index in ipairs({ first or false, second or false, fishing or false, cooking or false }) do
                if index then
                    local okInfo, name, _, _, maxSkill, _, _, skillLine = pcall(GetProfessionInfo, index)

                    if okInfo and type(name) == "string" and name ~= "" then
                        known[name] = tonumber(maxSkill) or 0
                        self:RememberLine(name, skillLine)
                    end
                end
            end
        end
    end

    return known
end

-- Every recipe the player knows: { name, tier ("optimal", "medium", "easy", "trivial"), available (copies the bags can pay) }.
local DIFFICULTY = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }

function Goals:ReadRecipes()
    local list = {}

    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo then
        local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)

        for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do
            local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)

            if okInfo and type(info) == "table" and info.learned ~= false and info.name then
                local tier = info.relativeDifficulty
                tier = type(tier) == "string" and tier or DIFFICULTY[tier]
                table.insert(list, { name = info.name, id = id, tier = tier, available = info.numAvailable or 0 })
            end
        end

        if #list > 0 then
            return list
        end
    end

    if GetNumTradeSkills and GetTradeSkillInfo then
        for index = 1, GetNumTradeSkills() do
            local name, tier, available = GetTradeSkillInfo(index)

            if name then
                table.insert(list, { name = name, tier = tier, available = available or 0, index = index })
            end
        end
    end

    return list
end

-- The recipe to make now: the best colour the bags can pay for (and the one with most copies possible), or, when the
-- bags can pay for none, the best colour overall. Returns name, tier, copies you can make, its position in the list.
function Goals:ReadBestRecipe()
    local bestPayable, bestAny

    for _, entry in ipairs(self:ReadRecipes()) do
        local rank = TIER_ORDER[entry.tier]

        if rank then
            entry.rank = rank

            if entry.available > 0 and (not bestPayable or rank < bestPayable.rank
                or (rank == bestPayable.rank and entry.available > bestPayable.available)) then
                bestPayable = entry
            end

            if not bestAny or rank < bestAny.rank then
                bestAny = entry
            end
        end
    end

    local pick = bestPayable or bestAny

    if not pick then
        return nil
    end

    return pick.name, pick.tier, pick.available, pick.index
end

-- The recipe lists (see the top of this file) ---------------------------------------------------------------------------
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)

        if ok and type(name) == "string" then
            return name
        end
    end

    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)

        if ok and type(name) == "string" then
            return name
        end
    end
end

-- Remembers what the open vendor sells for plain gold, in unlimited stock, among the items of the recipe data (reagents and
-- recipe books). This is how the plan learns that a vendor sells something: the data itself says nothing about vendors.
function Goals:RecordMerchant()
    if not (GetMerchantNumItems and GetMerchantItemInfo and GetMerchantItemLink and SN.RecipeData and SN.RecipeData.items) then
        return
    end

    local seen, changed = self:GetVendorSeen(), false

    for index = 1, GetMerchantNumItems() or 0 do
        local link = GetMerchantItemLink(index)
        local itemID = type(link) == "string" and tonumber(string.match(link, "item:(%d+)"))
        local _, _, price, quantity, available, _, _, extended = GetMerchantItemInfo(index)

        if itemID and SN.RecipeData.items[itemID] and type(price) == "number" and price > 0 and not extended
            and available == -1 then
            local unit = price / math.max(1, tonumber(quantity) or 1)

            if seen[itemID] ~= unit then
                seen[itemID], changed = unit, true
            end
        end
    end

    if changed then
        self.planCache = nil
    end
end

Goals.SpellName, Goals.TIER_NAMES = SpellName, TIER_NAMES
