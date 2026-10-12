local addonName, SN = ...

local Compat = SN:GetModule("compat")
if not Compat then
    return
end

local FRAME_NAME = "SuperNovaUICompatFrame"
local WIDTH = 500
local SIDE = 16
local TOP = 34

-- where the compatibility patches and the apply script are published
local FIX_URL = "https://github.com/Nethaum/SuperNovaUI"

local STATUS_FIXED = "|cff00ff00Fixed|r"
local STATUS_NEEDS_FIX = "|cffff9933Needs fix|r"

StaticPopupDialogs["SUPERNOVAUI_COMPAT_FIX"] = {
    text = "Addons are fixed outside the game: close WoW, run apply.ps1 from the compatibility patches, then start the game again.\n\nPatches:",
    button1 = OKAY,
    hasEditBox = true,
    editBoxWidth = 330,
    OnShow = function(dialog)
        local editBox = dialog.EditBox or dialog.editBox
        if editBox then
            editBox:SetText(FIX_URL)
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3, -- avoid some UI taint
}

local function AcquireLine(frame, index, font)
    local line = frame.lines[index]
    if not line then
        line = frame:CreateFontString(nil, "OVERLAY")
        frame.lines[index] = line
    end

    line:SetFontObject(font)
    line:ClearAllPoints()
    line:SetJustifyH("LEFT")
    line:SetWordWrap(true)
    line:Show()
    return line
end

local function CreateButton(frame, text, width)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(text)
    return button
end

function Compat:CreatePanel()
    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    frame:SetWidth(WIDTH)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", function()
        Compat:RefreshPanel()
    end)
    frame:Hide()

    frame.lines = {}

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -6)
    frame.title:SetText("SuperNovaUI - Compatibility")

    frame.refresh = CreateButton(frame, "Refresh", 100)
    frame.refresh:SetPoint("BOTTOMLEFT", SIDE, 12)
    frame.refresh:SetScript("OnClick", function()
        Compat:RefreshPanel()
    end)

    frame.help = CreateButton(frame, "How to fix", 120)
    frame.help:SetPoint("LEFT", frame.refresh, "RIGHT", 8, 0)
    frame.help:SetScript("OnClick", function()
        StaticPopup_Show("SUPERNOVAUI_COMPAT_FIX")
    end)

    tinsert(UISpecialFrames, FRAME_NAME) -- Escape closes it

    self.panel = frame
    return frame
end

-- lays out the lines top to bottom and sizes the frame to fit
function Compat:RefreshPanel()
    local frame = self.panel
    if not frame then
        return
    end

    for _, line in ipairs(frame.lines) do
        line:Hide()
    end

    local used = 0
    local y = -TOP

    local function Add(font, text, width, alignRight)
        used = used + 1
        local line = AcquireLine(frame, used, font)
        line:SetWidth(width or (WIDTH - 2 * SIDE))
        if alignRight then
            line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SIDE, y)
            line:SetJustifyH("RIGHT")
        else
            line:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE, y)
        end
        line:SetText(text)
        return line
    end

    Add("GameFontNormalLarge", "Addons that need a fix")
    y = y - 24

    local addons = self:GetAddonStates()
    local anyNeedsFix = false

    if #addons == 0 then
        Add("GameFontHighlightSmall", "None of the known incompatible addons is installed.")
        y = y - 20
    end

    for _, addon in ipairs(addons) do
        local label = addon.enabled and addon.name or (addon.name .. " |cff888888(disabled)|r")
        Add("GameFontHighlight", label, 320)
        Add("GameFontNormal", addon.fixed and STATUS_FIXED or STATUS_NEEDS_FIX, 150, true)
        y = y - 18

        if not addon.fixed then
            anyNeedsFix = true
            local problem = Add("GameFontDisableSmall", addon.problem)
            y = y - problem:GetStringHeight() - 4
        end
        y = y - 6
    end

    y = y - 6
    Add("GameFontNormalLarge", "Built-in fixes")
    y = y - 24

    for _, shim in ipairs(self:GetShimStates()) do
        local state = shim.active and "|cff00ff00active|r" or "|cff888888not needed (already provided)|r"
        local line = Add("GameFontHighlightSmall", shim.description .. " - " .. state)
        y = y - line:GetStringHeight() - 6
    end

    frame.help:SetEnabled(anyNeedsFix)
    frame:SetHeight(-y + 52)
end

function Compat:TogglePanel()
    local frame = self.panel or self:CreatePanel()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
