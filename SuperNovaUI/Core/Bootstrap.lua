local addonName, SN = ...

SN.addonName = addonName
SN.modules = SN.modules or {}
SN.moduleOrder = SN.moduleOrder or {}
SN.activeModules = SN.activeModules or {}

local eventFrame = CreateFrame("Frame")
SN.eventFrame = eventFrame

function SN:RegisterModule(name, module)
    if not name or not module then
        return
    end

    if self.modules[name] then
        return
    end

    module.name = name
    module.addon = self
    self.modules[name] = module
    table.insert(self.moduleOrder, name)
end

function SN:GetModule(name)
    return self.modules and self.modules[name]
end

-- Starts every module that is enabled and whose addon (if it needs one) is installed.
function SN:InitializeModules()
    for _, moduleName in ipairs(self.moduleOrder) do
        local module = self.modules[moduleName]

        if module and self:IsModuleRunnable(moduleName) then
            self:ActivateModule(moduleName)
        end
    end
end

function SN:ActivateModule(moduleName)
    local module = self.modules[moduleName]

    if not module or self.activeModules[moduleName] then
        return
    end

    self.activeModules[moduleName] = true

    if module.Initialize then
        module:Initialize()
    end
end

function SN:HandleAddonLoaded(loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    self:InitializeDatabase()
    self:ResolveDefaultEnabled()
    self:UpdateLocale(self.db.language)
    self:RegisterSlashCommands()
    self:InitializeModules()
end

function SN:HandlePlayerLogin()
    self:MaybeAskFirstRun()
end

local compartmentFunction = SN.config and SN.config.compartmentFunction
if compartmentFunction then
    _G[compartmentFunction] = function()
        if SN and SN.HandleSlashCommand then
            SN:HandleSlashCommand("")
        end
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        SN:HandleAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        SN:HandlePlayerLogin()
    end
end)
