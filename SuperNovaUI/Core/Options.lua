local addonName, SN = ...

--[[
    Module options. A module lists them in info.options and the panel draws them:

        { type = "header", text = L }
        { type = "text", text = L }
        { type = "toggle", key = "x", text = L, desc = L, default = true }
        { type = "choice", key = "x", text = L, values = { { value = "a", text = L }, ... }, default = "a" }
        { type = "slider", key = "x", text = L, min = 0, max = 10, step = 1, default = 5 }
        { type = "button", text = L, onClick = function(module) end }

    Values live in the module's account settings (db.modules[name][key]). Anything that comes from outside (an imported
    profile) goes through SN:ValidateOptionValue first.
]]

local VALUE_TYPES = { toggle = true, choice = true, slider = true }

function SN:FindOption(moduleName, key)
    local info = self:GetInfo(moduleName)

    if not info or not info.options then
        return nil
    end

    for _, option in ipairs(info.options) do
        if VALUE_TYPES[option.type] and option.key == key then
            return option
        end
    end

    return nil
end

-- Returns true and the cleaned value, or false when the value does not fit the option.
function SN:ValidateOptionValue(option, value)
    if not option then
        return false
    end

    if option.type == "toggle" then
        if type(value) ~= "boolean" then
            return false
        end

        return true, value
    end

    if option.type == "choice" then
        for _, entry in ipairs(option.values or {}) do
            if entry.value == value then
                return true, value
            end
        end

        return false
    end

    if option.type == "slider" then
        if type(value) ~= "number" or value ~= value then
            return false
        end

        local step = option.step or 1
        value = math.max(option.min, math.min(option.max, value))
        value = option.min + math.floor((value - option.min) / step + 0.5) * step
        return true, math.max(option.min, math.min(option.max, value))
    end

    return false
end

function SN:GetOption(moduleName, key)
    local option = self:FindOption(moduleName, key)
    local settings = self:GetModuleSettings(moduleName)

    if settings and settings[key] ~= nil then
        return settings[key]
    end

    return option and option.default
end

function SN:SetOption(moduleName, key, value)
    local option = self:FindOption(moduleName, key)
    local settings = self:GetModuleSettings(moduleName)

    if not option or not settings then
        return false
    end

    local valid, cleaned = self:ValidateOptionValue(option, value)

    if not valid then
        return false
    end

    settings[key] = cleaned

    local module = self.modules[moduleName]

    if module and module.OnOptionChanged then
        module:OnOptionChanged(key, cleaned)
    end

    self:NotifyChange()
    return true
end

-- Puts the options back to their defaults and turns the module on.
function SN:ResetModule(moduleName)
    local info = self:GetInfo(moduleName)
    local settings = self:GetModuleSettings(moduleName)

    if not info or not settings then
        return
    end

    for _, option in ipairs(info.options or {}) do
        if VALUE_TYPES[option.type] then
            settings[option.key] = nil
        end
    end

    self:SetModuleEnabled(moduleName, true)
end
