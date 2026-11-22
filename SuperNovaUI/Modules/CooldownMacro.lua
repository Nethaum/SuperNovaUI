local addonName, SN = ...

--[[
    Macro by cooldown.

    A macro cannot ask "is this spell on cooldown?". This module can: it watches one spell and keeps one macro in step
    with it. While the spell is ready the macro holds the "ready" text; while it is on cooldown the macro holds the
    "cooldown" text. The player keeps a single button on the bar.

    Example (druid, WoW Forever): watch the racial "Sky Vision". Ready: cast it. On cooldown: shift into Cat Form and
    use Dash. When the racial comes back, the same button casts it again.

    Limits that come from the game, not from this module:
    - a macro can only be changed outside combat (EditMacro and CreateMacro are blocked in combat), so a change that
      happens during a fight is applied the moment the fight ends;
    - in Retail 12 the cooldown values can be hidden from addons in combat; then the macro is left as it is.

    The cooldown of a spell is told apart from the global cooldown: anything of 1.5 s or less is ignored.
]]

local CooldownMacro = {
    running = false, -- the module is on: it listens to the game and edits the macro
    loaded = false,  -- the game has loaded the character's macros (PLAYER_ENTERING_WORLD); before that GetMacroIndexByName finds nothing
    state = nil,     -- "ready" or "cooldown": the text the macro holds right now
    blocked = false, -- a change is waiting for the player to leave combat
    problem = nil,   -- why the last attempt did nothing ("unset", "unknown", "limit", "failed")
}

local GLOBAL_COOLDOWN = 1.5
local END_MARGIN = 0.2 -- seconds after the expected end, so the game has really finished it when it is looked at
local DEFAULT_MACRO_NAME = "SNUI Cooldown"
local ICON = "INV_MISC_QUESTIONMARK"
local ICON_ID = 134400 -- the same question mark, as a file id

-- The example uses spell ids, so the macro gets the names in the player's own language.
local EXAMPLE = { watched = 1259686, dash = 1850, cat = 768 }

local function GetSpellName(spell)
    local id = tonumber(spell)

    if not id then
        return spell
    end

    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id)
    end

    if GetSpellInfo then
        return (GetSpellInfo(id))
    end
end

-- true: on cooldown, false: ready, nil: cannot be told (not learned, or the game hides the numbers).
-- Second value, when on cooldown: the moment it ends (GetTime() clock), from the start and duration the game reports, so
-- talents and changes Blizzard makes to a cooldown are already in it. No duration is ever written into this addon.
local function ReadCooldown(spell)
    local start, duration

    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spell)

        if not info then
            return nil
        end

        start, duration = info.startTime, info.duration
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(spell)
    else
        return nil
    end

    -- comparing a hidden ("secret") number raises an error: that simply means "cannot be told"
    local ok, result, readyAt = pcall(function()
        if type(start) ~= "number" or type(duration) ~= "number" then
            return nil
        end

        if start == 0 or duration == 0 then
            return false
        end

        if duration > GLOBAL_COOLDOWN then
            return true, start + duration
        end

        return false
    end)

    if not ok then
        return nil
    end

    return result, readyAt
end

local function Clean(text)
    return (tostring(text or ""):gsub("[\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

function CooldownMacro:GetConfig()
    local settings = SN:GetModuleSettings(self.name) or {}

    return {
        spell = Clean(settings.spell),
        macroName = Clean(settings.macroName) ~= "" and Clean(settings.macroName) or DEFAULT_MACRO_NAME,
        readyText = settings.readyText or "",
        cooldownText = settings.cooldownText or "",
    }
end

function CooldownMacro:IsConfigured()
    local config = self:GetConfig()
    return config.spell ~= "" and config.readyText ~= "" and config.cooldownText ~= ""
end

-- Writes the text into the macro (creating the macro for this character when it does not exist).
function CooldownMacro:Write(macroName, body)
    self.problem = nil
    self.errorText = nil

    local index = GetMacroIndexByName(macroName)
    local ok, result

    if index and index > 0 then
        if GetMacroBody(index) == body then
            return true
        end

        ok, result = pcall(EditMacro, index, macroName, nil, body)
    else
        -- the icon is a name in some clients and a number in others: try both
        ok, result = pcall(CreateMacro, macroName, ICON, body, true)

        if not ok then
            ok, result = pcall(CreateMacro, macroName, ICON_ID, body, true)
        end
    end

    if not ok then
        -- "no room" only when the game refused and the character really is at the game's limit (the limit differs
        -- between game versions, so it is read from the game and never assumed)
        local _, perCharacter = GetNumMacros()
        local limit = MAX_CHARACTER_MACROS

        if not (index and index > 0) and limit and perCharacter >= limit then
            self.problem = "limit"
        else
            self.problem = "failed"
        end

        self.errorText = tostring(result)
        return false
    end

    return true
end

-- The game says when a cooldown starts or changes (SPELL_UPDATE_COOLDOWN) but not when it ends. So the end that the game
-- reported (start + duration) is remembered and one look is scheduled for that moment. If the cooldown was changed meanwhile
-- (a talent, a reset, a patch that changed it) the game reports it, the end moves and the look moves with it.
function CooldownMacro:WatchEnd(readyAt)
    if readyAt and self.watching and math.abs(self.watching - readyAt) < 0.05 then
        return -- already waiting for this very moment
    end

    self.watchToken = (self.watchToken or 0) + 1 -- a look scheduled earlier no longer counts
    self.watching = readyAt

    if not readyAt then
        return
    end

    local token = self.watchToken
    C_Timer.After(math.max(readyAt - GetTime(), 0) + END_MARGIN, function()
        if token == CooldownMacro.watchToken then
            CooldownMacro.watching = nil
            CooldownMacro:Update()
        end
    end)
end

-- Looks at the spell and updates the macro when its state changed. "force" rewrites even if nothing changed.
function CooldownMacro:Update(force)
    if not self.running or not self.loaded then
        return
    end

    if not self:IsConfigured() then
        self.problem = "unset"
        return
    end

    local config = self:GetConfig()
    local onCooldown, readyAt = ReadCooldown(GetSpellName(config.spell) or config.spell)

    if onCooldown == nil then
        self.problem = "unknown"
        return
    end

    self:WatchEnd(onCooldown and readyAt or nil)

    local state = onCooldown and "cooldown" or "ready"

    if state == self.state and not self.blocked and not force then
        self.problem = nil
        return
    end

    if InCombatLockdown() then
        self.blocked = true
        return
    end

    local body = state == "ready" and config.readyText or config.cooldownText

    if self:Write(config.macroName, body) then
        self.state = state
        self.blocked = false
        self.problem = nil
        SN:Debug(self.name, "macro " .. config.macroName .. " -> " .. state)
    else
        self.problem = self.problem or "failed"
        SN:Debug(self.name, "could not write the macro: " .. tostring(self.errorText or self.problem))
    end

    SN:NotifyChange()
end

function CooldownMacro:Listen(on)
    if not self.frame then
        local frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" then
                CooldownMacro.loaded = true
            end

            CooldownMacro:Update()
        end)

        self.frame = frame
    end

    for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }) do
        if on then
            self.frame:RegisterEvent(event)
        else
            self.frame:UnregisterEvent(event)
        end
    end
end

function CooldownMacro:SetEnabled(enabled)
    self.running = enabled
    self:Listen(enabled)

    if enabled then
        self.state = nil
        self:Update(true)
    else
        self:WatchEnd(nil)
    end
end

function CooldownMacro:Initialize()
    self:SetEnabled(true)
end

function CooldownMacro:OnOptionChanged()
    self.state = nil
    self:Update(true)
end

-- Saves what the player typed and applies it at once.
function CooldownMacro:Save(values)
    local settings = SN:GetModuleSettings(self.name)

    if not settings then
        return
    end

    settings.spell = Clean(values.spell)
    settings.macroName = Clean(values.macroName)
    settings.readyText = values.readyText or ""
    settings.cooldownText = values.cooldownText or ""

    -- Setting it up shows the player wants it: a module that was off only because it had nothing to do turns on.
    if self:IsConfigured() and not settings.chosen and not SN:IsModuleEnabled(self.name) then
        SN:SetModuleEnabled(self.name, true, true)
    end

    self.state = nil
    self:Update(true)
end

-- The druid example, written in the player's language. Returns nil when the game does not know those spells.
function CooldownMacro:GetExample()
    local watched, dash, cat = GetSpellName(EXAMPLE.watched), GetSpellName(EXAMPLE.dash), GetSpellName(EXAMPLE.cat)

    if not (watched and dash and cat) then
        return nil
    end

    return {
        spell = watched,
        macroName = DEFAULT_MACRO_NAME,
        readyText = "#showtooltip\n/cast " .. watched,
        cooldownText = "#showtooltip\n/cast [form:3] " .. dash .. "\n/cast [noform:3] " .. cat,
    }
end

local PROBLEMS = {
    unset = { enUS = "choose the spell and both texts", ptBR = "escolha o feitiço e os dois textos" },
    unknown = { enUS = "the spell was not found or its cooldown cannot be read", ptBR = "o feitiço não foi encontrado ou a recarga não pode ser lida" },
    limit = { enUS = "no room for another character macro", ptBR = "não há espaço para outra macro do personagem" },
    failed = { enUS = "the game did not accept the macro change", ptBR = "o jogo não aceitou a mudança na macro" },
}

local STATES = {
    ready = { enUS = "spell ready", ptBR = "feitiço pronto" },
    cooldown = { enUS = "spell on cooldown", ptBR = "feitiço em recarga" },
}

function CooldownMacro:PrintStatus()
    local settings = SN:GetModuleSettings(self.name)

    if settings and settings.enabled == false then
        SN:Print(SN:Loc({ enUS = "Macro by cooldown: disabled.", ptBR = "Macro por recarga: desativado." }))
        return
    end

    self:Update(true)
    local config = self:GetConfig()

    if self.problem then
        SN:Print(SN:Loc({ enUS = "Macro by cooldown: ", ptBR = "Macro por recarga: " }) .. SN:Loc(PROBLEMS[self.problem]) .. ".")
    else
        SN:Print(string.format("%s [%s]: %s", SN:Loc({ enUS = "Macro by cooldown", ptBR = "Macro por recarga" }),
            config.macroName, SN:Loc(STATES[self.state] or STATES.ready)))
    end
end

function CooldownMacro:HandleCommand()
    self:PrintStatus()
end

local function L(enUS, ptBR)
    return SN:Loc({ enUS = enUS, ptBR = ptBR })
end

-- The settings part of the page: the spell, the macro name and the two texts.
local function BuildPage(module, flow)
    local W = SN.Widgets
    local parent = flow.parent
    local width = flow.width
    local settings = SN:GetModuleSettings(module.name) or {}

    SN:BuildDefaultPage(module.name, flow)

    local message = W.Text(parent, "GameFontHighlight", "")
    message:SetWidth(width)
    message:SetWordWrap(true)

    local function Say(text, color)
        message:SetText(text)
        message:SetTextColor(unpack(color or W.colors.text))
    end

    -- the edit boxes are drawn below, but the buttons and the message come first so they are always in view
    local spell, macroName, ready, cooldown

    local function Collect()
        return {
            spell = spell:GetText(),
            macroName = macroName:GetText(),
            readyText = ready:GetText(),
            cooldownText = cooldown:GetText(),
        }
    end

    flow:Header(L("Setup", "Configuração"))

    flow:Buttons({
        {
            text = L("Save and apply", "Salvar e aplicar"),
            width = 200,
            onClick = function()
                module:Save(Collect())

                if module.problem then
                    local text = SN:Loc(PROBLEMS[module.problem]) .. "."

                    if module.errorText then
                        text = text .. "\n" .. module.errorText
                    end

                    Say(text, W.colors.bad)
                else
                    Say(L("Saved. The macro is up to date.", "Salvo. A macro está atualizada."), W.colors.good)
                end
            end,
        },
        {
            text = L("Fill with the druid example", "Preencher com o exemplo do druida"),
            width = 260,
            onClick = function()
                local example = module:GetExample()

                if not example then
                    Say(L("The example needs spells this game version does not have.",
                        "O exemplo usa feitiços que esta versão do jogo não tem."), W.colors.bad)
                    return
                end

                spell:SetText(example.spell)
                macroName:SetText(example.macroName)
                ready:SetText(example.readyText)
                cooldown:SetText(example.cooldownText)
                Say(L("Example filled in. Press Save and apply.", "Exemplo preenchido. Clique em Salvar e aplicar."), W.colors.muted)
            end,
        },
    })

    flow:Add(message, 54, 10)

    local function Field(header, help, height, value)
        flow:Header(header)

        if help ~= "" then
            flow:Text(help, W.colors.muted)
        end

        local box, edit = W.MultiLineBox(parent, width, height)
        edit:SetText(value or "")
        flow:Add(box, height, 10)
        return edit
    end

    spell = Field(L("Spell to watch", "Feitiço a vigiar"),
        L("Name or spell id. Its cooldown decides which text the macro holds.",
            "Nome ou número (id) do feitiço. A recarga dele decide qual texto a macro recebe."),
        34, settings.spell)

    macroName = Field(L("Macro name", "Nome da macro"),
        L("Put this macro on your action bar once. It is created for this character if it does not exist; if a macro with this name exists, its text is replaced.",
            "Coloque esta macro na sua barra uma vez. Ela é criada para este personagem se não existir; se já houver uma macro com este nome, o texto dela é substituído."),
        34, settings.macroName ~= "" and settings.macroName or DEFAULT_MACRO_NAME)

    ready = Field(L("Macro while the spell is ready", "Macro com o feitiço pronto"), "", 90, settings.readyText)
    cooldown = Field(L("Macro while the spell is on cooldown", "Macro com o feitiço em recarga"), "", 90, settings.cooldownText)

    -- In combat -----------------------------------------------------------------------------------------------------
    flow:Header(L("Using it in combat", "Usando em combate"))
    flow:Text(L("The game does not let addons change macros during combat. A cooldown that starts or ends in a fight is only applied when the fight ends (in a raid boss fight, that is after the boss). If you use the spell in combat, use two fixed macros instead, one button each. Their text never changes, so combat does not matter:",
        "O jogo não deixa addons mudarem macros durante o combate. Uma recarga que começa ou termina numa luta só é aplicada quando a luta acaba (numa luta de boss de raide, depois do boss). Se você usa o feitiço em combate, use duas macros fixas, um botão para cada. O texto delas nunca muda, então o combate não atrapalha:"),
        W.colors.muted)

    local example = module:GetExample()
    local spellName = example and example.spell or L("Spell", "Feitiço")
    local fallback = example and example.cooldownText or ("#showtooltip\n/cast [form:3] " .. L("Second spell", "Segundo feitiço"))

    local function Sample(label, text, height)
        flow:Text(label, W.colors.text, "GameFontNormal")
        local box, edit = W.MultiLineBox(parent, width, height)
        edit:SetText(text)
        flow:Add(box, height, 10)
    end

    Sample(L("Button 1: the spell, whenever it is ready", "Botão 1: o feitiço, sempre que estiver pronto"),
        "#showtooltip\n/cast " .. spellName, 44)
    Sample(L("Button 2: the fallback (druid example: Cat Form, then Dash)", "Botão 2: a alternativa (exemplo do druida: Forma de Felino e depois Arremetida)"),
        fallback, 60)

    flow:Add(W.NewFrame(parent), 40, 0) -- room at the bottom
end

CooldownMacro.info = {
    category = "tools",
    kind = "feature",
    order = 1,
    name = { enUS = "Macro by cooldown", ptBR = "Macro por recarga" },
    desc = {
        enUS = "Keeps one macro in step with a spell's cooldown: one text while the spell is ready, another while it recharges. One button, two behaviours, and it switches back by itself.",
        ptBR = "Mantém uma macro de acordo com a recarga de um feitiço: um texto com o feitiço pronto e outro enquanto ele recarrega. Um botão, dois comportamentos, e a macro volta sozinha.",
    },
    help = { "/snui macro - show the state of the macro by cooldown" },
    isUseful = function(module)
        return module:IsConfigured()
    end,
    BuildPage = BuildPage,
    GetStatus = function(module)
        if not module:IsConfigured() then
            return "warning", PROBLEMS.unset
        end

        if module.problem then
            return "warning", PROBLEMS[module.problem]
        end

        if module.state then
            return "active", STATES[module.state]
        end

        return "active"
    end,
}

SN:RegisterModuleDefaults("macro", { enabled = true, spell = "", macroName = "", readyText = "", cooldownText = "" })
SN:RegisterModule("macro", CooldownMacro)
