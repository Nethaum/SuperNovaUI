local addonName, SN = ...

local DEFAULT_DATABASE = {
    debug = false,
    language = "auto",
    firstRunDone = false,
    modules = {},
    ui = { collapsed = {} },
}

local DEFAULT_CHARACTER_DATABASE = {
    modules = {},
}

local function CopyDefaults(defaults, target)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end

            CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function SN:InitializeDatabase()
    local config = self.config
    _G[config.database] = _G[config.database] or {}
    _G[config.characterDatabase] = _G[config.characterDatabase] or {}

    -- Saved before modules could start off by default: what the player already had stays as it is.
    local saved = _G[config.database]

    if saved.firstRunDone and saved.policyVersion == nil and type(saved.modules) == "table" then
        for _, settings in pairs(saved.modules) do
            if type(settings) == "table" and settings.chosen == nil then
                settings.chosen = true
            end
        end
    end

    saved.policyVersion = 1

    CopyDefaults(DEFAULT_DATABASE, _G[config.database])
    CopyDefaults(DEFAULT_CHARACTER_DATABASE, _G[config.characterDatabase])

    self.db = _G[config.database]
    self.charDB = _G[config.characterDatabase]
end

-- Modules register their own defaults here before InitializeDatabase runs.
function SN:RegisterModuleDefaults(moduleName, accountDefaults, characterDefaults)
    DEFAULT_DATABASE.modules[moduleName] = accountDefaults or { enabled = true }
    DEFAULT_CHARACTER_DATABASE.modules[moduleName] = characterDefaults or {}
end

function SN:GetModuleSettings(moduleName)
    if not self.db or not self.db.modules then
        return nil
    end

    return self.db.modules[moduleName]
end

function SN:GetCharacterModuleSettings(moduleName)
    if not self.charDB or not self.charDB.modules then
        return nil
    end

    return self.charDB.modules[moduleName]
end
