local addonName, SN = ...

--[[
    Profession goal: what to tell the player.

    Builds the summary of the open profession (how far the goal is, the recipe to make now, the cheapest plan) as plain data,
    and the text that the box and the chat command show.

    "Recipe to make now" follows the colours the game itself gives a recipe: orange (optimal) always raises the skill,
    yellow (medium) usually, green (easy) sometimes, grey (trivial) never. The best one is the highest colour that the
    bags can pay for; when none can be paid, the highest colour overall. When a plan with prices exists, its first step
    replaces that suggestion: the cheapest recipe, not the first orange one.
]]

local Goals = SN.ProfessionGoal
local L, Clean, SpellName = Goals.L, Goals.Clean, Goals.SpellName
local TIER_NAMES = Goals.TIER_NAMES
local Plan = SN.GoalPlan -- only where the game has recipe data (WoW Forever)

if Plan then
    Plan.GetSeen = function()
        return Goals:GetVendorSeen()
    end
end

-- The plan ------------------------------------------------------------------------------------------------------------

local function RecipeName(row)
    return SpellName(row[1]) or row[2] or tostring(row[1])
end

-- A recipe is known when its spell id is saved, or (where the game gave no id) its name.
local function KnownRecipePredicate(known)
    return function(row)
        return known[row[1]] == true or known[string.lower(RecipeName(row))] == true
            or (type(row[2]) == "string" and known[string.lower(row[2])] == true)
    end
end

local PLAN_CACHE_SECONDS = 60

-- The plan for a goal, or nil when no list knows the profession. Kept for a minute (prices move slowly, the maths is not free).
function Goals:GetPlan(profession, skill, goal)
    local entry = Plan and self:FindProfessionEntry(profession)

    if not entry then
        return nil
    end

    local cacheKey = table.concat({ profession, math.floor(skill), goal, math.floor(GetTime() / PLAN_CACHE_SECONDS) }, "|")

    if self.planCache and self.planCache.key == cacheKey then
        return self.planCache.plan
    end

    local plan = Plan.Build(entry, skill, goal, KnownRecipePredicate(self:GetKnownRecipes(profession)))
    self.planCache = { key = cacheKey, plan = plan }
    return plan
end

-- The text of a plan ---------------------------------------------------------------------------------------------------

local function AppendAll(lines, more)
    for _, line in ipairs(more) do
        table.insert(lines, line)
    end
end

local function StepText(step)
    local cost = step.cost > 0 and (" ~" .. Plan.Money(step.cost)) or ""
    return string.format("%d-%d: %s x%d%s%s", step.from, step.to or step.from, RecipeName(step.recipe), step.crafts, cost,
        step.partial and " (?)" or "")
end

local function TotalText(plan)
    local text = Plan.Money(plan.total)
    return plan.partial and (text .. " " .. L("(incomplete)", "(incompleto)")) or text
end

local function HeadlineLines(plan)
    local lines = {}

    if plan.stuck then
        table.insert(lines, string.format(L("No known recipe gives points from skill %d: the plan stops there.",
            "Nenhuma receita conhecida dá pontos a partir do nível %d: o plano para aí."), plan.stuck))
    end

    if #plan.steps > 0 then
        table.insert(lines, string.format(L("Cheapest way: about %s in %d crafts.", "Caminho mais barato: cerca de %s em %d fabricações."),
            TotalText(plan), plan.crafts))
    end

    return lines
end

local function BookLines(plan)
    local lines = {}

    for _, book in ipairs(plan.books) do
        table.insert(lines, string.format(L("Buy the recipe %s (~%s).", "Compre a receita %s (~%s)."),
            Plan.ItemName(book.itemID), Plan.Money(book.price)))
    end

    return lines
end

local function StepLines(plan)
    local lines = {}

    for _, step in ipairs(plan.steps) do
        table.insert(lines, StepText(step))
    end

    return lines
end

local function PriceText(itemID)
    local price, source = Plan.PriceOf(itemID)

    if not price then
        return L("price unknown", "preço desconhecido")
    end

    local sourceName = source == "auction" and L("auction", "leilão") or L("vendor", "vendedor")
    return string.format("%s (%s)", Plan.Money(price), sourceName)
end

local function SortedShoppingIds(plan)
    local ids = {}

    for itemID in pairs(plan.shopping) do
        table.insert(ids, itemID)
    end

    table.sort(ids)
    return ids
end

local function ShoppingLines(plan)
    local lines = {}

    for _, itemID in ipairs(SortedShoppingIds(plan)) do
        table.insert(lines, string.format("  %dx %s - %s", plan.shopping[itemID], Plan.ItemName(itemID), PriceText(itemID)))
    end

    return lines
end

local function MissingPriceLines(plan)
    local lines = {}

    if not plan.partial then
        return lines
    end

    table.insert(lines, L("Some items have no price: no vendor was seen selling them and no auction addon has them.",
        "Alguns itens não têm preço: nenhum vendedor visto os vende e nenhum addon de leilão os tem."))

    if not Plan.HasAuctionPrices() then
        table.insert(lines, L("Install Auctionator (or TradeSkillMaster) to include Auction House prices.",
            "Instale o Auctionator (ou o TradeSkillMaster) para incluir os preços do leilão."))
    end

    return lines
end

-- The short text of the box: the headline and the step to take now.
local function ShortPlanLines(plan)
    if not plan then
        return {}
    end

    local lines = HeadlineLines(plan)

    if plan.steps[1] then
        table.insert(lines, L("Now: ", "Agora: ") .. StepText(plan.steps[1]))
    end

    AppendAll(lines, MissingPriceLines(plan))
    return lines
end

-- The whole plan for the chat: books to buy, every step, and the shopping list with prices.
function Goals.FullPlanLines(plan)
    if not plan then
        return {}
    end

    local lines = HeadlineLines(plan)
    AppendAll(lines, BookLines(plan))
    AppendAll(lines, StepLines(plan))
    AppendAll(lines, ShoppingLines(plan))
    AppendAll(lines, MissingPriceLines(plan))
    return lines
end

-- The summary --------------------------------------------------------------------------------------------------------

local function ApplyGoal(summary, goal)
    summary.goal = tonumber(goal.level)
    summary.label = Clean(goal.label)
    summary.missing = math.max(0, summary.goal - summary.rank)
    summary.reached = summary.rank >= summary.goal
    summary.needsHigherRank = summary.goal > summary.maxRank and summary.rank >= summary.maxRank
end

-- Everything the box and the command say, as plain data (so it can be tested without a window).
function Goals:GetSummary()
    local profession, rank, maxRank = self:ReadProfession()

    if not profession then
        return nil
    end

    local summary = { profession = profession, rank = rank, maxRank = maxRank }
    local goal = self:GetGoals()[self:KeyOf(profession)]

    if type(goal) == "table" and tonumber(goal.level) then
        ApplyGoal(summary, goal)
    end

    if not summary.reached then
        summary.recipe, summary.tier, summary.available, summary.recipeIndex = self:ReadBestRecipe()

        if summary.goal and not summary.needsHigherRank then
            summary.plan = self:GetPlan(profession, rank, summary.goal)
        end
    end

    return summary
end

-- The text of a summary ------------------------------------------------------------------------------------------------

local function TargetText(summary)
    if summary.label == "" then
        return tostring(summary.goal)
    end

    return summary.label .. " (" .. summary.goal .. ")"
end

local function MakeNowLine(summary)
    local tierName = TIER_NAMES[summary.tier] and SN:Loc(TIER_NAMES[summary.tier]) or summary.tier
    local line = string.format(L("Make now: %s (%s).", "Faça agora: %s (%s)."), summary.recipe, tierName)

    if summary.available > 0 then
        return line .. " " .. string.format(L("You can make %d.", "Você pode fazer %d."), summary.available)
    end

    return line .. " " .. L("You are missing materials.", "Faltam materiais.")
end

local function SuggestionLines(summary)
    if summary.needsHigherRank then
        return { L("Your rank stops at " .. summary.maxRank .. ": train the next rank first.",
            "Seu nível de profissão para em " .. summary.maxRank .. ": aprenda o próximo nível no treinador.") }
    end

    if not summary.recipe then
        return { L("No recipe left that raises your level: look for a new one at a trainer or vendor.",
            "Nenhuma receita sobe mais o nível: procure uma nova no treinador ou em um vendedor.") }
    end

    if summary.plan and summary.plan.steps[1] then
        return {} -- the plan names the first step, chosen by price
    end

    return { MakeNowLine(summary) }
end

function Goals.Describe(summary)
    local target = TargetText(summary)

    if summary.reached then
        return L("Goal reached: ", "Meta alcançada: ") .. target
    end

    local lines = { string.format(L("%s: %d of %d for the goal %s, %d to go.", "%s: %d de %d para a meta %s, faltam %d."),
        summary.profession, summary.rank, summary.goal, target, summary.missing) }

    AppendAll(lines, SuggestionLines(summary))
    AppendAll(lines, ShortPlanLines(summary.plan))
    return table.concat(lines, "\n")
end
