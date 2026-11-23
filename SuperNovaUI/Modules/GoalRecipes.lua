local addonName, SN = ...

--[[
    Profession goal: the recipes and their levels.

    Finds a recipe by the name the player types and says which level it needs: first in the recipe data inside this addon
    (Data/Recipes.lua), then from the recipe item in the vendor window or the bags. Tells which levels a goal may
    have.
]]

local Goals = SN.ProfessionGoal
local Clean, SpellName = Goals.Clean, Goals.SpellName

local function Normalize(text)
    return string.lower(Clean(text))
end

-- What a goal can be: from the skill every profession starts with to the highest one the profession can reach. The top comes
-- from the game's own recipe data (`max` of the profession, 300 in WoW Forever today), so it follows the game; 300 is only the
-- answer when no list knows the profession.
local START_LEVEL, FALLBACK_MAX_LEVEL = 1, 300

-- The professions of the recipe data inside this addon (Data/Recipes.lua); empty when the data is missing.
function Goals:GetProfessions()
    if type(SN.RecipeData) == "table" and type(SN.RecipeData.professions) == "table" then
        return SN.RecipeData.professions
    end

    return {}
end

local function IsProfession(entry, wanted, id)
    return type(entry) == "table" and ((id and entry.id == id) or string.lower(tostring(entry.name)) == wanted)
end

local function ProfessionEntry(professions, wanted, id)
    for _, entry in ipairs(professions) do
        if IsProfession(entry, wanted, id) then
            return entry
        end
    end
end

-- The entry of the recipe data for this profession (matched by its id, else its name); nil when the data lacks it.
function Goals:FindProfessionEntry(profession)
    return ProfessionEntry(self:GetProfessions(), Normalize(profession), self:DataId(profession))
end

-- Is there recipe data inside this addon (WoW Forever only)? Without it the recipes come from the game's own windows.
function Goals:HasRecipeData()
    return next(self:GetProfessions()) ~= nil
end

-- The highest level of the profession: from the recipe data, else from the window the player opened (a tier of Retail has
-- its own top), else the default.
local function HighestLevel(module, profession)
    local entry = module:FindProfessionEntry(profession)
    local fromData = entry and tonumber(entry.max)
    local fromWindow = tonumber(module:GetSeen()[module:KeyOf(profession)])

    return fromData or fromWindow
end

-- The lowest and the highest level a goal for this profession can have.
function Goals:GetLevelRange(profession)
    local highest = HighestLevel(self, profession)

    if highest and highest >= START_LEVEL then
        return START_LEVEL, highest
    end

    return START_LEVEL, FALLBACK_MAX_LEVEL
end

function Goals:IsValidLevel(number, profession)
    local lowest, highest = self:GetLevelRange(profession)
    return type(number) == "number" and number >= lowest and number <= highest and number == math.floor(number)
end

local function SearchList(professions, needle, wanted, id)
    local named = ProfessionEntry(professions, wanted, id) ~= nil

    for _, entry in ipairs(professions) do
        if type(entry) == "table" and type(entry.recipes) == "table"
            and (not named or IsProfession(entry, wanted, id)) then
            for _, row in ipairs(entry.recipes) do
                local localName = type(row) == "table" and type(row[1]) == "number" and SpellName(row[1])
                local english = type(row) == "table" and type(row[2]) == "string" and row[2]

                if (localName and string.find(string.lower(localName), needle, 1, true))
                    or (english and string.find(string.lower(english), needle, 1, true)) then
                    local level = tonumber(row.min)

                    if level then
                        return level, localName or english
                    end
                end
            end
        end
    end
end

-- Finds the recipe by the name the player typed, in the player's language (from the spell id) or in English (the list's
-- own name). Only the recipes of the same profession are searched when the data has it (by id, else by name); otherwise all.
-- Returns the level (`min`) and the recipe's name as the game shows it; nil when the data lacks it.
function Goals:FindListedRecipe(recipeName, profession)
    local needle = Normalize(recipeName)

    if needle == "" then
        return nil
    end

    return SearchList(self:GetProfessions(), needle, Normalize(profession), self:DataId(profession))
end

-- Finding a recipe's level from its name -----------------------------------------------------------------------------
-- A recipe item says what it needs ("Requires Cooking (180)"), but only the item can say it: the profession window does
-- not list recipes the player has not learned. So the item is looked for where the player can see it: the vendor window
-- that is open and the bags. The sentence is the game's own (ITEM_MIN_SKILL), so it works in any language.

local function RequirementPattern()
    local text = ITEM_MIN_SKILL or "Requires %s (%d)"
    text = text:gsub("%%%d%$s", "\1"):gsub("%%%d%$d", "\2"):gsub("%%s", "\1"):gsub("%%d", "\2")
    text = text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    return "^" .. text:gsub("\1", "(.-)"):gsub("\2", "(%%d+)") .. "$"
end

-- The lines of an item's tooltip from the modern tooltip data.
local function DataTooltipLines(link)
    local lines = {}

    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return lines
    end

    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)

    if not (ok and type(data) == "table") then
        return lines
    end

    for _, line in ipairs(data.lines or {}) do
        if TooltipUtil and TooltipUtil.SurfaceArgs then
            pcall(TooltipUtil.SurfaceArgs, line)
        end

        if type(line.leftText) == "string" then
            table.insert(lines, line.leftText)
        end
    end

    return lines
end

-- The lines of an item's tooltip read from a hidden tooltip, where the modern data does not exist.
local function ScannerTooltipLines(link)
    local lines = {}

    pcall(function()
        local tip = Goals.scanner or CreateFrame("GameTooltip", "SNUIGoalScanner", nil, "GameTooltipTemplate")
        Goals.scanner = tip
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:SetHyperlink(link)

        for index = 1, tip:NumLines() do
            local text = _G["SNUIGoalScannerTextLeft" .. index]
            text = text and text:GetText()

            if type(text) == "string" then
                table.insert(lines, text)
            end
        end
    end)

    return lines
end

local function TooltipLines(link)
    local lines = DataTooltipLines(link)

    if #lines == 0 then
        lines = ScannerTooltipLines(link)
    end

    return lines
end

-- "Requires Cooking (180)" in the item's tooltip -> "Cooking", 180.
local function ReadRequirement(link)
    local pattern = RequirementPattern()

    for _, text in ipairs(TooltipLines(link)) do
        local first, second = string.match(text, pattern)

        if first and second then
            if tonumber(first) and not tonumber(second) then
                first, second = second, first
            end

            if tonumber(second) then
                return first, tonumber(second)
            end
        end
    end
end

-- Links of the items in the open vendor window and in the bags.
local function VisibleItemLinks()
    local links = {}

    if GetMerchantNumItems and GetMerchantItemLink then
        for index = 1, GetMerchantNumItems() or 0 do
            table.insert(links, (GetMerchantItemLink(index)))
        end
    end

    local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local getLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink

    if numSlots and getLink then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, numSlots(bag) or 0 do
                table.insert(links, (getLink(bag, slot)))
            end
        end
    end

    return links
end

-- Looks for an item whose name contains the typed recipe name (an item "Recipe: Calcified Smoothie" contains
-- "Calcified Smoothie"). With a profession given, only a recipe for that profession counts.
-- Returns the level, the profession the item names, and the item's name; nil when it is not in sight.
function Goals:FindRecipeLevel(recipeName, profession)
    local needle = Normalize(recipeName)

    if needle == "" then
        return nil
    end

    for _, link in ipairs(VisibleItemLinks()) do
        local itemName = type(link) == "string" and string.match(link, "%[(.-)%]")

        if itemName and string.find(string.lower(itemName), needle, 1, true) then
            local requiredProfession, level = ReadRequirement(link)

            if self:IsValidLevel(level, requiredProfession) and (not profession or self:IsSameProfession(requiredProfession, profession)) then
                return level, requiredProfession, itemName
            end
        end
    end

    return nil
end

-- Is this a recipe the game can confirm right now? Either the recipe data inside this addon has it, or the item is in sight (vendor window, bags), and then its
-- level is known too, or it is a recipe the character already knows (the open profession window lists those).
-- Returns true, level (nil for a known recipe) when confirmed, false otherwise. An empty name is always fine.
function Goals:CheckRecipeName(recipeName, profession)
    local needle = Normalize(recipeName)

    if needle == "" then
        return true
    end

    local listedLevel = self:FindListedRecipe(recipeName, profession)

    if listedLevel then
        return true, listedLevel
    end

    local level = self:FindRecipeLevel(recipeName, profession)

    if level then
        return true, level
    end

    for _, recipe in ipairs(self:ReadRecipes()) do
        if string.find(string.lower(recipe.name), needle, 1, true) then
            return true
        end
    end

    return false
end
