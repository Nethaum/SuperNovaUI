local addonName, SN = ...

local ChatHistory = {
    configuredEditBoxes = {},
}

local function SafeCall(callback, ...)
    if not callback then
        return false
    end

    local ok = pcall(callback, ...)
    return ok
end

local function AddUniqueEditBox(editBoxes, editBox)
    if not editBox or editBoxes[editBox] then
        return
    end

    if editBox.IsForbidden and editBox:IsForbidden() then
        return
    end

    editBoxes[editBox] = true
    table.insert(editBoxes, editBox)
end

function ChatHistory:GetSettings()
    return SN:GetModuleSettings(self.name)
end

function ChatHistory:GetChatWindowCount()
    return NUM_CHAT_WINDOWS or 10
end

function ChatHistory:CollectEditBoxes()
    local editBoxes = {}

    if DEFAULT_CHAT_FRAME then
        AddUniqueEditBox(editBoxes, DEFAULT_CHAT_FRAME.editBox)
    end

    AddUniqueEditBox(editBoxes, ChatFrameEditBox)

    for index = 1, self:GetChatWindowCount() do
        local chatFrame = _G["ChatFrame" .. index]
        AddUniqueEditBox(editBoxes, chatFrame and chatFrame.editBox)
        AddUniqueEditBox(editBoxes, _G["ChatFrame" .. index .. "EditBox"])
    end

    return editBoxes
end

function ChatHistory:ConfigureEditBox(editBox)
    local settings = self:GetSettings()
    if not settings or settings.enabled == false or not editBox then
        return
    end

    if editBox.SetHistoryLines then
        SafeCall(editBox.SetHistoryLines, editBox, settings.maxLines or 64)
    end

    if editBox.SetAltArrowKeyMode then
        SafeCall(editBox.SetAltArrowKeyMode, editBox, not settings.useArrowKeys)
    end

    self.configuredEditBoxes[editBox] = true

    if editBox.HookScript and not editBox.superNovaChatHistoryHooked then
        editBox.superNovaChatHistoryHooked = true

        editBox:HookScript("OnShow", function(targetEditBox)
            ChatHistory:ConfigureEditBox(targetEditBox)
        end)

        editBox:HookScript("OnEditFocusGained", function(targetEditBox)
            ChatHistory:ConfigureEditBox(targetEditBox)
        end)
    end
end

function ChatHistory:ConfigureChatEditBoxes()
    for _, editBox in ipairs(self:CollectEditBoxes()) do
        self:ConfigureEditBox(editBox)
    end
end

function ChatHistory:ScheduleConfigure(delay)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, function()
            ChatHistory:ConfigureChatEditBoxes()
        end)
    else
        self:ConfigureChatEditBoxes()
    end
end

function ChatHistory:Initialize()
    self:ConfigureChatEditBoxes()
    self:ScheduleConfigure(1)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")

    events:SetScript("OnEvent", function()
        ChatHistory:ScheduleConfigure(0)
        ChatHistory:ScheduleConfigure(1)
    end)

    if hooksecurefunc and FCF_OpenNewWindow then
        hooksecurefunc("FCF_OpenNewWindow", function()
            ChatHistory:ScheduleConfigure(0)
        end)
    end

    self.events = events
end

function ChatHistory:PrintStatus()
    local settings = self:GetSettings()
    if not settings then
        return
    end

    local configuredCount = 0
    for _ in pairs(self.configuredEditBoxes) do
        configuredCount = configuredCount + 1
    end

    SN:Print(string.format(
        "Chat History: %s, arrow keys %s, %d edit boxes configured.",
        settings.enabled == false and "disabled" or "enabled",
        settings.useArrowKeys and "enabled" or "Alt-only",
        configuredCount
    ))
end

SN:RegisterModule("chatHistory", ChatHistory)
