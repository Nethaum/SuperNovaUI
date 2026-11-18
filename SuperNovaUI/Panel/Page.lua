local addonName, SN = ...

--[[
    What a module's page shows when it does not draw its own (info.BuildPage): name, kind and status, description, the
    addon it needs, the on/off switch, its options and a reset button.
]]

local W = SN.Widgets

local function Hex(color)
    return string.format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

local STATUS_COLORS = {
    active = W.colors.good,
    disabled = W.colors.muted,
    missing = W.colors.muted,
    pending = W.colors.warn,
    warning = W.colors.warn,
}

function SN:ColoredStatus(status)
    return Hex(STATUS_COLORS[status] or W.colors.muted) .. self:GetStatusText(status) .. "|r"
end

local function RenderOption(flow, moduleName, option)
    local parent = flow.parent
    local text = SN:Loc(option.text)

    if option.type == "header" then
        flow:Header(text)
    elseif option.type == "text" then
        flow:Text(text, W.colors.muted)
    elseif option.type == "toggle" then
        local check = W.Check(parent, text, function()
            return SN:GetOption(moduleName, option.key) == true
        end, function(value)
            SN:SetOption(moduleName, option.key, value)
        end)
        if option.desc then
            check.tooltip = function()
                return text, { SN:Loc(option.desc) }
            end
        end

        flow:Add(check, 22, option.desc and 2 or 10)

        if option.desc then
            flow:Text(SN:Loc(option.desc), W.colors.muted, "GameFontDisableSmall", 26)
        end
    elseif option.type == "choice" then
        flow:Text(text)
        local values = {}

        for _, entry in ipairs(option.values) do
            table.insert(values, { value = entry.value, text = SN:Loc(entry.text) })
        end

        flow:Add(W.Choice(parent, values, function()
            return SN:GetOption(moduleName, option.key)
        end, function(value)
            SN:SetOption(moduleName, option.key, value)
        end), 24)
    elseif option.type == "slider" then
        flow:Text(text)
        flow:Add(W.Slider(parent, option, function()
            return SN:GetOption(moduleName, option.key)
        end, function(value)
            SN:SetOption(moduleName, option.key, value)
        end), 22)
    elseif option.type == "button" then
        flow:Buttons({ {
            text = text,
            width = option.width or 220,
            onClick = function()
                option.onClick(SN.modules[moduleName])
            end,
        } })
    end
end

function SN:BuildDefaultPage(moduleName, flow)
    local info = self:GetInfo(moduleName)
    local parent = flow.parent

    local title = W.Text(parent, "GameFontNormalHuge", self:GetModuleDisplayName(moduleName))
    flow:Add(title, 28, 4)

    local meta = W.Text(parent, "GameFontHighlight", "")
    flow:Add(meta, 16, 10, function()
        local status, detail = self:GetModuleStatus(moduleName)
        local text = Hex(W.colors.accent) .. self:GetKindText(info.kind) .. "|r   -   " .. self:ColoredStatus(status)

        if detail then
            text = text .. "   " .. Hex(W.colors.muted) .. "(" .. self:Loc(detail) .. ")|r"
        end

        meta:SetText(text)
    end)

    flow:Text(self:Loc(info.desc), W.colors.muted)

    if info.requiresAddon then
        local requirement = W.Text(parent, "GameFontHighlight", "")
        flow:Add(requirement, 16, 10, function()
            local installed = self:IsAddonInstalled(info.requiresAddon)
            local state = self:T(installed and "required_addon_ok" or "required_addon_missing")
            requirement:SetText(self:T("required_addon", info.requiresAddon .. " (" .. state .. ")"))
        end)
    end

    if self:IsToggleable(moduleName) then
        local check = W.Check(parent, self:T("enable_module"), function()
            return self:IsModuleEnabled(moduleName)
        end, function(value)
            self:SetModuleEnabled(moduleName, value)
        end)
        check.tooltip = function()
            return self:T("enable_module"), { self:Loc(info.desc) }
        end
        flow:Add(check, 22, 14)
    end

    for _, option in ipairs(info.options or {}) do
        RenderOption(flow, moduleName, option)
    end

    if self:IsToggleable(moduleName) and info.options and #info.options > 0 then
        flow:Buttons({ {
            text = self:T("reset_module"),
            width = 180,
            onClick = function()
                self:ResetModule(moduleName)
            end,
        } })
    end
end
