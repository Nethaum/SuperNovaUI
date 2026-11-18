local addonName, SN = ...

--[[
    The pages every SuperNovaUI addon has, in the "General" category: General (modules on/off, language), Profile
    (export and import) and Debug. They are modules of kind "core": they show in the tree but have no on/off switch.
]]

local W = SN.Widgets


-- General ----------------------------------------------------------------------------------------------------------

local General = {}

General.info = {
    category = "general",
    kind = "core",
    order = 1,
    name = { enUS = "General", ptBR = "Geral" },
    desc = { enUS = "Modules and language.", ptBR = "Módulos e idioma." },
}

function General.info.BuildPage(module, flow)
    local parent = flow.parent

    flow:Add(W.Text(parent, "GameFontNormalHuge", SN:T("general_name")), 28, 4)
    flow:Add(W.Text(parent, "GameFontHighlight", SN:T("general_version", SN.version), W.colors.muted), 16, 10)
    flow:Text(SN:T("general_desc"), W.colors.muted)

    flow:Header(SN:T("general_modules"))
    local counts = W.Text(parent, "GameFontHighlight", "")
    flow:Add(counts, 16, 10, function()
        counts:SetText(SN:T("general_counts", SN:CountEnabledModules()))
    end)
    flow:Buttons({
        {
            text = SN:T("enable_all"),
            width = 170,
            onClick = function()
                SN:SetAllEnabled(true)
            end,
        },
        {
            text = SN:T("disable_all"),
            width = 170,
            onClick = function()
                SN:SetAllEnabled(false)
            end,
        },
    })
    flow:Buttons({
        {
            text = SN:T("ask_again"),
            width = 340,
            onClick = function()
                SN:AskFirstRunAgain()
            end,
        },
    })

    flow:Header(SN:T("language"))
    flow:Add(W.Choice(parent, {
        { value = "auto", text = SN:T("language_auto") },
        { value = "enUS", text = SN:T("language_en") },
        { value = "ptBR", text = SN:T("language_pt") },
    }, function()
        return SN.db.language
    end, function(value)
        SN.db.language = value
        SN:UpdateLocale(value)
        SN:RebuildPanel()
    end), 24)

    flow:Buttons({
        {
            text = SN:T("reset_position"),
            width = 240,
            onClick = function()
                SN:ResetPanelPosition()
            end,
        },
        {
            text = SN:T("reload_ui"),
            width = 220,
            onClick = function()
                ReloadUI()
            end,
        },
    })
end

SN:RegisterModule("general", General)

-- Profile ----------------------------------------------------------------------------------------------------------

local Profile = {}

Profile.info = {
    category = "general",
    kind = "core",
    order = 2,
    name = { enUS = "Profile", ptBR = "Perfil" },
    desc = { enUS = "Export and import your module settings.", ptBR = "Exporte e importe as configurações dos módulos." },
}

function Profile.info.BuildPage(module, flow)
    local parent = flow.parent
    local width = flow.width

    flow:Add(W.Text(parent, "GameFontNormalHuge", SN:T("profile_name")), 28, 4)
    flow:Text(SN:T("profile_desc"), W.colors.muted)

    local message = W.Text(parent, "GameFontHighlight", "")
    local function Say(text, color)
        message:SetText(text)
        message:SetTextColor(unpack(color or W.colors.text))
    end

    flow:Header(SN:T("profile_export"))
    flow:Text(SN:T("profile_export_help"), W.colors.muted)
    local exportBox, exportEdit = W.MultiLineBox(parent, width, 90)
    flow:Add(exportBox, 90, 8)
    flow:Buttons({ {
        text = SN:T("profile_export"),
        width = 160,
        onClick = function()
            exportEdit:SetText(SN:ExportProfile())
            exportEdit:SetFocus()
            exportEdit:HighlightText()
            Say(SN:T("profile_exported"), W.colors.good)
        end,
    } })

    flow:Header(SN:T("profile_import"))
    flow:Text(SN:T("profile_import_help"), W.colors.muted)
    local importBox, importEdit = W.MultiLineBox(parent, width, 90)
    flow:Add(importBox, 90, 8)
    flow:Buttons({ {
        text = SN:T("profile_import"),
        width = 160,
        onClick = function()
            local ok, data = SN:ReadProfile(importEdit:GetText())

            if not ok then
                Say(SN:T(data), W.colors.bad)
                return
            end

            local plan, otherFlavor = SN:PlanProfileImport(data)

            if #plan == 0 then
                Say(SN:T("profile_nothing"), W.colors.muted)
                return
            end

            SN:ApplyProfileImport(plan)
            local text = SN:T("profile_imported", #plan)

            if otherFlavor then
                text = text .. "\n" .. SN:T("profile_flavor_warning")
            end

            Say(text, W.colors.good)
        end,
    } })

    message:SetWidth(width)
    message:SetWordWrap(true)
    flow:Add(message, 36, 10)
end

SN:RegisterModule("profile", Profile)

-- Debug ------------------------------------------------------------------------------------------------------------

local Debug = {}

Debug.info = {
    category = "general",
    kind = "core",
    order = 3,
    name = { enUS = "Debug", ptBR = "Depuração" },
    desc = { enUS = "Extra messages in the chat.", ptBR = "Mensagens extras no chat." },
}

function Debug.info.BuildPage(module, flow)
    local parent = flow.parent

    flow:Add(W.Text(parent, "GameFontNormalHuge", SN:T("debug_name")), 28, 4)
    flow:Text(SN:T("debug_desc"), W.colors.muted)
    flow:Add(W.Check(parent, SN:T("debug_toggle"), function()
        return SN.db.debug == true
    end, function(value)
        SN.db.debug = value
    end), 22)
end

SN:RegisterModule("debug", Debug)
