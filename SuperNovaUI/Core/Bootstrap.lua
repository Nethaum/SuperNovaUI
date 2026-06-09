local addonName, SN = ...

SN.addonName = addonName
SN.modules = SN.modules or {}
SN.moduleOrder = SN.moduleOrder or {}

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

function SN:InitializeModules()
    for _, moduleName in ipairs(self.moduleOrder) do
        local module = self.modules[moduleName]
        local settings = self:GetModuleSettings(moduleName)

        if module and settings and settings.enabled ~= false and module.Initialize then
            module:Initialize()
        end
    end
end

function SN:HandleAddonLoaded(loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    self:InitializeDatabase()
    self:RegisterSlashCommands()
    self:InitializeModules()

    self:Print("loaded. Use /snui for commands.")
end

function SuperNovaUI_AddonCompartmentFunc()
    if SN and SN.HandleSlashCommand then
        SN:HandleSlashCommand("")
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        SN:HandleAddonLoaded(...)
    end
end)
