local addonName, SN = ...

--[[
    The first-run window: "load the modules that work with your addons?". It lists the recommended modules; Yes keeps
    them on, No turns everything off and opens the panel so the player picks.
]]

local W = SN.Widgets

local WIDTH = 460
local MAX_LISTED = 8

function SN:ShowWelcome()
    local compatible = self:GetRecommendedModules()
    local lines = {}

    for index, moduleName in ipairs(compatible) do
        if index > MAX_LISTED then
            table.insert(lines, "...")
            break
        end

        table.insert(lines, "- " .. self:GetModuleDisplayName(moduleName))
    end

    if self.welcome then
        self.welcome:Hide()
    end

    local frame = W.NewFrame(UIParent, self.config.welcomeName)
    frame:SetSize(WIDTH, 190 + #lines * 16)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    frame:SetFrameStrata("FULLSCREEN_DIALOG") -- above the options panel, which is a DIALOG
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    W.Backdrop(frame, W.colors.background, W.colors.accent)
    W.Stars(frame, 26, 4217, { 14, 12, WIDTH - 14, 190 + #lines * 16 - 12 })

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -14)
    icon:SetTexture(SN.config.icon)

    local title = W.Text(frame, "GameFontNormalLarge", self:T("welcome_title"), W.colors.accent)
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)

    local question = W.Text(frame, "GameFontHighlight", self:T("welcome_text"))
    question:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -52)
    question:SetWidth(WIDTH - 40)
    question:SetWordWrap(true)

    local found = W.Text(frame, "GameFontHighlight", self:T("welcome_found", #compatible), W.colors.muted)
    found:SetPoint("TOPLEFT", question, "BOTTOMLEFT", 0, -14)

    local list = W.Text(frame, "GameFontHighlight", table.concat(lines, "\n"))
    list:SetPoint("TOPLEFT", found, "BOTTOMLEFT", 8, -6)
    list:SetWidth(WIDTH - 60)

    local note = W.Text(frame, "GameFontDisableSmall", self:T("welcome_note"), W.colors.muted)
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 58)

    local function Answer(enableAll)
        frame:Hide()
        self:AnswerFirstRun(enableAll)
    end

    local yes = W.Button(frame, self:T("welcome_yes"), 200, 28, function()
        Answer(true)
    end)
    yes:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18)
    yes:SetSelected(true)

    local no = W.Button(frame, self:T("welcome_no"), 200, 28, function()
        Answer(false)
    end)
    no:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 18)

    self.welcome = frame
    return frame
end
