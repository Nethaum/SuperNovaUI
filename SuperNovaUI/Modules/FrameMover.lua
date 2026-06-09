local addonName, SN = ...

local FrameMover = {
    attachedFrames = {},
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

local function IsSafeFrame(frame)
    if not frame then
        return false
    end

    if frame.IsForbidden and frame:IsForbidden() then
        return false
    end

    return frame.SetMovable and frame.RegisterForDrag and frame.StartMoving and frame.StopMovingOrSizing
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
        return
    end

    if not IsSafeFrame(frame) then
        return
    end

    frame:StartMoving()
end

function FrameMover:StopMoving(frame, frameName)
    if not IsSafeFrame(frame) then
        return
    end

    frame:StopMovingOrSizing()
    self:SavePlacement(frame, frameName)
end

function FrameMover:ScaleFrame(frame, frameName, delta)
    local settings = self:GetSettings()
    if not settings or not settings.allowScaling then
        return
    end

    if not IsModifierDown(settings.scaleModifier or "CTRL") then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local currentScale = frame:GetScale() or 1
    local step = settings.scaleStep or 0.05
    local nextScale = Clamp(currentScale + (delta * step), settings.minScale or 0.7, settings.maxScale or 1.8)

    frame:SetScale(nextScale)
    self:SavePlacement(frame, frameName)
end

function FrameMover:ConfigureFrame(frame, frameName)
    if self.attachedFrames[frameName] or not IsSafeFrame(frame) then
        return
    end

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")

    if frame.SetDontSavePosition then
        frame:SetDontSavePosition(true)
    end

    frame:HookScript("OnDragStart", function(targetFrame)
        FrameMover:StartMoving(targetFrame, frameName)
    end)

    frame:HookScript("OnDragStop", function(targetFrame)
        FrameMover:StopMoving(targetFrame, frameName)
    end)

    if frame.EnableMouseWheel and frame.HookScript then
        frame:EnableMouseWheel(true)
        frame:HookScript("OnMouseWheel", function(targetFrame, delta)
            FrameMover:ScaleFrame(targetFrame, frameName, delta)
        end)
    end

    self:ApplyPlacement(frame, frameName)
    self.attachedFrames[frameName] = true
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
