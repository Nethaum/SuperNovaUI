local addonName, SN = ...

local function SplitCommand(message)
    local command, rest = string.match(message or "", "^(%S*)%s*(.-)$")
    return string.lower(command or ""), rest or ""
end

-- Core commands first, then the lines modules list in info.help.
function SN:ShowHelp()
    self:Print("commands:")
    self:Print("/snui - open the panel")
    self:Print("/snui status - show SuperNovaUI status")

    for _, moduleName in ipairs(self.moduleOrder) do
        local info = self:GetInfo(moduleName)

        for _, line in ipairs(info and info.help or {}) do
            self:Print(line)
        end
    end

    self:Print("/snui reload - reload the UI")
end

function SN:ShowStatus()
    self:Print(string.format("%s %s - modules:", self.config.title, tostring(self.version)))

    local listed = 0

    for _, moduleName in ipairs(self.moduleOrder) do
        if self:IsToggleable(moduleName) then
            listed = listed + 1
            local status = self:GetModuleStatus(moduleName)
            self:Print(string.format("- %s: %s", self:GetModuleDisplayName(moduleName), self:GetStatusText(status)))
        end
    end

    if listed == 0 then
        self:Print("- no modules installed")
    end
end

function SN:HandleSlashCommand(message)
    local command, rest = SplitCommand(message)
    local module = self:GetModule(command)

    if module and module.HandleCommand then
        module:HandleCommand((SplitCommand(rest)))
    elseif command == "" or command == "panel" then
        if self.TogglePanel then
            self:TogglePanel()
        else
            self:ShowHelp()
        end
    elseif command == "help" then
        self:ShowHelp()
    elseif command == "status" then
        self:ShowStatus()
    elseif command == "reload" then
        ReloadUI()
    else
        self:Print("unknown command. Use /snui help.")
    end
end

function SN:RegisterSlashCommands()
    for index, command in ipairs(self.config.slashCommands) do
        _G["SLASH_SUPERNOVAUI" .. index] = command
    end

    SlashCmdList.SUPERNOVAUI = function(message)
        SN:HandleSlashCommand(message)
    end
end
