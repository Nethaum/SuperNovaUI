local addonName, SN = ...

local HELP_LINES = {
    "commands:",
    "/snui status - show module status",
    "/snui lock - lock frame movement",
    "/snui unlock - unlock frame movement",
    "/snui resetframes - clear saved frame positions",
    "/snui reload - reload the UI",
}

local function SplitCommand(message)
    local command, rest = string.match(message or "", "^(%S*)%s*(.-)$")
    return string.lower(command or ""), rest or ""
end

function SN:ShowHelp()
    for _, line in ipairs(HELP_LINES) do
        self:Print(line)
    end
end

function SN:ShowStatus()
    self:Print("modules:")

    for _, moduleName in ipairs(self.moduleOrder) do
        local settings = self:GetModuleSettings(moduleName)
        local enabled = settings and settings.enabled ~= false
        self:Print(string.format("- %s: %s", moduleName, enabled and "enabled" or "disabled"))
    end

    local frameMover = self:GetModule("frameMover")
    if frameMover and frameMover.PrintStatus then
        frameMover:PrintStatus()
    end
end

function SN:SetFrameMoverLocked(locked)
    local settings = self:GetModuleSettings("frameMover")
    if not settings then
        return
    end

    settings.locked = locked
    self:Print(locked and "FrameMover locked." or "FrameMover unlocked.")
end

function SN:HandleSlashCommand(message)
    local command = SplitCommand(message)

    if command == "" or command == "help" then
        self:ShowHelp()
    elseif command == "status" then
        self:ShowStatus()
    elseif command == "lock" then
        self:SetFrameMoverLocked(true)
    elseif command == "unlock" then
        self:SetFrameMoverLocked(false)
    elseif command == "resetframes" then
        self:ResetFramePlacements()
        self:Print("Frame placements cleared. Reload UI to restore Blizzard defaults.")
    elseif command == "reload" then
        ReloadUI()
    else
        self:Print("unknown command. Use /snui help.")
    end
end

function SN:RegisterSlashCommands()
    SLASH_SUPERNOVAUI1 = "/snui"
    SLASH_SUPERNOVAUI2 = "/supernova"

    SlashCmdList.SUPERNOVAUI = function(message)
        SN:HandleSlashCommand(message)
    end
end
