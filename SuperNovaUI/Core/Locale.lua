local addonName, SN = ...

--[[
    Text. Two languages: English (default) and Brazilian Portuguese. A "localized value" is either a plain string or
    a table { enUS = "...", ptBR = "..." }; SN:Loc() picks the right one. Interface strings live in SN.strings and
    are read with SN:T(key, ...).
]]

local STRINGS = {
    enUS = {
        panel_title = "SuperNovaUI",
        search = "Search modules...",
        no_results = "No module matches your search.",
        kind_core = "General",
        kind_fix = "Addon fix",
        kind_compat = "Compatibility",
        kind_feature = "Feature",
        status_active = "Active",
        status_disabled = "Disabled",
        status_missing = "Addon not installed",
        status_pending = "Reload needed",
        status_warning = "Needs attention",
        enable_module = "Enable this module",
        required_addon = "Required addon: %s",
        required_addon_ok = "installed",
        required_addon_missing = "not installed",
        module_unavailable = "This module only does something when %s is installed.",
        reload_banner = "Some changes only apply after a reload.",
        reload_now = "Reload now",
        reset_module = "Reset to defaults",
        close = "Close",

        general_name = "General",
        general_desc = "SuperNovaUI keeps your addons working after game patches. Each fix or feature is a module you can turn on or off.",
        general_version = "Version %s",
        general_modules = "Modules",
        general_counts = "%d of %d modules are enabled.",
        enable_all = "Enable all",
        disable_all = "Disable all",
        language = "Language",
        language_auto = "Automatic",
        language_en = "English",
        language_pt = "Portuguese (Brazil)",
        ask_again = "Show the welcome question again",
        reset_position = "Reset window position",
        reload_ui = "Reload the interface",

        profile_name = "Profile",
        profile_desc = "Export your module settings to a text and import them on another character, another computer or the other SuperNovaUI addon.",
        profile_export = "Export",
        profile_import = "Import",
        profile_export_help = "Press Export, then copy the text (Ctrl+C).",
        profile_import_help = "Paste a profile text here and press Import.",
        profile_exported = "Profile exported. Copy the text above.",
        profile_imported = "Profile imported: %d module(s) changed.",
        profile_nothing = "Nothing to change: the profile matches your current settings.",
        profile_flavor_warning = "This profile came from another game version. Only the modules that exist here were used.",
        profile_empty = "Paste a profile text first.",
        profile_err_format = "This text is not a SuperNovaUI profile.",
        profile_err_checksum = "The text is damaged or incomplete (checksum does not match).",
        profile_err_data = "The profile could not be read.",
        profile_err_family = "This profile belongs to another addon.",
        profile_err_version = "This profile was made by a newer version. Update SuperNovaUI.",

        debug_name = "Debug",
        debug_desc = "Prints extra information in the chat while modules work. Leave it off unless someone asks you to turn it on.",
        debug_toggle = "Show debug messages",

        welcome_title = "Welcome to SuperNovaUI",
        welcome_text = "Do you want to load all the modules that work with the addons you have installed?",
        welcome_found = "Found %d compatible module(s):",
        welcome_yes = "Yes, load them all",
        welcome_no = "No, I will choose",
        welcome_note = "You can change this any time with /snui.",

        cat_general = "General",
        cat_compat = "Compatibility",
        cat_groups = "Groups and dungeons",
        cat_pets = "Battle pets",
        cat_interface = "Interface",
        cat_tools = "Tools",
    },
    ptBR = {
        panel_title = "SuperNovaUI",
        search = "Buscar módulos...",
        no_results = "Nenhum módulo corresponde à busca.",
        kind_core = "Geral",
        kind_fix = "Correção de addon",
        kind_compat = "Compatibilidade",
        kind_feature = "Recurso",
        status_active = "Ativo",
        status_disabled = "Desativado",
        status_missing = "Addon não instalado",
        status_pending = "Precisa recarregar",
        status_warning = "Precisa de atenção",
        enable_module = "Ativar este módulo",
        required_addon = "Addon necessário: %s",
        required_addon_ok = "instalado",
        required_addon_missing = "não instalado",
        module_unavailable = "Este módulo só faz algo quando o %s está instalado.",
        reload_banner = "Algumas mudanças só valem depois de recarregar.",
        reload_now = "Recarregar agora",
        reset_module = "Restaurar padrões",
        close = "Fechar",

        general_name = "Geral",
        general_desc = "O SuperNovaUI mantém seus addons funcionando depois dos patches do jogo. Cada correção ou recurso é um módulo que você pode ligar ou desligar.",
        general_version = "Versão %s",
        general_modules = "Módulos",
        general_counts = "%d de %d módulos estão ativados.",
        enable_all = "Ativar todos",
        disable_all = "Desativar todos",
        language = "Idioma",
        language_auto = "Automático",
        language_en = "English",
        language_pt = "Português (Brasil)",
        ask_again = "Mostrar de novo a pergunta de boas-vindas",
        reset_position = "Restaurar a posição da janela",
        reload_ui = "Recarregar a interface",

        profile_name = "Perfil",
        profile_desc = "Exporte as configurações dos módulos para um texto e importe em outro personagem, outro computador ou no outro addon SuperNovaUI.",
        profile_export = "Exportar",
        profile_import = "Importar",
        profile_export_help = "Clique em Exportar e copie o texto (Ctrl+C).",
        profile_import_help = "Cole aqui o texto de um perfil e clique em Importar.",
        profile_exported = "Perfil exportado. Copie o texto acima.",
        profile_imported = "Perfil importado: %d módulo(s) alterado(s).",
        profile_nothing = "Nada a mudar: o perfil é igual às suas configurações atuais.",
        profile_flavor_warning = "Este perfil veio de outra versão do jogo. Só os módulos que existem aqui foram usados.",
        profile_empty = "Cole primeiro o texto de um perfil.",
        profile_err_format = "Este texto não é um perfil do SuperNovaUI.",
        profile_err_checksum = "O texto está danificado ou incompleto (a verificação não confere).",
        profile_err_data = "Não foi possível ler o perfil.",
        profile_err_family = "Este perfil pertence a outro addon.",
        profile_err_version = "Este perfil foi feito por uma versão mais nova. Atualize o SuperNovaUI.",

        debug_name = "Depuração",
        debug_desc = "Mostra informações extras no chat enquanto os módulos trabalham. Deixe desligado, a não ser que alguém peça para ligar.",
        debug_toggle = "Mostrar mensagens de depuração",

        welcome_title = "Bem-vindo ao SuperNovaUI",
        welcome_text = "Quer carregar todos os módulos que funcionam com os addons que você tem instalados?",
        welcome_found = "Encontrei %d módulo(s) compatível(is):",
        welcome_yes = "Sim, carregar todos",
        welcome_no = "Não, eu escolho",
        welcome_note = "Você pode mudar isso quando quiser com /snui.",

        cat_general = "Geral",
        cat_compat = "Compatibilidade",
        cat_groups = "Grupos e masmorras",
        cat_pets = "Mascotes de batalha",
        cat_interface = "Interface",
        cat_tools = "Ferramentas",
    },
}

SN.strings = STRINGS
SN.localeKey = "enUS"

local function ClientLocaleKey()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "ptBR" or locale == "ptPT" then
        return "ptBR"
    end
    return "enUS"
end

-- language: "auto", "enUS" or "ptBR" (the saved choice).
function SN:UpdateLocale(language)
    if language == "enUS" or language == "ptBR" then
        self.localeKey = language
    else
        self.localeKey = ClientLocaleKey()
    end
end

function SN:Loc(value)
    if type(value) == "table" then
        return value[self.localeKey] or value.enUS or ""
    end
    return value or ""
end

function SN:T(key, ...)
    local text = (STRINGS[self.localeKey] and STRINGS[self.localeKey][key]) or STRINGS.enUS[key] or key
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

SN:UpdateLocale("auto")
