local addonName, SN = ...

--[[
    Game functions: the switch for the shims that the companion addon !SuperNovaUI_Compat defines.

    The companion loads before everything else (so other addons find the functions while they load) and reads its own
    saved variable, SuperNovaUICompatDB, before this addon exists. This module writes the player's choice there; a change
    therefore applies after a reload.
]]

local COMPANION = "!SuperNovaUI_Compat"

local Shims = {}

local function Companion()
    return _G.SuperNovaUICompat
end

local function Describe(shim)
    local state
    if shim.disabled then
        state = { enUS = "turned off", ptBR = "desligado" }
    elseif shim.active then
        state = { enUS = "restored", ptBR = "restaurado" }
    else
        state = { enUS = "not needed (the game or another addon already provides it)", ptBR = "não precisa (o jogo ou outro addon já fornece)" }
    end

    return { enUS = shim.description .. " - " .. state.enUS, ptBR = shim.description .. " - " .. state.ptBR }
end

local function BuildOptions()
    local options = {
        { type = "header", text = { enUS = "Functions this module restores", ptBR = "Funções que este módulo restaura" } },
    }

    local companion = Companion()
    local states = companion and companion:GetShimStates() or {}

    for _, shim in ipairs(states) do
        table.insert(options, { type = "text", text = Describe(shim) })
    end

    if #states == 0 then
        table.insert(options, { type = "text", text = { enUS = "The companion addon is not loaded.", ptBR = "O addon de apoio não está carregado." } })
    end

    return options
end

function Shims:OnToggled(enabled)
    _G.SuperNovaUICompatDB = _G.SuperNovaUICompatDB or {}
    _G.SuperNovaUICompatDB.disabled = not enabled or nil
end

-- Keeps the companion's saved choice in line with this addon's (they are saved separately).
function Shims:Initialize()
    self:OnToggled(SN:IsModuleEnabled(self.name))
end

Shims.info = {
    category = "compat",
    kind = "compat",
    requiresAddon = COMPANION,
    order = 2,
    name = { enUS = "Game functions", ptBR = "Funções do jogo" },
    desc = {
        enUS = "Restores functions that Blizzard removed in recent patches but other addons still call (MouseIsOver, item functions, battle pet constants). Changes apply after a reload.",
        ptBR = "Restaura funções que a Blizzard removeu em patches recentes, mas que outros addons ainda chamam (MouseIsOver, funções de itens, constantes de mascotes). As mudanças valem depois de recarregar.",
    },
    options = BuildOptions(),
    GetStatus = function()
        local companion = Companion()
        local states = companion and companion:GetShimStates() or {}
        local active = 0

        for _, shim in ipairs(states) do
            if shim.active then
                active = active + 1
            end
        end

        return "active", {
            enUS = string.format("%d of %d restored", active, #states),
            ptBR = string.format("%d de %d restauradas", active, #states),
        }
    end,
}

SN:RegisterModuleDefaults("shims", { enabled = true })
SN:RegisterModule("shims", Shims)
