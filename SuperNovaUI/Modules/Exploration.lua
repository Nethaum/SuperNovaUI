local addonName, SN = ...

--[[
    Exploration markers.

    Marks the regions of the zone you are in that you have not discovered yet, on the world map and on the minimap.

    What is undiscovered comes from comparing two lists. SN.ExplorationData (generated from the game's own tables, see
    tools/gen-exploration.py) holds every region of every zone map, each with the fog piece that the game draws once the
    region is discovered and the middle of the region. C_MapExplorationInfo.GetExploredMapTextures lists the fog pieces
    of the regions already discovered. A region whose piece is not in that list gets a marker; discovering it removes it.

    The world map markers are small frames on the map's canvas. The minimap markers are placed from the distance to the
    player in yards (the zone's size in yards from C_Map.GetMapWorldSize and the minimap's radius in yards from
    C_Minimap.GetViewRadius), turned by the player's facing when the minimap rotates. The minimap is looked at ten times a
    second, and only while it has a marker to move.

    Shared by the Retail and the WoW Forever addons; only Data/Exploration.lua differs.
]]

local Exploration = {
    running = false,
    worldPins = {},
    minimapPins = {},
    cache = {}, -- uiMapID -> { time = when it was read, list = the regions without a discovery }
}

-- Media/Icons/Unexplored.tga: a small ring with a dot, next to the addon's own icon
local ICON = (SN.config.icon:gsub("SuperNovaUI$", "Unexplored"))
local WORLD_PIN_SIZE, MINIMAP_PIN_SIZE = 14, 10
local MINIMAP_STEP = 0.1  -- seconds between two looks at the minimap
local CACHE_SECONDS = 3   -- how long a read of the explored pieces is reused (events clear it sooner)
local MAP_EVENTS = { "MAP_EXPLORATION_UPDATED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD" }

local function L(enUS, ptBR)
    return SN:Loc({ enUS = enUS, ptBR = ptBR })
end

-- A "secret value" (hidden by the game in some situations) cannot be used in arithmetic: treat it as missing.
local function Plain(value)
    if type(value) ~= "number" then
        return nil
    end

    if issecretvalue and issecretvalue(value) then
        return nil
    end

    return value
end

function Exploration:IsSupported()
    return SN.ExplorationData ~= nil
        and C_Map ~= nil and C_Map.GetBestMapForUnit ~= nil and C_Map.GetPlayerMapPosition ~= nil
        and C_MapExplorationInfo ~= nil and C_MapExplorationInfo.GetExploredMapTextures ~= nil
end

function Exploration:GetSetting(key)
    return SN:GetOption(self.name, key)
end

-- The regions of one zone map that have no discovery yet: { { offsetX, ..., centerX, centerY, areaID }, ... }.
function Exploration:GetUndiscovered(mapID)
    local regions = mapID and SN.ExplorationData and SN.ExplorationData[mapID]

    if not regions then
        return nil
    end

    local now = GetTime()
    local cached = self.cache[mapID]

    if cached and now - cached.time < CACHE_SECONDS then
        return cached.list
    end

    local found = {}
    local ok, explored = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)

    if ok and type(explored) == "table" then
        for _, piece in ipairs(explored) do
            found[piece.offsetX .. ":" .. piece.offsetY .. ":" .. piece.textureWidth .. ":" .. piece.textureHeight] = true
        end
    end

    local list = {}

    for _, region in ipairs(regions) do
        if not found[region[1] .. ":" .. region[2] .. ":" .. region[3] .. ":" .. region[4]] then
            table.insert(list, region)
        end
    end

    self.cache[mapID] = { time = now, list = list }
    return list
end

function Exploration:ForgetReads()
    self.cache = {}
end

function Exploration:GetAreaName(areaID)
    local name = areaID and areaID > 0 and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areaID)

    if type(name) == "string" and name ~= "" then
        return name
    end

    return L("Unexplored area", "Área inexplorada")
end

local function NewPin(parent, size, interactive)
    local pin = CreateFrame("Frame", nil, parent)
    pin:SetSize(size, size)
    pin:SetFrameLevel(parent:GetFrameLevel() + 20)
    pin:EnableMouse(interactive and true or false)

    local icon = pin:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture(ICON)
    pin.icon = icon

    if interactive then
        pin:SetScript("OnEnter", function(self)
            if not GameTooltip then
                return
            end

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(Exploration:GetAreaName(self.areaID), 1, 1, 1)
            GameTooltip:AddLine(L("Not discovered yet", "Ainda não descoberta"), 0.6, 0.8, 1)
            GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
    end

    pin:Hide()
    return pin
end

local function HidePins(pins, from)
    for index = from or 1, #pins do
        pins[index]:Hide()
    end
end

-- ---- World map ---------------------------------------------------------------------------------------------------

function Exploration:UpdateWorldMap()
    local map = _G.WorldMapFrame

    if not self.running or not map or not self:GetSetting("worldMap") or not map:IsShown() then
        HidePins(self.worldPins)
        return
    end

    local canvas = map.GetCanvas and map:GetCanvas()
    local mapID = map.GetMapID and map:GetMapID()
    local list = canvas and self:GetUndiscovered(mapID)

    if not list then
        HidePins(self.worldPins)
        return
    end

    local width, height = canvas:GetWidth(), canvas:GetHeight()
    local scale = canvas:GetScale()

    if not scale or scale <= 0 then
        scale = 1
    end

    for index, region in ipairs(list) do
        local pin = self.worldPins[index]

        if not pin then
            pin = NewPin(canvas, WORLD_PIN_SIZE, true)
            self.worldPins[index] = pin
        end

        -- the canvas is zoomed by its scale; the marker keeps its own size by scaling the other way
        pin:SetScale(1 / scale)
        pin.areaID = region[7]
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", region[5] * width * scale, -region[6] * height * scale)
        pin:Show()
    end

    HidePins(self.worldPins, #list + 1)
end

function Exploration:HookWorldMap()
    local map = _G.WorldMapFrame

    if self.hooked or not map or not hooksecurefunc then
        return
    end

    self.hooked = true
    local function Refresh()
        Exploration:UpdateWorldMap()
    end

    map:HookScript("OnShow", Refresh)
    map:HookScript("OnHide", Refresh)

    for _, method in ipairs({ "OnMapChanged", "OnCanvasScaleChanged" }) do
        if type(map[method]) == "function" then
            hooksecurefunc(map, method, Refresh)
        end
    end
end

-- ---- Minimap -----------------------------------------------------------------------------------------------------

-- Radius of what the minimap shows, in yards.
local function GetMinimapRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, radius = pcall(C_Minimap.GetViewRadius)
        radius = ok and Plain(radius)

        if radius and radius > 0 then
            return radius
        end
    end

    return nil
end

-- Where a point lands on the minimap, from its distance to the player: `east` and `north` in yards. A minimap that
-- rotates keeps the direction the player faces (`facing`, in radians, 0 = north and growing to the west) at the top.
function Exploration.Project(east, north, rotates, facing)
    if not rotates then
        return east, north
    end

    local sine, cosine = math.sin(facing), math.cos(facing)
    return east * cosine + north * sine, -east * sine + north * cosine
end

local function IsSquareMinimap()
    local shape = GetMinimapShape and GetMinimapShape()
    return shape == "SQUARE"
end

function Exploration:UpdateMinimap()
    local minimap = _G.Minimap

    if not self.running or not minimap or not self:GetSetting("minimap") or not minimap:IsVisible() then
        HidePins(self.minimapPins)
        return
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local list = mapID and self:GetUndiscovered(mapID)
    local radius = GetMinimapRadius()

    if not list or #list == 0 or not radius then
        HidePins(self.minimapPins)
        return
    end

    local okPosition, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    local playerX, playerY = position and Plain(position.x), position and Plain(position.y)
    local yardsWide, yardsHigh

    if C_Map.GetMapWorldSize then
        local okSize, wide, high = pcall(C_Map.GetMapWorldSize, mapID)
        yardsWide, yardsHigh = okSize and Plain(wide), okSize and Plain(high)
    end

    if not (okPosition and playerX and playerY and yardsWide and yardsHigh and yardsWide > 0) then
        HidePins(self.minimapPins)
        return
    end

    local half = minimap:GetWidth() / 2
    local square = IsSquareMinimap()
    local rotates = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotates and Plain(GetPlayerFacing and GetPlayerFacing()) or 0
    local shown = 0

    for _, region in ipairs(list) do
        -- east and north of the player, in yards (the map's y grows to the south)
        local east = (region[5] - playerX) * yardsWide
        local north = -(region[6] - playerY) * yardsHigh
        local sx, sy = Exploration.Project(east, north, rotates, facing)
        local offsetX, offsetY = sx / radius * half, sy / radius * half
        local inside

        if square then
            inside = math.abs(offsetX) <= half and math.abs(offsetY) <= half
        else
            inside = offsetX * offsetX + offsetY * offsetY <= half * half
        end

        if inside then
            shown = shown + 1
            local pin = self.minimapPins[shown]

            if not pin then
                pin = NewPin(minimap, MINIMAP_PIN_SIZE, false)
                self.minimapPins[shown] = pin
            end

            pin:ClearAllPoints()
            pin:SetPoint("CENTER", minimap, "CENTER", offsetX, offsetY)
            pin:Show()
        end
    end

    HidePins(self.minimapPins, shown + 1)
end

-- The minimap is looked at only while the module is on and the minimap markers are wanted.
function Exploration:UpdateTicker()
    local wanted = self.running and self:GetSetting("minimap")

    if not wanted then
        if self.ticker then
            self.ticker:SetScript("OnUpdate", nil)
        end

        HidePins(self.minimapPins)
        return
    end

    if not self.ticker then
        self.ticker = CreateFrame("Frame")
    end

    local elapsed = 0
    self.ticker:SetScript("OnUpdate", function(_, step)
        elapsed = elapsed + step

        if elapsed >= MINIMAP_STEP then
            elapsed = 0
            Exploration:UpdateMinimap()
        end
    end)
end

-- ---- Life cycle --------------------------------------------------------------------------------------------------

function Exploration:Refresh()
    if self.running then
        self:HookWorldMap() -- the world map may only exist after the game has finished loading its own addons
    end

    self:UpdateTicker()
    self:UpdateWorldMap()
    self:UpdateMinimap()
end

function Exploration:Listen(on)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function()
            Exploration:ForgetReads()
            Exploration:Refresh()
        end)
    end

    for _, event in ipairs(MAP_EVENTS) do
        if on then
            pcall(self.frame.RegisterEvent, self.frame, event)
        else
            pcall(self.frame.UnregisterEvent, self.frame, event)
        end
    end
end

function Exploration:SetEnabled(enabled)
    self.running = enabled and self:IsSupported()
    self:Listen(self.running)
    self:ForgetReads()
    self:Refresh()
end

function Exploration:Initialize()
    self:SetEnabled(true)
end

function Exploration:OnOptionChanged()
    self:Refresh()
end

-- /snui explore: how many regions of the current zone are still undiscovered.
function Exploration:HandleCommand()
    if not self:IsSupported() then
        SN:Print(L("exploration markers are not available in this game.", "os marcadores de exploração não estão disponíveis neste jogo."))
        return
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local regions = mapID and SN.ExplorationData[mapID]

    if not regions then
        SN:Print(L("this zone has no regions to discover.", "esta zona não tem regiões para descobrir."))
        return
    end

    self:ForgetReads()
    local list = self:GetUndiscovered(mapID)
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local zone = info and info.name or tostring(mapID)

    SN:Print(L("%s: %d of %d regions still to discover.", "%s: faltam descobrir %d de %d regiões."):format(zone, #list, #regions))

    for _, region in ipairs(list) do
        SN:Print("  - " .. self:GetAreaName(region[7]))
    end
end

Exploration.info = {
    category = "interface",
    kind = "feature",
    order = 1,
    name = { enUS = "Exploration markers", ptBR = "Marcadores de exploração" },
    desc = {
        enUS = "Marks the regions of your zone that you have not discovered yet, on the world map and on the minimap. A marker disappears when you discover the region.",
        ptBR = "Marca as regiões da sua zona que você ainda não descobriu, no mapa-múndi e no minimapa. O marcador some quando você descobre a região.",
    },
    -- Leatrix Maps uncovers the whole map, so there is nothing left to point at.
    conflictsWith = { "Leatrix_Maps" },
    isUseful = function(module)
        return module:IsSupported()
    end,
    help = { "/snui explore - list the regions of the current zone that are still undiscovered" },
    options = {
        { type = "toggle", key = "worldMap", default = true,
            text = { enUS = "Show markers on the world map", ptBR = "Mostrar marcadores no mapa-múndi" },
            desc = { enUS = "A small ring on the zone map for each region you have not discovered.", ptBR = "Um pequeno anel no mapa da zona para cada região que você ainda não descobriu." } },
        { type = "toggle", key = "minimap", default = true,
            text = { enUS = "Show markers on the minimap", ptBR = "Mostrar marcadores no minimapa" },
            desc = { enUS = "The same markers on the minimap, when the region is within its range.", ptBR = "Os mesmos marcadores no minimapa, quando a região está ao alcance dele." } },
    },
    GetStatus = function(module)
        if not module:IsSupported() then
            return "warning", L("Not available in this game", "Indisponível neste jogo")
        end

        return "active"
    end,
}

SN:RegisterModuleDefaults("explore", { enabled = true })
SN:RegisterModule("explore", Exploration)
