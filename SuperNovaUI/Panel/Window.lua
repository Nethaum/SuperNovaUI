local addonName, SN = ...

--[[
    The options window: modules grouped by category on the left (like folders), the selected module's page on the right.
    Pages are built once and kept; SN:RefreshPanel() only updates what they show.
]]

local W = SN.Widgets

local WIDTH, HEIGHT = 800, 580
local LEFT_WIDTH = 230
local PAGE_WIDTH = WIDTH - LEFT_WIDTH - 62
local ROW_WIDTH = LEFT_WIDTH - 30
local BANNER_HEIGHT = 40

local STATUS_DOT = {
    active = W.colors.good,
    disabled = W.colors.muted,
    missing = W.colors.muted,
    pending = W.colors.warn,
    warning = W.colors.warn,
}

local function AcquireRow(panel, index)
    local row = panel.rows[index]

    if not row then
        row = W.Button(panel.listContent, "", ROW_WIDTH, 24)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 24, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.label:SetJustifyH("LEFT")
        row.dot = row:CreateTexture(nil, "OVERLAY")
        row.dot:SetSize(8, 8)
        row.dot:SetPoint("LEFT", row, "LEFT", 10, 0)
        panel.rows[index] = row
    end

    row:Show()
    return row
end

local function Collapsed(category)
    return SN.db and SN.db.ui and SN.db.ui.collapsed[category] == true
end

function SN:RefreshList()
    local panel = self.panel

    if not panel then
        return
    end

    for _, row in ipairs(panel.rows) do
        row:Hide()
    end

    panel.visible = {}

    local filtering = panel.filter ~= nil and panel.filter ~= ""
    local tree = self:GetModuleTree(panel.filter)
    local index, y = 0, 0

    for _, category in ipairs(tree) do
        local collapsed = Collapsed(category.id) and not filtering

        index = index + 1
        local header = AcquireRow(panel, index)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", panel.listContent, "TOPLEFT", 0, -y)
        header.dot:Hide()
        header.tooltip = nil
        header.label:ClearAllPoints()
        header.label:SetPoint("LEFT", header, "LEFT", 8, 0)
        header.label:SetText((collapsed and "+  " or "-  ") .. category.name)
        header.label:SetTextColor(unpack(W.colors.accent))
        header:SetSelected(false)
        header:SetScript("OnClick", function()
            self.db.ui.collapsed[category.id] = not Collapsed(category.id) or nil
            self:RefreshList()
        end)
        y = y + 26

        if not collapsed then
            for _, moduleName in ipairs(category.modules) do
                index = index + 1
                local row = AcquireRow(panel, index)
                local status = self:GetModuleStatus(moduleName)

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", panel.listContent, "TOPLEFT", 12, -y)
                row:SetWidth(ROW_WIDTH - 12)
                row.dot:Show()
                W.SetColor(row.dot, STATUS_DOT[status] or W.colors.muted)
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row, "LEFT", 24, 0)
                row.label:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                row.label:SetText(self:GetModuleDisplayName(moduleName))
                row.label:SetTextColor(unpack(status == "active" and W.colors.text or W.colors.muted))
                row:SetSelected(panel.selected == moduleName)
                row.tooltip = function()
                    return self:GetModuleDisplayName(moduleName), self:GetModuleTooltipLines(moduleName)
                end
                row:SetScript("OnClick", function()
                    self:SelectModule(moduleName)
                end)
                table.insert(panel.visible, moduleName)
                y = y + 26
            end
        end
    end

    panel.empty:SetShown(#tree == 0)
    panel.listScroll:SetContentHeight(y + 4)
end

-- What the tooltip of a module in the tree says: kind and status, what it does, which addon it needs.
function SN:GetModuleTooltipLines(moduleName)
    local info = self:GetInfo(moduleName)
    local status, detail = self:GetModuleStatus(moduleName)
    local state = self:GetKindText(info.kind) .. " - " .. self:GetStatusText(status)

    if detail then
        state = state .. " (" .. self:Loc(detail) .. ")"
    end

    local lines = { state, self:Loc(info.desc) }

    if info.requiresAddon then
        local installed = self:IsAddonInstalled(info.requiresAddon)
        table.insert(lines, self:T("required_addon", info.requiresAddon .. " (" .. self:T(installed and "required_addon_ok" or "required_addon_missing") .. ")"))
    end

    return lines
end

-- Up and down arrows: the previous or next module in the list as it is shown now.
function SN:MoveSelection(step)
    local panel = self.panel
    local visible = panel and panel.visible or {}

    if #visible == 0 then
        return
    end

    local current = 0

    for index, moduleName in ipairs(visible) do
        if moduleName == panel.selected then
            current = index
        end
    end

    local target = math.max(1, math.min(#visible, (current == 0 and (step > 0 and 1 or #visible)) or (current + step)))
    self:SelectModule(visible[target])
end

function SN:ShowPage(moduleName)
    local panel = self.panel
    local info = self:GetInfo(moduleName)

    if not panel or not info then
        return
    end

    if panel.currentPage then
        panel.currentPage.frame:Hide()
    end

    local page = panel.pages[moduleName]

    if not page then
        local frame = CreateFrame("Frame", nil, panel.pageContent)
        frame:SetSize(PAGE_WIDTH, 10)
        frame:SetPoint("TOPLEFT", panel.pageContent, "TOPLEFT", 0, 0)

        local flow = W.NewFlow(frame, PAGE_WIDTH)

        if info.BuildPage then
            info.BuildPage(self.modules[moduleName], flow)
        else
            self:BuildDefaultPage(moduleName, flow)
        end

        frame:SetHeight(flow:Height())
        page = { frame = frame, flow = flow }
        panel.pages[moduleName] = page
    end

    page.frame:Show()
    page.flow:Refresh()
    panel.currentPage = page
    panel.pageScroll:SetContentHeight(page.flow:Height() + 10)
    panel.pageScroll:ScrollToTop()
end

function SN:SelectModule(moduleName)
    if not self:GetInfo(moduleName) then
        moduleName = "general"
    end

    self.panel.selected = moduleName
    self.db.ui.selected = moduleName
    self:ShowPage(moduleName)
    self:RefreshList()
end

function SN:UpdateBanner()
    local panel = self.panel

    if not panel then
        return
    end

    panel.banner:SetShown(self:HasPendingReload())
end

function SN:RefreshPanel()
    local panel = self.panel

    if not panel or not panel:IsShown() then
        return
    end

    self:RefreshList()

    if panel.currentPage then
        panel.currentPage.flow:Refresh()
    end

    self:UpdateBanner()
end

-- Applies the current language to the window and drops the cached pages so they are drawn again.
function SN:RebuildPanel()
    local panel = self.panel

    if not panel then
        return
    end

    for _, page in pairs(panel.pages) do
        page.frame:Hide()
    end

    panel.pages = {}
    panel.currentPage = nil
    panel.title:SetText(self:T("panel_title") .. "  " .. W.colors.accentHex .. "v" .. tostring(self.version) .. "|r")
    panel.placeholder:SetText(self:T("search"))
    panel.empty:SetText(self:T("no_results"))
    panel.bannerText:SetText(self:T("reload_banner"))
    panel.bannerButton.label:SetText(self:T("reload_now"))
    self:SelectModule(panel.selected or "general")
end

function SN:BuildPanel()
    if self.panel then
        return self.panel
    end

    W.colors.accentHex = "|cff38bdf8"

    local panel = W.NewFrame(UIParent, self.config.panelName)
    panel:SetSize(WIDTH, HEIGHT)
    self:RestorePanelPosition(panel)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        self:SavePanelPosition(frame)
    end)
    panel:EnableKeyboard(true)
    panel:SetScript("OnKeyDown", function(frame, key)
        local handled = false

        if key == "UP" or key == "DOWN" then
            self:MoveSelection(key == "UP" and -1 or 1)
            handled = true
        elseif key == "F" and IsControlKeyDown and IsControlKeyDown() then
            panel.search:SetFocus()
            handled = true
        end

        -- keys the window does not use must still reach the game (movement, chat, ...)
        if not (InCombatLockdown and InCombatLockdown()) then
            frame:SetPropagateKeyboardInput(not handled)
        end
    end)
    W.Backdrop(panel, W.colors.background, W.colors.border)
    -- the sky: stars everywhere except behind the page (text) on the right
    W.Stars(panel, 90, 20260, { LEFT_WIDTH + 30, 46, WIDTH - 16, HEIGHT - 16 - BANNER_HEIGHT })
    panel:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, self.config.panelName)
    end

    panel.rows = {}
    panel.pages = {}
    panel.filter = ""

    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(24, 24)
    panel.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -10)
    panel.icon:SetTexture(SN.config.icon)

    panel.title = W.Text(panel, "GameFontNormalLarge", "")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 46, -14)

    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -40)
    headerLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -40)
    W.SetColor(headerLine, W.colors.border)

    local close = W.Button(panel, "X", 24, 24, function()
        panel:Hide()
    end)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)

    -- Left column: search and the tree.
    local search = CreateFrame("EditBox", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    search:SetSize(LEFT_WIDTH - 16, 24)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -46)
    search:SetAutoFocus(false)
    search:SetFontObject(W.fonts.body)
    search:SetTextInsets(8, 8, 0, 0)
    W.Backdrop(search, W.colors.panel, W.colors.border)

    panel.placeholder = W.Text(search, "GameFontDisable", "", W.colors.muted)
    panel.placeholder:SetPoint("LEFT", search, "LEFT", 8, 0)

    search:SetScript("OnTextChanged", function(box)
        panel.filter = box:GetText() or ""
        panel.placeholder:SetShown(panel.filter == "")
        self:RefreshList()
    end)
    search:SetScript("OnEscapePressed", function(box)
        box:SetText("")
        box:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
    end)
    search:SetScript("OnArrowPressed", function(_, key)
        key = string.upper(key or "")

        if key == "UP" or key == "DOWN" then
            self:MoveSelection(key == "UP" and -1 or 1)
        end
    end)
    panel.search = search

    panel.listScroll, panel.listContent = W.ScrollArea(panel, LEFT_WIDTH - 16)
    panel.listScroll:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -10)
    panel.listScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16 + BANNER_HEIGHT)
    panel.listScroll:SetWidth(LEFT_WIDTH - 16)

    panel.empty = W.Text(panel.listContent, "GameFontDisable", "", W.colors.muted)
    panel.empty:SetPoint("TOPLEFT", panel.listContent, "TOPLEFT", 6, -6)
    panel.empty:SetWidth(LEFT_WIDTH - 40)
    panel.empty:Hide()

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_WIDTH + 14, -46)
    divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", LEFT_WIDTH + 14, 16)
    W.SetColor(divider, W.colors.border)

    -- Right column: the page.
    panel.pageScroll, panel.pageContent = W.ScrollArea(panel, PAGE_WIDTH)
    panel.pageScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_WIDTH + 30, -46)
    panel.pageScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16 + BANNER_HEIGHT)

    -- Bottom banner: shown when a change needs a reload.
    local banner = W.NewFrame(panel)
    banner:SetHeight(BANNER_HEIGHT - 6)
    banner:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 14)
    banner:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 14)
    W.Backdrop(banner, W.colors.selected, W.colors.warn)
    panel.bannerText = W.Text(banner, "GameFontHighlight", "")
    panel.bannerText:SetPoint("LEFT", banner, "LEFT", 12, 0)
    panel.bannerButton = W.Button(banner, "", 150, 24, function()
        ReloadUI()
    end)
    panel.bannerButton:SetPoint("RIGHT", banner, "RIGHT", -6, 0)
    banner:Hide()
    panel.banner = banner

    panel:SetScript("OnShow", function()
        self:RefreshPanel()
    end)

    self.panel = panel
    self:RebuildPanel()
    return panel
end

-- The window remembers where the player put it.
function SN:SavePanelPosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint()

    if point then
        self.db.ui.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
end

function SN:RestorePanelPosition(frame)
    local position = self.db.ui.position

    frame:ClearAllPoints()

    if type(position) == "table" and position.point then
        frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

function SN:ResetPanelPosition()
    self.db.ui.position = nil

    if self.panel then
        self:RestorePanelPosition(self.panel)
    end
end

function SN:OpenPanel(moduleName)
    local panel = self:BuildPanel()
    panel:Show()
    self:SelectModule(moduleName or (self.db.ui and self.db.ui.selected) or "general")
    self:UpdateBanner()
end

function SN:TogglePanel()
    if self.panel and self.panel:IsShown() then
        self.panel:Hide()
    else
        self:OpenPanel()
    end
end
