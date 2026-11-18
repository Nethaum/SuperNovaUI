local addonName, SN = ...

local Compat = {}

-- toc field written into every addon we patched (see wow-addon-patches)
local PATCH_FIELD = "X-SuperNovaUI-Patch"

--[[
    Addons that need a fix file by file (a shim cannot repair them).
    An addon counts as fixed when its .toc carries X-SuperNovaUI-Patch.
]]
local KNOWN_ADDONS = {
    {
        name = "tdBattlePetScript",
        problem = { enUS = "Original version fails on 12.x: options panel, removed constants and a removed font.", ptBR = "A versão original falha no 12.x: painel de opções, constantes removidas e uma fonte removida." },
    },
    {
        name = "tdBattlePetScript_Rematch",
        problem = { enUS = "Written for Rematch 4. Needs a Rematch 5 version to attach scripts to teams.", ptBR = "Feito para o Rematch 4. Precisa de uma versão para o Rematch 5 para ligar scripts às equipes." },
    },
    {
        name = "RematchElvUISkin",
        problem = { enUS = "Skin for Rematch 4. Does not match the Rematch 5 window.", ptBR = "Skin do Rematch 4. Não combina com a janela do Rematch 5." },
    },
    {
        name = "RematchCelestialTournament",
        problem = { enUS = "Replaces Rematch 4 internals that no longer exist.", ptBR = "Substitui partes internas do Rematch 4 que não existem mais." },
    },
    {
        name = "RematchNextTarget",
        problem = { enUS = "Replaces Rematch 4 internals that no longer exist.", ptBR = "Substitui partes internas do Rematch 4 que não existem mais." },
    },
    {
        name = "Rematch",
        problem = { enUS = "5.3.1 raises an error reading NPC names (secret values, patch 12.1).", ptBR = "A 5.3.1 dá erro ao ler nomes de NPC (valores secretos, patch 12.1)." },
        -- fixed at runtime by the SuperNovaUI module of this name instead of by a patched file
        fixedByModule = "rematch",
    },
}

--[[
    Behaviour tweaks SuperNovaUI applies to other addons at runtime (they are not compatibility
    fixes, so they are listed apart). Each one is a SuperNovaUI module that sets `installed`
    once it hooked the other addon.
]]
local TWEAKS = {
    {
        module = "pgf",
        addon = "PremadeGroupsFilter",
        description = "Premade Groups Filter: Party Fit also hides groups with my class and specialization.",
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

-- The shims live in the companion addon !SuperNovaUI_Compat (it loads first, see its Shims.lua).
-- Returns its list of { name, description, active }, or nil when the companion is not installed.
function Compat:GetShimStates()
    local shared = _G.SuperNovaUICompat
    return shared and shared:GetShimStates() or nil
end

-- tweaks with a state: "active", "disabled", "not hooked" (addon present but not reached) or "not installed"
function Compat:GetTweakStates()
    local states = {}
    for _, tweak in ipairs(TWEAKS) do
        local module = SN:GetModule(tweak.module)
        local settings = SN:GetModuleSettings(tweak.module)
        local state
        if not AddonExists(tweak.addon) then
            state = "not installed"
        elseif settings and settings.enabled == false then
            state = "disabled"
        elseif module and module.installed then
            state = "active"
        else
            state = "not hooked"
        end

        tinsert(states, { name = tweak.module, description = tweak.description, state = state })
    end
    return states
end

-- known addons that are installed, with: fixed (patched), enabled, problem
function Compat:GetAddonStates()
    local states = {}
    for _, known in ipairs(KNOWN_ADDONS) do
        if AddonExists(known.name) then
            local fixed
            if known.fixedByModule then
                local module = SN:GetModule(known.fixedByModule)
                fixed = module ~= nil and module.installed == true
            else
                fixed = GetMetadata(known.name, PATCH_FIELD) ~= nil
            end

            tinsert(states, {
                name = known.name,
                problem = known.problem,
                enabled = IsAddonEnabled(known.name),
                fixed = fixed,
            })
        end
    end
    return states
end

function Compat:PrintStatus()
    local shims = self:GetShimStates()
    if shims then
        SN:Print("Compatibility shims:")
        for _, shim in ipairs(shims) do
            SN:Print(string.format("- %s: %s", shim.description, shim.active and "active (provided by !SuperNovaUI_Compat)" or "not needed (already provided)"))
        end
    else
        SN:Print("Compatibility shims: companion addon !SuperNovaUI_Compat is not installed, so they are inactive.")
    end

    SN:Print("Tweaks:")
    for _, tweak in ipairs(self:GetTweakStates()) do
        SN:Print(string.format("- %s: %s", tweak.description, tweak.state))
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
    else
        SN:OpenPanel(self.name)
    end
end

-- The page: what each known addon needs, and which fixes are built in.
local function Text(english, portuguese)
    return { enUS = english, ptBR = portuguese }
end

local function Hex(color)
    return string.format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

local function BuildPage(module, flow)
    local W = SN.Widgets
    local parent = flow.parent

    flow:Add(W.Text(parent, "GameFontNormalHuge", SN:Loc(module.info.name)), 28, 4)
    flow:Text(SN:Loc(module.info.desc), W.colors.muted)

    flow:Header(SN:Loc(Text("Addons that need a fix", "Addons que precisam de correção")))

    for _, known in ipairs(KNOWN_ADDONS) do
        local row = W.Text(parent, "GameFontHighlight", "")
        flow:Add(row, 16, 2, function()
            local text, color = Text("Not installed", "Não instalado"), W.colors.muted

            for _, state in ipairs(module:GetAddonStates()) do
                if state.name == known.name then
                    if state.fixed then
                        text, color = Text("Fixed", "Corrigido"), W.colors.good
                    else
                        text, color = Text("Needs fix", "Precisa de correção"), W.colors.warn
                    end

                    if not state.enabled then
                        text = Text(SN:Loc(text) .. ", disabled", SN:Loc(text) .. ", desativado")
                    end
                end
            end

            row:SetText(known.name .. "   -   " .. Hex(color) .. SN:Loc(text) .. "|r")
        end)
        flow:Text(SN:Loc(known.problem), W.colors.muted, "GameFontDisableSmall", 12)
    end

    flow:Text(SN:Loc(Text(
        "SuperNovaUI never edits other addons' files. For an addon marked \"Needs fix\", look for an updated version on its page (CurseForge, Wago or its website) or ask its author.",
        "O SuperNovaUI nunca edita os arquivos de outros addons. Para um addon marcado como \"Precisa de correção\", procure uma versão atualizada na página dele (CurseForge, Wago ou o site) ou fale com o autor."
    )), W.colors.muted)

    flow:Header(SN:Loc(Text("Fixes built in", "Correções embutidas")))

    for _, moduleName in ipairs(SN:GetToggleableModules()) do
        local row = W.Text(parent, "GameFontHighlight", "")
        flow:Add(row, 16, 6, function()
            local status, detail = SN:GetModuleStatus(moduleName)
            local text = SN:GetModuleDisplayName(moduleName) .. "   -   " .. SN:ColoredStatus(status)

            if detail then
                text = text .. "   " .. Hex(W.colors.muted) .. "(" .. SN:Loc(detail) .. ")|r"
            end

            row:SetText(text)
        end)
    end
end

Compat.info = {
    category = "compat",
    kind = "core",
    order = 1,
    name = { enUS = "Fix status", ptBR = "Estado das correções" },
    desc = {
        enUS = "Shows which addons have a known problem with this game version and which fixes are built in.",
        ptBR = "Mostra quais addons têm um problema conhecido nesta versão do jogo e quais correções já estão embutidas.",
    },
    BuildPage = BuildPage,
    help = {
        "/snui compat - open the fix status page (addons that need a fix)",
        "/snui compat status - print the compatibility state in the chat",
    },
}

SN:RegisterModuleDefaults("compat", { enabled = true })
SN:RegisterModule("compat", Compat)
