local addonName, SN = ...

--[[
    What the panel knows about modules.

    A module describes itself with `module.info` before it registers:

        info = {
            category = "pets",                 -- one of SN.categories
            kind = "fix",                      -- "fix", "compat", "feature" or "core" (a page that cannot be turned off)
            requiresAddon = "Rematch",         -- optional: the module only does something when this addon is installed
            conflictsWith = { "OtherAddon" },  -- optional: installed addons that already do what the module does
            isUseful = function(module) end,   -- optional: return false when the module has nothing to do for this player
            name = { enUS = "...", ptBR = "..." },
            desc = { enUS = "...", ptBR = "..." },
            order = 10,                        -- optional, inside its category
            options = { ... },                 -- optional, see Panel/Options.lua
            BuildPage = function(page) end,    -- optional: draws the whole right side by hand
            GetStatus = function(module) return "active" | "warning", text end,   -- optional
            help = { "/snui x - what x does" },  -- optional: lines for /snui help
        }

    Optional module hooks: Initialize(), SetEnabled(on) (start or stop on the fly), OnToggled(on) (called on every change of
    the switch, also when a reload is needed), OnOptionChanged(key, value), HandleCommand(arg).

    A module is on by default, except when it would be useless or would duplicate an addon the player already runs
    (no addon it needs, a conflicting addon, or isUseful returning false): then it starts off. That is only a default:
    SN:ResolveDefaultEnabled recomputes it on every load until the player touches the switch, and from that moment
    (settings.chosen) the choice is kept. SN:SetModuleEnabled saves the choice and, when the module cannot
    start or stop on the fly (no module:SetEnabled), remembers that a reload is needed.
]]

SN.categories = {
    { id = "general", order = 1, name = "cat_general" },
    { id = "compat", order = 2, name = "cat_compat" },
    { id = "groups", order = 3, name = "cat_groups" },
    { id = "pets", order = 4, name = "cat_pets" },
    { id = "interface", order = 5, name = "cat_interface" },
    { id = "tools", order = 6, name = "cat_tools" },
}

SN.pendingReload = SN.pendingReload or {}

local KIND_STRINGS = {
    core = "kind_core",
    fix = "kind_fix",
    compat = "kind_compat",
    feature = "kind_feature",
}

function SN:GetKindText(kind)
    return self:T(KIND_STRINGS[kind] or "kind_feature")
end

function SN:IsAddonInstalled(addon)
    if not addon then
        return true
    end

    if C_AddOns and C_AddOns.DoesAddOnExist then
        return C_AddOns.DoesAddOnExist(addon) and true or false
    end

    if GetAddOnInfo then
        local foundName, _, _, _, reason = GetAddOnInfo(addon)
        return foundName ~= nil and reason ~= "MISSING"
    end

    return false
end

-- Installed and not disabled in the character's AddOns list (when the game cannot say, installed is enough).
function SN:IsAddonRunning(addon)
    if not self:IsAddonInstalled(addon) then
        return false
    end

    local player = UnitName and UnitName("player")

    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, addon, player)

        if ok and type(state) == "number" then
            return state > 0
        end
    elseif GetAddOnEnableState then
        local ok, state = pcall(GetAddOnEnableState, player, addon)

        if ok and type(state) == "number" then
            return state > 0
        end
    end

    return true
end

function SN:GetInfo(moduleName)
    local module = self.modules[moduleName]
    return module and module.info or nil
end

function SN:GetModuleDisplayName(moduleName)
    local info = self:GetInfo(moduleName)
    return self:Loc(info and info.name or moduleName)
end

-- Core pages are never switched; every other module can be.
function SN:IsToggleable(moduleName)
    local info = self:GetInfo(moduleName)
    return info ~= nil and info.kind ~= "core"
end

function SN:IsModuleEnabled(moduleName)
    if not self:IsToggleable(moduleName) then
        return true
    end

    local settings = self:GetModuleSettings(moduleName)
    return settings == nil or settings.enabled ~= false
end

-- The addon a module works on is installed (or the module needs none).
function SN:IsModuleAvailable(moduleName)
    local info = self:GetInfo(moduleName)
    return info == nil or self:IsAddonInstalled(info.requiresAddon)
end

-- Addons the player runs that already do what the module does (info.conflictsWith).
function SN:GetModuleConflicts(moduleName)
    local info = self:GetInfo(moduleName)
    local found = {}

    for _, addon in ipairs(info and info.conflictsWith or {}) do
        if self:IsAddonRunning(addon) then
            table.insert(found, addon)
        end
    end

    return found
end

-- Should the module start on for this player: it has what it needs, nothing else covers it, and it has work to do.
function SN:IsModuleRecommended(moduleName)
    if not self:IsToggleable(moduleName) then
        return true
    end

    local info = self:GetInfo(moduleName)

    if not self:IsModuleAvailable(moduleName) or #self:GetModuleConflicts(moduleName) > 0 then
        return false
    end

    if info.isUseful then
        local ok, useful = pcall(info.isUseful, self.modules[moduleName])

        if ok and useful == false then
            return false
        end
    end

    return true
end

-- A module the player never switched follows the recommendation; one they switched keeps their choice.
function SN:ResolveDefaultEnabled()
    for _, moduleName in ipairs(self:GetToggleableModules()) do
        local settings = self:GetModuleSettings(moduleName)

        if settings and not settings.chosen then
            settings.enabled = self:IsModuleRecommended(moduleName)
        end
    end
end

function SN:GetRecommendedModules()
    local list = {}

    for _, moduleName in ipairs(self:GetToggleableModules()) do
        if self:IsModuleRecommended(moduleName) then
            table.insert(list, moduleName)
        end
    end

    return list
end

function SN:IsModuleRunnable(moduleName)
    return self:IsModuleEnabled(moduleName) and self:IsModuleAvailable(moduleName)
end

function SN:IsModuleActive(moduleName)
    return self.activeModules[moduleName] == true
end

-- "active", "disabled", "missing", "pending" or "warning", plus an optional detail text.
function SN:GetModuleStatus(moduleName)
    local module = self.modules[moduleName]
    local info = self:GetInfo(moduleName)

    if not module or not info then
        return "disabled"
    end

    if not self:IsToggleable(moduleName) then
        return "active"
    end

    if self.pendingReload[moduleName] then
        return "pending"
    end

    if not self:IsModuleAvailable(moduleName) then
        return "missing"
    end

    if not self:IsModuleEnabled(moduleName) then
        return "disabled"
    end

    local conflicts = self:GetModuleConflicts(moduleName)

    if #conflicts > 0 then
        return "warning", self:T("status_conflict", table.concat(conflicts, ", "))
    end

    if info.GetStatus then
        local ok, status, text = pcall(info.GetStatus, module)

        if ok and status then
            return status, text
        end
    end

    return "active"
end

function SN:GetStatusText(status)
    return self:T("status_" .. tostring(status))
end

-- Turns a module on or off. Returns true when it took effect right away, false when a reload is needed.
-- A change the player makes is remembered as their choice; `asDefault` is for the addon's own recommendation.
function SN:SetModuleEnabled(moduleName, enabled, asDefault)
    if not self:IsToggleable(moduleName) then
        return true
    end

    local settings = self:GetModuleSettings(moduleName)
    local module = self.modules[moduleName]

    if not settings or not module then
        return true
    end

    enabled = enabled and true or false
    settings.enabled = enabled

    if not asDefault then
        settings.chosen = true
    end

    if module.OnToggled then
        module:OnToggled(enabled)
    end

    local shouldRun = enabled and self:IsModuleAvailable(moduleName)
    local isRunning = self:IsModuleActive(moduleName)

    if shouldRun == isRunning then
        self.pendingReload[moduleName] = nil
        self:NotifyChange()
        return true
    end

    if module.SetEnabled then
        module:SetEnabled(shouldRun)

        if shouldRun then
            self:ActivateModule(moduleName)
        else
            self.activeModules[moduleName] = nil
        end

        self.pendingReload[moduleName] = nil
        self:NotifyChange()
        return true
    end

    self.pendingReload[moduleName] = true
    self:NotifyChange()
    return false
end

-- Every module the user can switch (core pages are not in this list).
function SN:GetToggleableModules()
    local list = {}

    for _, moduleName in ipairs(self.moduleOrder) do
        if self:IsToggleable(moduleName) then
            table.insert(list, moduleName)
        end
    end

    return list
end

-- Modules that work with what the player has installed.
function SN:GetCompatibleModules()
    local list = {}

    for _, moduleName in ipairs(self:GetToggleableModules()) do
        if self:IsModuleAvailable(moduleName) then
            table.insert(list, moduleName)
        end
    end

    return list
end

function SN:SetAllEnabled(enabled)
    for _, moduleName in ipairs(self:GetToggleableModules()) do
        self:SetModuleEnabled(moduleName, enabled)
    end
end

function SN:CountEnabledModules()
    local total, enabled = 0, 0

    for _, moduleName in ipairs(self:GetToggleableModules()) do
        total = total + 1

        if self:IsModuleEnabled(moduleName) then
            enabled = enabled + 1
        end
    end

    return enabled, total
end

function SN:HasPendingReload()
    return next(self.pendingReload) ~= nil
end

-- The tree the panel shows: categories in order, each with its modules in order. A filter keeps only the modules
-- whose name or description contain it; categories left empty are dropped.
function SN:GetModuleTree(filter)
    local needle = filter and string.lower(filter) or ""
    local tree = {}

    for _, category in ipairs(self.categories) do
        local members = {}

        for _, moduleName in ipairs(self.moduleOrder) do
            local info = self:GetInfo(moduleName)

            if info and (info.category or "tools") == category.id then
                local matches = needle == ""
                    or string.find(string.lower(self:Loc(info.name)), needle, 1, true)
                    or string.find(string.lower(self:Loc(info.desc)), needle, 1, true)

                if matches then
                    table.insert(members, moduleName)
                end
            end
        end

        table.sort(members, function(first, second)
            local firstOrder = self:GetInfo(first).order or 100
            local secondOrder = self:GetInfo(second).order or 100

            if firstOrder ~= secondOrder then
                return firstOrder < secondOrder
            end

            return self:GetModuleDisplayName(first) < self:GetModuleDisplayName(second)
        end)

        if #members > 0 then
            table.insert(tree, { id = category.id, name = self:T(category.name), modules = members })
        end
    end

    return tree
end

-- Called after any change that the panel should show.
function SN:NotifyChange()
    if self.RefreshPanel then
        self:RefreshPanel()
    end
end
