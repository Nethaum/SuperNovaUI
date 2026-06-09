local addonName, SN = ...

local FrameMover = {
    attachedFrames = {},
    attachedInputs = {},
    attachedWheels = {},
    dragHandles = {},
    movingFrames = {},
}

local DEFAULT_DRAG_HEIGHT = 56

local FRAME_PROFILES = {
    WorldMapFrame = {
        dragHeight = 72,
        wheelTargets = {
            "WorldMapFrame.ScrollContainer",
        },
    },
}

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function IsModifierDown(modifier)
    if modifier == "NONE" then
        return true
    elseif modifier == "ALT" then
        return IsAltKeyDown()
    elseif modifier == "CTRL" then
        return IsControlKeyDown()
    elseif modifier == "SHIFT" then
        return IsShiftKeyDown()
    end

    return false
end

local function ResolveFramePath(framePath)
    local currentFrame

    for segment in string.gmatch(framePath or "", "[^%.]+") do
        currentFrame = currentFrame and currentFrame[segment] or _G[segment]

        if not currentFrame then
            return nil
        end
    end

    return currentFrame
end

local function IsSafeFrame(frame)
    if not frame then
        return false
    end

    if frame.IsForbidden and frame:IsForbidden() then
        return false
    end

    return frame.SetMovable and frame.RegisterForDrag and frame.StartMoving and frame.StopMovingOrSizing
end

local function CanReceiveInput(frame)
    if not frame then
        return false
    end

    if frame.IsForbidden and frame:IsForbidden() then
        return false
    end

    return frame.HookScript and frame.EnableMouse
end

function FrameMover:GetSettings()
    return SN:GetModuleSettings(self.name)
end

function FrameMover:IsInteractionAllowed()
    local settings = self:GetSettings()
    if not settings or settings.locked then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    return IsModifierDown(settings.modifier or "SHIFT")
end

function FrameMover:GetPlacement(frameName)
    local settings = self:GetSettings()
    if not settings then
        return nil
    end

    settings.placements = settings.placements or {}
    settings.placements[frameName] = settings.placements[frameName] or {}

    return settings.placements[frameName]
end

function FrameMover:SavePlacement(frame, frameName)
    local placement = self:GetPlacement(frameName)
    if not placement then
        return
    end

    local point, _, relativePoint, xOffset, yOffset = frame:GetPoint(1)
    placement.point = point or "CENTER"
    placement.relativePoint = relativePoint or "CENTER"
    placement.x = math.floor((xOffset or 0) + 0.5)
    placement.y = math.floor((yOffset or 0) + 0.5)
    placement.scale = frame:GetScale() or 1
end

function FrameMover:ApplyPlacement(frame, frameName)
    local placement = self:GetPlacement(frameName)
    if not placement or not placement.point then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(placement.point, UIParent, placement.relativePoint, placement.x or 0, placement.y or 0)

    if placement.scale then
        frame:SetScale(placement.scale)
    end
end

function FrameMover:StartMoving(frame, frameName)
    if not self:IsInteractionAllowed() then
        return false
    end

    if not IsSafeFrame(frame) then
        return false
    end

    frame:SetMovable(true)

    local ok = pcall(frame.StartMoving, frame)
    if not ok then
        return false
    end

    self.movingFrames[frameName] = frame
    return true
end

function FrameMover:StopMoving(frame, frameName)
    local movingFrame = self.movingFrames[frameName]
    if not movingFrame then
        return
    end

    self.movingFrames[frameName] = nil

    if not IsSafeFrame(movingFrame) then
        return
    end

    pcall(movingFrame.StopMovingOrSizing, movingFrame)
    self:SavePlacement(movingFrame, frameName)
end

function FrameMover:StopAllMoving()
    for frameName, frame in pairs(self.movingFrames) do
        self:StopMoving(frame, frameName)
    end
end

function FrameMover:ScaleFrame(frame, frameName, delta)
    local settings = self:GetSettings()
    if not settings or settings.locked or not settings.allowScaling then
        return
    end

    if not IsModifierDown(settings.scaleModifier or "CTRL") then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if not IsSafeFrame(frame) then
        return
    end

    local currentScale = frame:GetScale() or 1
    local step = settings.scaleStep or 0.05
    local nextScale = Clamp(currentScale + (delta * step), settings.minScale or 0.7, settings.maxScale or 1.8)

    frame:SetScale(nextScale)
    self:SavePlacement(frame, frameName)
end

function FrameMover:AttachInputHandlers(inputFrame, targetFrame, frameName, options)
    if not CanReceiveInput(inputFrame) or not IsSafeFrame(targetFrame) then
        return
    end

    local inputKey = tostring(inputFrame) .. ":" .. frameName
    if self.attachedInputs[inputKey] then
        return
    end

    options = options or {}

    if not options.preserveMouseState then
        inputFrame:EnableMouse(true)
    end

    inputFrame:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            FrameMover:StartMoving(targetFrame, frameName)
        end
    end)

    inputFrame:HookScript("OnMouseUp", function()
        FrameMover:StopMoving(targetFrame, frameName)
    end)

    inputFrame:HookScript("OnDragStart", function(_, button)
        if button == "LeftButton" then
            FrameMover:StartMoving(targetFrame, frameName)
        end
    end)

    inputFrame:HookScript("OnDragStop", function()
        FrameMover:StopMoving(targetFrame, frameName)
    end)

    self.attachedInputs[inputKey] = true
end

function FrameMover:AttachMouseWheel(inputFrame, targetFrame, frameName)
    if not inputFrame or not inputFrame.HookScript or not inputFrame.EnableMouseWheel or not IsSafeFrame(targetFrame) then
        return
    end

    if inputFrame.IsForbidden and inputFrame:IsForbidden() then
        return
    end

    local inputKey = tostring(inputFrame) .. ":" .. frameName
    if self.attachedWheels[inputKey] then
        return
    end

    inputFrame:EnableMouseWheel(true)
    inputFrame:HookScript("OnMouseWheel", function(_, delta)
        FrameMover:ScaleFrame(targetFrame, frameName, delta)
    end)

    self.attachedWheels[inputKey] = true
end

function FrameMover:CreateDragHandle(frame, frameName)
    if self.dragHandles[frameName] or not CreateFrame then
        return
    end

    local profile = FRAME_PROFILES[frameName] or {}
    local dragHandle = CreateFrame("Frame", nil, frame)
    dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    dragHandle:SetHeight(profile.dragHeight or DEFAULT_DRAG_HEIGHT)

    if dragHandle.SetFrameLevel and frame.GetFrameLevel then
        dragHandle:SetFrameLevel((frame:GetFrameLevel() or 0) + 100)
    end

    dragHandle:EnableMouse(false)
    dragHandle:SetScript("OnUpdate", function(targetFrame)
        local settings = FrameMover:GetSettings()
        local enabled = settings
            and not settings.locked
            and IsModifierDown(settings.modifier or "SHIFT")
            and not (InCombatLockdown and InCombatLockdown())

        enabled = enabled and true or false
        if targetFrame.superNovaMouseEnabled ~= enabled then
            targetFrame:EnableMouse(enabled)
            targetFrame.superNovaMouseEnabled = enabled
        end
    end)

    self.dragHandles[frameName] = dragHandle
    self:AttachInputHandlers(dragHandle, frame, frameName, { preserveMouseState = true })
end

function FrameMover:ConfigureFrame(frame, frameName)
    if not IsSafeFrame(frame) then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if not self.attachedFrames[frameName] then
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")

        if frame.SetDontSavePosition then
            frame:SetDontSavePosition(true)
        end

        self:ApplyPlacement(frame, frameName)
        self.attachedFrames[frameName] = true
    end

    self:AttachInputHandlers(frame, frame, frameName)
    self:AttachMouseWheel(frame, frame, frameName)
    self:CreateDragHandle(frame, frameName)

    local profile = FRAME_PROFILES[frameName]
    if profile and profile.wheelTargets then
        for _, inputPath in ipairs(profile.wheelTargets) do
            self:AttachMouseWheel(ResolveFramePath(inputPath), frame, frameName)
        end
    end
end

function FrameMover:RegisterConfiguredFrames()
    local settings = self:GetSettings()
    if not settings or not settings.frames then
        return
    end

    for _, frameName in ipairs(settings.frames) do
        self:ConfigureFrame(_G[frameName], frameName)
    end
end

function FrameMover:Initialize()
    self:RegisterConfiguredFrames()

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_LOADED")

    events:SetScript("OnEvent", function()
        FrameMover:RegisterConfiguredFrames()

        if C_Timer and C_Timer.After then
            C_Timer.After(1, function()
                FrameMover:RegisterConfiguredFrames()
            end)
        end
    end)

    self.events = events
end

function FrameMover:PrintStatus()
    local settings = self:GetSettings()
    if not settings then
        return
    end

    local attachedCount = 0
    for _ in pairs(self.attachedFrames) do
        attachedCount = attachedCount + 1
    end

    SN:Print(string.format(
        "FrameMover: %s, modifier %s, %d frames attached.",
        settings.locked and "locked" or "unlocked",
        settings.modifier or "SHIFT",
        attachedCount
    ))
end

SN:RegisterModule("frameMover", FrameMover)
