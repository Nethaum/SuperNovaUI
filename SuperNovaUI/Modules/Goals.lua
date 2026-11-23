local addonName, SN = ...

--[[
    Profession goal.

    The player picks a profession and a target level (for example "Cooking 180, to learn a recipe that needs it") and, with
    the profession window open, a small box below it says how far the goal is and what to do next, by the cheapest way.

    The module is made of small files, loaded in this order (see the .toc):
      GoalPlan     the maths of the cheapest path (prices, steps); WoW Forever only, the one with recipe data
      GoalStore    what is saved, per profession id (never the translated name)
      GoalGame     what the game says: the open window, the professions, the recipes, the merchant
      GoalRecipes  the recipe lists, the level a recipe needs, the range a goal may have
      GoalPage     the settings page
      GoalReport   the summary and the text of the box and of the chat
      Goals        this file: the box, the events, saving a goal, the command, the module's registration
]]

local Goals = SN.ProfessionGoal
local L, Clean = Goals.L, Goals.Clean

local BOX_WIDTH, BOX_TEXT_WIDTH, BOX_PADDING = 300, 284, 8
local EVENTS = {
    "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "TRADE_SKILL_CLOSE", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "MERCHANT_SHOW", "MERCHANT_UPDATE",
}

-- The box below the profession window ----------------------------------------------------------------------------------

function Goals:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local W = SN.Widgets
    local anchor = _G.ProfessionsFrame or _G.TradeSkillFrame

    if not anchor then
        return nil
    end

    local frame = W.NewFrame(UIParent)
    frame:SetSize(BOX_WIDTH, 64)
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    W.Backdrop(frame, W.colors.panel, W.colors.border)

    local text = W.Text(frame, "GameFontHighlight", "")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", BOX_PADDING, -BOX_PADDING)
    text:SetWidth(BOX_TEXT_WIDTH)
    text:SetWordWrap(true)

    frame.text = text
    frame:Hide()
    self.frame = frame
    return frame
end

function Goals:HideFrame()
    if self.frame then
        self.frame:Hide()
    end
end

function Goals:ShowSummary(frame, summary)
    frame.text:SetText(Goals.Describe(summary))
    frame:SetHeight(math.max(40, frame.text:GetStringHeight() + 2 * BOX_PADDING))
    frame:Show()
end

-- What was seen -------------------------------------------------------------------------------------------------------

-- The highest level of each profession, from the ones the character has and from the window that is open.
function Goals:RememberSeen(openProfession, openMaxRank)
    local seen = self:GetSeen()

    if not self:HasProfessionTiers() then
        for name, maxSkill in pairs(self:ReadKnownProfessions()) do
            local key = self:KeyOf(name)

            if seen[key] == nil then
                seen[key] = maxSkill
            end
        end
    end

    if not openProfession then
        return
    end

    local key = self:KeyOf(openProfession)

    if seen[key] ~= openMaxRank then
        seen[key] = openMaxRank
        SN:NotifyChange()
    end
end

-- Says it once, in the chat, when the goal is reached.
function Goals:AnnounceWhenReached(summary)
    local goal = self:GetGoals()[self:KeyOf(summary.profession)]

    if summary.reached and not goal.announced then
        goal.announced = true
        SN:Print(Goals.Describe(summary))
    end
end

-- Redraws the box (hidden when there is no goal for the open profession).
function Goals:Update()
    if not self.running then
        return
    end

    local profession, _, maxRank = self:ReadProfession()
    self:RememberSeen(profession, maxRank)

    if profession then
        self:RememberKnownRecipes(profession)
    end

    local summary = self:GetSummary()
    local frame = summary and summary.goal and self:EnsureFrame()

    if not frame then
        self:HideFrame()
        return
    end

    self:ShowSummary(frame, summary)
    self:AnnounceWhenReached(summary)
end

-- Events ---------------------------------------------------------------------------------------------------------------

local function OnEvent(event)
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        Goals:RecordMerchant()
    elseif event == "TRADE_SKILL_CLOSE" then
        Goals:HideFrame()
    else
        Goals:Update()
    end
end

function Goals:Listen(on)
    if not self.listener then
        self.listener = CreateFrame("Frame")
        self.listener:SetScript("OnEvent", function(_, event)
            OnEvent(event)
        end)
    end

    local register = on and self.listener.RegisterEvent or self.listener.UnregisterEvent

    for _, event in ipairs(EVENTS) do
        -- an event this game version does not have raises an error: skip it instead of breaking the switch
        pcall(register, self.listener, event)
    end
end

function Goals:SetEnabled(enabled)
    self.running = enabled
    self:Listen(enabled)

    if enabled then
        self:Update()
    else
        self:HideFrame()
    end
end

function Goals:Initialize()
    self:SetEnabled(true)
end

-- Saving a goal -------------------------------------------------------------------------------------------------------

-- The level the player means: the typed one, or the one the typed recipe needs. Returns the level, or nil and why
-- ("recipe": the game cannot confirm the name; "level": no usable level).
function Goals:ResolveLevel(profession, level, label)
    local number = tonumber(Clean(level))
    local noLevel = Clean(level) == "" or number == 0
    local confirmed, levelOfRecipe = self:CheckRecipeName(label, profession)

    if not confirmed then
        return nil, "recipe"
    end

    if noLevel and levelOfRecipe then
        number, noLevel = levelOfRecipe, false
    end

    if noLevel or not self:IsValidLevel(number, profession) then
        return nil, "level"
    end

    return number
end

function Goals:RemoveGoal(key)
    self:GetGoals()[key] = nil
    self:Update()
    SN:NotifyChange()
end

function Goals:StoreGoal(key, level, label)
    self:GetGoals()[key] = { level = level, label = Clean(label) }

    -- Setting a goal shows the player wants it: a module that was off only because it had nothing to do turns on.
    local settings = SN:GetModuleSettings(self.name)

    if settings and not settings.chosen and not SN:IsModuleEnabled(self.name) then
        SN:SetModuleEnabled(self.name, true, true)
    end

    self:Update()
    SN:NotifyChange()
end

local function IsEmpty(level, label)
    local number = tonumber(Clean(level))
    return (Clean(level) == "" or number == 0) and Clean(label) == ""
end

-- Saves a goal. An empty level and name remove it. A recipe name must be one the game can confirm (CheckRecipeName); when
-- it is, and the level is empty, the level comes from the recipe. Returns true, or false and why ("recipe" or "level").
function Goals:SetGoal(profession, level, label)
    profession = Clean(profession)

    if profession == "" then
        return false, "level"
    end

    local key = self:KeyOf(profession)

    if IsEmpty(level, label) then
        self:RemoveGoal(key)
        return true
    end

    local number, why = self:ResolveLevel(profession, level, label)

    if not number then
        return false, why
    end

    self:StoreGoal(key, number, label)
    return true
end

-- The chat command ----------------------------------------------------------------------------------------------------

local function PrintLines(lines)
    for _, line in ipairs(lines) do
        SN:Print(line)
    end
end

local function PrintPlan(summary)
    if not (summary and summary.goal) then
        SN:Print(L("Open the window of a profession that has a goal, then type /snui goal plan.",
            "Abra a janela de uma profissão que tenha meta e digite /snui goal plan."))
    elseif summary.reached then
        SN:Print(Goals.Describe(summary))
    else
        SN:Print(string.format(L("%s: from %d to %d.", "%s: de %d a %d."), summary.profession, summary.rank, summary.goal))

        local lines = Goals.FullPlanLines(summary.plan)

        if #lines == 0 and not Goals:HasRecipeData() then
            SN:Print(L("The cheapest-way plan is not available in this game version yet.",
                "O plano do caminho mais barato ainda não existe nesta versão do jogo."))
        elseif #lines == 0 then
            SN:Print(L("No recipe list knows this profession.", "Nenhuma lista de receitas conhece esta profissão."))
        end

        PrintLines(lines)
    end
end

function Goals:PrintAllGoals()
    local goals = {}

    for key, goal in pairs(self:GetGoals()) do
        table.insert(goals, string.format("%s: %s", self:NameOf(key), tostring(goal.level)))
    end

    table.sort(goals)

    if #goals == 0 then
        SN:Print(L("Profession goal: no goal set. Set one in Tools > Profession goal.",
            "Meta de profissão: nenhuma meta. Defina uma em Tools > Profession goal."))
        return
    end

    SN:Print(L("Profession goal: ", "Meta de profissão: ") .. table.concat(goals, "; ")
        .. L(". Open the profession window to see how far it is.", ". Abra a janela da profissão para ver o quanto falta."))
end

local function PrintOpenProfession(summary)
    if summary.goal then
        SN:Print(Goals.Describe(summary))
        return
    end

    SN:Print(string.format(L("%s: no goal set for it (level %d of %d).", "%s: sem meta para ela (nível %d de %d)."),
        summary.profession, summary.rank, summary.maxRank))
end

function Goals:HandleCommand(arg)
    local summary = self:GetSummary()

    if arg == "plan" then
        PrintPlan(summary)
    elseif not summary then
        self:PrintAllGoals()
    else
        PrintOpenProfession(summary)
    end
end

-- The module ----------------------------------------------------------------------------------------------------------

Goals.info = {
    category = "tools",
    kind = "feature",
    order = 3,
    name = { enUS = "Profession goal", ptBR = "Meta de profissão" },
    desc = {
        enUS = "Set a target level for any profession. With its window open, a box shows how many points are left and the recipe that raises your level now, using what is in your bags.",
        ptBR = "Defina um nível desejado para qualquer profissão. Com a janela dela aberta, uma caixa mostra quantos pontos faltam e a receita que sobe o seu nível agora, com o que está nas suas bolsas.",
    },
    help = { "/snui goal - how far the goal of the open profession is", "/snui goal plan - the cheapest way to it, with prices and what to buy" },
    isUseful = function(module)
        return module:HasGoal()
    end,
    BuildPage = Goals.BuildPage,
    GetStatus = function(module)
        if not module:HasGoal() then
            return "active", { enUS = "no goal set", ptBR = "nenhuma meta definida" }
        end

        return "active"
    end,
}

SN:RegisterModuleDefaults("goal", { enabled = true })

SN:RegisterModule("goal", Goals)
