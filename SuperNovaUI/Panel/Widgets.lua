local addonName, SN = ...

--[[
    Small flat widgets built from plain frames, so the panel does not depend on Blizzard templates that differ between
    clients (only the optional BackdropTemplate is used, when the client has it).
]]

local W = {}
SN.Widgets = W

W.colors = {
    background = { 0.035, 0.035, 0.09, 0.97 }, -- deep space
    panel = { 0.07, 0.065, 0.15, 1 },
    border = { 0.22, 0.2, 0.42, 1 },            -- dusk violet
    accent = { 0.22, 0.74, 0.97, 1 },           -- the SuperNovaUI cyan
    hover = { 0.13, 0.12, 0.27, 1 },
    selected = { 0.15, 0.18, 0.4, 1 },          -- nebula blue
    text = { 0.9, 0.93, 0.96 },
    muted = { 0.64, 0.65, 0.82 },
    good = { 0.35, 0.85, 0.5 },
    bad = { 0.95, 0.4, 0.4 },
    warn = { 0.98, 0.78, 0.3 },
}

local FLAT = "Interface\\Buttons\\WHITE8x8"

-- Fonts. The window draws its text with its own font objects pointing at the font file Blizzard ships (Friz Quadrata),
-- so it looks the same whatever a font addon did to the game's GameFont objects. A client in another alphabet (Russian,
-- Korean, Chinese) keeps the font its own client chose, because Friz Quadrata has no letters for it.
local LATIN_CLIENTS = { enUS = true, enGB = true, esES = true, esMX = true, ptBR = true, ptPT = true, frFR = true, deDE = true, itIT = true }

local function FontFile()
    local locale = GetLocale and GetLocale() or "enUS"

    if LATIN_CLIENTS[locale] then
        return "Fonts\\FRIZQT__.TTF"
    end

    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local FONT_SIZES = { huge = 22, large = 16, body = 12, small = 10 }

-- Which of ours replaces each GameFont template the pages ask for.
local FONT_OF_TEMPLATE = {
    GameFontNormalHuge = "huge",
    GameFontNormalLarge = "large",
    GameFontNormal = "body",
    GameFontHighlight = "body",
    GameFontDisable = "body",
    GameFontDisableSmall = "small",
}

W.fonts = {}

for key, size in pairs(FONT_SIZES) do
    local font = CreateFont(SN.config.panelName .. "Font" .. key)
    font:SetFont(FontFile(), size, "")
    font:SetShadowColor(0, 0, 0, 1)
    font:SetShadowOffset(1, -1)
    W.fonts[key] = font
end

function W.FontFor(template)
    return W.fonts[FONT_OF_TEMPLATE[template or "GameFontHighlight"] or "body"]
end

-- Tooltips: a widget with a .tooltip function (returning a title and a list of lines) shows it while the mouse is over it.
function W.ShowTooltip(owner)
    if not owner.tooltip or not GameTooltip then
        return
    end

    local title, lines = owner.tooltip()

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", 1, 1, 1)

    for _, line in ipairs(lines or {}) do
        if line ~= "" then
            GameTooltip:AddLine(line, 0.75, 0.8, 0.86, true)
        end
    end

    GameTooltip:Show()
end

function W.HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function W.SetColor(texture, color)
    if texture.SetColorTexture then
        texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    else
        texture:SetTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

-- Scatters small dim stars on a frame. The same seed always gives the same sky. `exclude` ({ left, top, right, bottom },
-- from the top left corner) is a region that stays empty so no star sits behind text.
function W.Stars(frame, count, seed, exclude)
    local width, height = frame:GetWidth(), frame:GetHeight()
    local state = seed

    local function Random()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end

    local tints = { { 1, 1, 1 }, { 0.75, 0.85, 1 }, { 0.85, 0.78, 1 } }
    local made, tries = 0, 0

    while made < count and tries < count * 40 do
        tries = tries + 1

        local x, y = 2 + Random() * (width - 6), 2 + Random() * (height - 6)
        local size = Random() < 0.2 and 2 or 1
        local tint = tints[math.floor(Random() * #tints) + 1]
        local alpha = 0.25 + Random() * 0.45
        local blocked = exclude and x > exclude[1] and x < exclude[3] and y > exclude[2] and y < exclude[4]

        if not blocked then
            local star = frame:CreateTexture(nil, "BORDER")
            star:SetSize(size, size)
            star:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
            W.SetColor(star, { tint[1], tint[2], tint[3], alpha })
            made = made + 1
        end
    end
end

function W.NewFrame(parent, name)
    return CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
end

function W.Backdrop(frame, background, border)
    if not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    frame:SetBackdropColor(unpack(background))
    frame:SetBackdropBorderColor(unpack(border))
end

function W.Text(parent, template, text, color)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(W.FontFor(template))
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text or "")
    color = color or W.colors.text
    label:SetTextColor(color[1], color[2], color[3])
    return label
end

-- A button with a flat look. Returns the button; button.label is its text.
function W.Button(parent, text, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    button:SetSize(width, height or 24)
    W.Backdrop(button, W.colors.panel, W.colors.border)

    button.label = W.Text(button, "GameFontHighlight", text)
    button.label:SetPoint("CENTER")
    button.label:SetJustifyH("CENTER")

    local needed = (button.label:GetStringWidth() or 0) + 14
    if needed > width then
        button:SetWidth(needed)
    end

    button:SetScript("OnEnter", function(self)
        if self.SetBackdropColor and not self.selected then
            self:SetBackdropColor(unpack(W.colors.hover))
        end

        W.ShowTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(unpack(self.selected and W.colors.selected or W.colors.panel))
        end

        W.HideTooltip()
    end)

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    function button:SetSelected(selected)
        self.selected = selected
        if self.SetBackdropColor then
            self:SetBackdropColor(unpack(selected and W.colors.selected or W.colors.panel))
            self:SetBackdropBorderColor(unpack(selected and W.colors.accent or W.colors.border))
        end
    end

    return button
end

-- A check box with a text. get() says whether it is on; set(value) is called when it is clicked.
function W.Check(parent, text, get, set)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(22)

    local box = W.NewFrame(row)
    box:SetSize(18, 18)
    box:SetPoint("LEFT", row, "LEFT", 0, 0)
    W.Backdrop(box, W.colors.panel, W.colors.border)

    local mark = box:CreateTexture(nil, "OVERLAY")
    mark:SetSize(10, 10)
    mark:SetPoint("CENTER")
    W.SetColor(mark, W.colors.accent)

    row.label = W.Text(row, "GameFontHighlight", text)
    row.label:SetPoint("LEFT", box, "RIGHT", 8, 0)

    function row:Refresh()
        if get() then
            mark:Show()
        else
            mark:Hide()
        end
    end

    row:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
    end)
    row:SetScript("OnEnter", W.ShowTooltip)
    row:SetScript("OnLeave", W.HideTooltip)

    row:SetWidth(40 + (row.label:GetStringWidth() or 100))
    row:Refresh()
    return row
end

-- A row of buttons, one per value; the current one is highlighted.
function W.Choice(parent, values, get, set)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)
    row.buttons = {}

    local x = 0

    for _, entry in ipairs(values) do
        local button = W.Button(row, entry.text, 10, 24, function()
            set(entry.value)
            row:Refresh()
        end)
        button:SetWidth(math.max(70, (button.label:GetStringWidth() or 60) + 24))
        button:SetPoint("LEFT", row, "LEFT", x, 0)
        x = x + button:GetWidth() + 6
        button.value = entry.value
        table.insert(row.buttons, button)
    end

    row:SetWidth(math.max(x, 1))

    function row:Refresh()
        local current = get()

        for _, button in ipairs(self.buttons) do
            button:SetSelected(button.value == current)
        end
    end

    row:Refresh()
    return row
end

-- A horizontal slider with its value written next to it.
function W.Slider(parent, option, get, set)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)

    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(180, 14)
    slider:SetPoint("LEFT", row, "LEFT", 0, 0)
    slider:SetMinMaxValues(option.min, option.max)
    slider:SetValueStep(option.step or 1)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(4)
    W.SetColor(track, W.colors.border)

    slider:SetThumbTexture(FLAT)
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(10, 16)
        thumb:SetVertexColor(unpack(W.colors.accent))
    end

    local valueText = W.Text(row, "GameFontHighlight", "")
    valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    row.valueText = valueText

    local updating = false

    slider:SetScript("OnValueChanged", function(_, value)
        if updating then
            return
        end

        set(value)
        valueText:SetText(tostring(get()))
    end)

    function row:Refresh()
        updating = true
        slider:SetValue(get())
        updating = false
        valueText:SetText(tostring(get()))
    end

    row:SetWidth(260)
    row:Refresh()
    return row
end

-- A scrolling area: returns the scroll frame and the content frame to put things in.
function W.ScrollArea(parent, width)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 10)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)

    local bar = scroll:CreateTexture(nil, "OVERLAY")
    bar:SetWidth(3)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    W.SetColor(bar, W.colors.border)
    bar:Hide()

    local function UpdateBar()
        local range = scroll:GetVerticalScrollRange() or 0
        local height = scroll:GetHeight() or 1

        if range <= 0 then
            bar:Hide()
            return
        end

        local barHeight = math.max(24, height * height / (height + range))
        local offset = (scroll:GetVerticalScroll() or 0) / range * (height - barHeight)
        bar:SetHeight(barHeight)
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -offset)
        bar:Show()
    end

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local target = (self:GetVerticalScroll() or 0) - delta * 36
        self:SetVerticalScroll(math.max(0, math.min(range, target)))
        UpdateBar()
    end)

    function scroll:SetContentHeight(height)
        content:SetHeight(math.max(height, 10))
        self:UpdateScrollChildRect()
        UpdateBar()
    end

    function scroll:ScrollToTop()
        self:SetVerticalScroll(0)
        UpdateBar()
    end

    return scroll, content
end

-- Text box with room for several lines. Returns the box (a Frame) and its edit box.
function W.MultiLineBox(parent, width, height)
    local box = W.NewFrame(parent)
    box:SetSize(width, height)
    W.Backdrop(box, W.colors.background, W.colors.border)

    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(W.fonts.body)
    edit:SetWidth(width - 14)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 24)))
    end)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function()
        edit:SetFocus()
    end)

    return box, edit
end

-- Stacks things top to bottom inside a frame and remembers what has to be refreshed when the state changes.
function W.NewFlow(parent, width)
    local flow = { parent = parent, width = width, y = 0, refreshers = {} }

    function flow:Place(frame, height, gap, indent)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", indent or 0, -self.y)
        self.y = self.y + height + (gap or 10)
    end

    function flow:Header(text)
        self.y = self.y + 6
        local label = W.Text(self.parent, "GameFontNormalLarge", text, W.colors.accent)
        self:Place(label, 20, 8)
        return label
    end

    function flow:Text(text, color, template, indent)
        local label = W.Text(self.parent, template or "GameFontHighlight", text, color)
        label:SetWidth(self.width - (indent or 0))
        label:SetWordWrap(true)
        self:Place(label, label:GetStringHeight() or 14, 10, indent)
        return label
    end

    function flow:Add(widget, height, gap, refresh)
        self:Place(widget, height or widget:GetHeight() or 24, gap or 10)

        if refresh then
            table.insert(self.refreshers, refresh)
        elseif widget.Refresh then
            table.insert(self.refreshers, function()
                widget:Refresh()
            end)
        end

        return widget
    end

    function flow:Buttons(definitions)
        local row = CreateFrame("Frame", nil, self.parent)
        row:SetSize(self.width, 26)
        local x = 0

        for _, definition in ipairs(definitions) do
            local button = W.Button(row, definition.text, definition.width or 150, 26, definition.onClick)
            button:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + button:GetWidth() + 8
            row[definition.id or definition.text] = button
        end

        self:Place(row, 26, 12)
        return row
    end

    function flow:OnRefresh(callback)
        table.insert(self.refreshers, callback)
    end

    function flow:Refresh()
        for _, callback in ipairs(self.refreshers) do
            callback()
        end
    end

    function flow:Height()
        return self.y
    end

    return flow
end
