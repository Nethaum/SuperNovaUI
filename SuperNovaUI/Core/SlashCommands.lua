local addonName, SN = ...

local HELP_LINES = {
    "commands:",
    "/snui status - show SuperNovaUI status",
    "/snui windows status - show Window Mover status",
    "/snui windows lock - lock window movement and scaling",
    "/snui windows unlock - unlock window movement and scaling",
    "/snui windows reset - close windows and reset saved window positions",
    "/snui chat status - show Chat History status",
    "/snui reload - reload the UI",
}

local MODULE_LABELS = {
    frameMover = "Window Mover",
    chatHistory = "Chat History",
}

local function SafeCall(callback, ...)
    if not callback then
        return false
    end

    local ok = pcall(callback, ...)
    return ok
end

local function CloseFrame(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end

    SafeCall(HideUIPanel, frame)

    if frame:IsShown() then
        return SafeCall(frame.Hide, frame)
    end

    return true
end

local function SplitCommand(message)
    local command, rest = string.match(message or "", "^(%S*)%s*(.-)$")
    return string.lower(command or ""), rest or ""
end

local function GetModuleLabel(moduleName)
    return MODULE_LABELS[moduleName] or moduleName
end

function SN:ShowHelp()
    for _, line in ipairs(HELP_LINES) do
        self:Print(line)
    end
end

function SN:ShowStatus()
    self:Print("SuperNovaUI status:")

    for _, moduleName in ipairs(self.moduleOrder) do
        local settings = self:GetModuleSettings(moduleName)
        local enabled = settings and settings.enabled ~= false
        self:Print(string.format("- %s: %s", GetModuleLabel(moduleName), enabled and "enabled" or "disabled"))
    end
end

function SN:ShowWindowStatus()
    local frameMover = self:GetModule("frameMover")
    if frameMover and frameMover.PrintStatus then
        frameMover:PrintStatus()
    end
end

function SN:ShowChatStatus()
    local chatHistory = self:GetModule("chatHistory")
    if chatHistory and chatHistory.PrintStatus then
        chatHistory:PrintStatus()
    end
end

function SN:SetFrameMoverLocked(locked)
    local settings = self:GetModuleSettings("frameMover")
    if not settings then
        return
    end

    settings.locked = locked

    local frameMover = self:GetModule("frameMover")
    if locked and frameMover and frameMover.StopAllMoving then
        frameMover:StopAllMoving()
    end

    if locked then
        self:Print("Window movement locked. Movement and scaling are disabled.")
    else
        self:Print("Window movement unlocked. Hold SHIFT to move windows or CTRL + mousewheel to scale.")
    end
end

function SN:CloseOpenWindows()
    local frameMover = self:GetModule("frameMover")
    if frameMover and frameMover.StopAllMoving then
        frameMover:StopAllMoving()
    end

    SafeCall(CloseAllWindows)
    SafeCall(CloseAllBags)

    local settings = self:GetModuleSettings("frameMover")
    if not settings or not settings.frames then
        return
    end

    for _, frameName in ipairs(settings.frames) do
        CloseFrame(_G[frameName])
    end
end

function SN:ResetWindows()
    self:CloseOpenWindows()
    self:ResetFramePlacements()
    self:Print("Windows closed and saved window positions cleared. Reload UI to restore Blizzard defaults.")
end

function SN:HandleWindowCommand(message)
    local command = SplitCommand(message)

    if command == "" or command == "status" then
        self:ShowWindowStatus()
    elseif command == "help" then
        self:ShowHelp()
    elseif command == "lock" then
        self:SetFrameMoverLocked(true)
    elseif command == "unlock" then
        self:SetFrameMoverLocked(false)
    elseif command == "reset" or command == "resetwindows" or command == "resetframes" then
        self:ResetWindows()
    else
        self:Print("unknown windows command. Use /snui help.")
    end
end

function SN:HandleChatCommand(message)
    local command = SplitCommand(message)

    if command == "" or command == "status" or command == "history" then
        self:ShowChatStatus()
    elseif command == "help" then
        self:ShowHelp()
    else
        self:Print("unknown chat command. Use /snui help.")
    end
end

function SN:HandleSlashCommand(message)
    local command, rest = SplitCommand(message)

    if command == "" or command == "help" then
        self:ShowHelp()
    elseif command == "status" then
        self:ShowStatus()
    elseif command == "window" or command == "windows" then
        self:HandleWindowCommand(rest)
    elseif command == "chat" then
        self:HandleChatCommand(rest)
    elseif command == "lock" then
        self:SetFrameMoverLocked(true)
    elseif command == "unlock" then
        self:SetFrameMoverLocked(false)
    elseif command == "resetframes" or command == "resetwindows" then
        self:ResetWindows()
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
