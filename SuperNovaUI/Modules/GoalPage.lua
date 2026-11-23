local addonName, SN = ...

--[[
    Profession goal: the settings page.

    One pair of boxes (target level, recipe name) for every profession the player has, and the button that confirms a save.
]]

local Goals = SN.ProfessionGoal
local L = Goals.L

local LEVEL_BOX_WIDTH, BOX_HEIGHT, LEVEL_MAX_DIGITS = 120, 34, 3
local SAVE_BUTTON_WIDTH, FIND_BUTTON_WIDTH = 260, 220

-- A short confirmation on the button itself ------------------------------------------------------------------------------
-- The button turns green and says "Saved!", then fades back, so a click never feels like it did nothing. A second click
-- while it runs starts it over.

local FLASH_STEPS, FLASH_STEP_SECONDS, FLASH_HOLD_SECONDS = 10, 0.06, 0.9
local FLASH_GREEN = { 0.12, 0.42, 0.24 }

local function PaintButton(button, fill, border)
    if button.SetBackdropColor then
        button:SetBackdropColor(fill[1], fill[2], fill[3], 1)
        button:SetBackdropBorderColor(unpack(border))
    end
end

local function BlendedColor(from, to, amount)
    return {
        from[1] + (to[1] - from[1]) * amount,
        from[2] + (to[2] - from[2]) * amount,
        from[3] + (to[3] - from[3]) * amount,
    }
end

local function RestoreButton(button)
    local colors = SN.Widgets.colors

    button.label:SetText(button.flashText)
    button.label:SetTextColor(unpack(colors.text))
    button.flashText = nil
    PaintButton(button, colors.panel, colors.border)
end

local function Flash(button, doneText)
    if not button or not button.label then
        return
    end

    local colors = SN.Widgets.colors
    button.flashText = button.flashText or button.label:GetText()
    button.flashToken = (button.flashToken or 0) + 1
    local token = button.flashToken

    button.label:SetText(doneText)
    button.label:SetTextColor(unpack(colors.good))
    PaintButton(button, FLASH_GREEN, colors.good)

    local function FadeStep(number)
        if token ~= button.flashToken then
            return -- another click started a new run
        end

        if number > FLASH_STEPS then
            RestoreButton(button)
            return
        end

        if button.SetBackdropColor then
            local fill = BlendedColor(FLASH_GREEN, colors.panel, number / FLASH_STEPS)
            button:SetBackdropColor(fill[1], fill[2], fill[3], 1)
        end

        C_Timer.After(FLASH_STEP_SECONDS, function()
            FadeStep(number + 1)
        end)
    end

    C_Timer.After(FLASH_HOLD_SECONDS, function()
        FadeStep(1)
    end)
end

-- The page ------------------------------------------------------------------------------------------------------------

-- The names of every profession to show, in the game's language now, sorted. Everything is saved under the key of each one.
local function ProfessionNames(module)
    local seen, goals = module:GetSeen(), module:GetGoals()
    local keys, names = {}, {}

    for name, maxSkill in pairs(module:ReadKnownProfessions()) do
        local key = module:KeyOf(name)

        if not module:HasProfessionTiers() and seen[key] == nil then
            seen[key] = maxSkill
        end
    end

    for key in pairs(seen) do
        keys[key] = true
    end

    for key in pairs(goals) do
        keys[key] = true
    end

    for key in pairs(keys) do
        table.insert(names, module:NameOf(key))
    end

    table.sort(names)
    return names
end

local function ShowMessage(message, text, color)
    message:SetText(text)
    message:SetTextColor(unpack(color))
end

local function SaveFailureText(module, profession, why)
    if why == "recipe" and module:HasRecipeData() then
        return L("No WoW Forever recipe has that name. Check the spelling (any part of the name works).",
            "Nenhuma receita do WoW Forever tem esse nome. Confira a escrita (qualquer parte do nome serve).")
    elseif why == "recipe" then
        return L("That recipe is not in sight. Open a vendor that sells it, or put the recipe in your bags, and try again.",
            "Essa receita não está à vista. Abra um vendedor que a venda, ou ponha a receita nas bolsas, e tente de novo.")
    end

    local lowest, highest = module:GetLevelRange(profession)
    return string.format(L("The target level takes only a number from %d to %d (for %s).",
        "O nível desejado aceita só um número de %d a %d (em %s)."), lowest, highest, profession)
end

local function BuildLevelBox(parent, flow, goal)
    local W = SN.Widgets
    local box, edit = W.MultiLineBox(parent, LEVEL_BOX_WIDTH, BOX_HEIGHT)

    edit:SetNumeric(true) -- the game itself refuses anything but digits here
    edit:SetMaxLetters(LEVEL_MAX_DIGITS)
    edit:SetText(goal.level and tostring(goal.level) or "")
    flow:Text(L("Target level", "Nível desejado"), W.colors.text, "GameFontNormal")
    flow:Add(box, BOX_HEIGHT, 6)
    return edit
end

local function BuildRecipeBox(parent, flow, goal)
    local W = SN.Widgets
    local box, edit = W.MultiLineBox(parent, flow.width, BOX_HEIGHT)

    edit:SetText(goal.label or "")
    flow:Text(L("Recipe name", "Nome da receita"), W.colors.text, "GameFontNormal")
    flow:Add(box, BOX_HEIGHT, 6)
    return edit
end

local function FindLevelOfRecipe(module, recipeName, profession)
    local level, itemName = module:FindListedRecipe(recipeName, profession)

    if level then
        return level, itemName
    end

    local _
    level, _, itemName = module:FindRecipeLevel(recipeName, profession)
    return level, itemName
end

-- The two buttons of a profession: save the goal, and find the level a recipe needs.
local function BuildButtons(module, flow, message, profession, levelEdit, recipeEdit)
    local W = SN.Widgets
    local saveText = L("Save goal", "Salvar meta") .. " - " .. profession
    local findText = L("Find level", "Descobrir nível") .. " - " .. profession
    local row

    local function Save()
        local saved, why = module:SetGoal(profession, levelEdit:GetText(), recipeEdit:GetText())

        if not saved then
            ShowMessage(message, SaveFailureText(module, profession, why), W.colors.bad)
            return
        end

        local goal = module:GetGoals()[module:KeyOf(profession)]
        levelEdit:SetText(goal and tostring(goal.level) or "")
        message:SetText("")
        Flash(row[saveText], L("Saved!", "Salvo!"))
    end

    local function FindLevel()
        local level, itemName = FindLevelOfRecipe(module, recipeEdit:GetText(), profession)

        if not level then
            ShowMessage(message, L("That recipe is not in sight. Open a vendor that sells it, or put the recipe in your bags, and press again.",
                "Essa receita não está à vista. Abra um vendedor que a venda, ou ponha a receita nas bolsas, e clique de novo."),
                W.colors.muted)
            return
        end

        levelEdit:SetText(tostring(level))
        ShowMessage(message, string.format(L("%s needs %s %d. Press Save goal to keep it.", "%s exige %s %d. Clique em Salvar meta para guardar."),
            itemName, profession, level), W.colors.good)
    end

    row = flow:Buttons({
        { text = saveText, width = SAVE_BUTTON_WIDTH, onClick = Save },
        { text = findText, width = FIND_BUTTON_WIDTH, onClick = FindLevel },
    })
end

local function BuildProfessionCard(module, flow, message, profession)
    local goal = module:GetGoals()[module:KeyOf(profession)] or {}
    flow:Header(profession)

    local levelEdit = BuildLevelBox(flow.parent, flow, goal)
    local recipeEdit = BuildRecipeBox(flow.parent, flow, goal)
    BuildButtons(module, flow, message, profession, levelEdit, recipeEdit)
end

local function PageIntro(module)
    if module:HasRecipeData() then
        return L("Your professions show up here (if one is missing, open its window once). Type the level you want to reach, or only the recipe name and the level is found for you. The recipe name must be one of the WoW Forever recipes (type any part of its name). Leave both empty to remove the goal.",
            "Suas profissões aparecem aqui (se faltar alguma, abra a janela dela uma vez). Digite o nível que você quer alcançar, ou só o nome da receita que o nível é descoberto para você. O nome da receita precisa ser uma das receitas do WoW Forever (digite qualquer parte do nome). Deixe os dois vazios para remover a meta.")
    end

    return L("Open the window of each profession (and of each expansion's level of it) once and it shows up here. Type the level you want to reach, or only the name of a recipe that is in a vendor window or in your bags and the level is found for you. Leave both empty to remove the goal.",
        "Abra uma vez a janela de cada profissão (e de cada nível de expansão dela) e ela aparece aqui. Digite o nível que você quer alcançar, ou só o nome de uma receita que esteja na janela de um vendedor ou nas bolsas que o nível é descoberto para você. Deixe os dois vazios para remover a meta.")
end

-- The page: one pair of boxes (target level, recipe name) for every profession the player has opened.
local function BuildPage(module, flow)
    local W = SN.Widgets

    SN:BuildDefaultPage(module.name, flow)

    local message = W.Text(flow.parent, "GameFontHighlight", "")
    message:SetWidth(flow.width)
    message:SetWordWrap(true)

    flow:Header(L("Goals", "Metas"))
    flow:Text(PageIntro(module), W.colors.muted)

    local names = ProfessionNames(module)

    if #names == 0 then
        flow:Text(L("No profession seen yet.", "Nenhuma profissão vista ainda."), W.colors.muted)
    end

    for _, profession in ipairs(names) do
        BuildProfessionCard(module, flow, message, profession)
    end

    flow:Add(message, 30, 10)
    flow:Add(W.NewFrame(flow.parent), 40, 0) -- room at the bottom
end

Goals.BuildPage = BuildPage
