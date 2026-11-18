local addonName, SN = ...

--[[
    Profile export and import.

    A profile is the module settings (which modules are on and their options). The export text is:

        SNUI1:<checksum>:<base64 of the data>

    The data is a small JSON-like text written and read by the code below. Nothing is ever run (no loadstring), the
    reader accepts only strings, numbers, booleans and nested tables, and the import keeps only modules and option
    values that the addon itself knows and that pass SN:ValidateOptionValue.
]]

local FORMAT_VERSION = 1
local PREFIX = "SNUI" .. FORMAT_VERSION
local MAX_TEXT = 60000
local MAX_DEPTH = 6
local MAX_NODES = 4000

-- Writer ---------------------------------------------------------------------------------------------------------

local ESCAPES = { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function EncodeString(value)
    return '"' .. string.gsub(value, '[\\"\n\r\t]', ESCAPES) .. '"'
end

local function Encode(value, depth)
    local kind = type(value)

    if kind == "string" then
        return EncodeString(value)
    elseif kind == "number" then
        return string.format("%.14g", value)
    elseif kind == "boolean" then
        return value and "true" or "false"
    elseif kind == "table" then
        if depth > MAX_DEPTH then
            return "null"
        end

        local keys = {}

        for key in pairs(value) do
            table.insert(keys, tostring(key))
        end

        table.sort(keys)

        local parts = {}

        for _, key in ipairs(keys) do
            local item = value[key]

            if item == nil then
                item = value[tonumber(key)]
            end

            if type(item) ~= "function" and type(item) ~= "userdata" then
                table.insert(parts, EncodeString(key) .. ":" .. Encode(item, depth + 1))
            end
        end

        return "{" .. table.concat(parts, ",") .. "}"
    end

    return "null"
end

function SN:Serialize(value)
    return Encode(value, 1)
end

-- Reader ---------------------------------------------------------------------------------------------------------

local UNESCAPES = { ["\\"] = "\\", ['"'] = '"', n = "\n", r = "\r", t = "\t" }

local function Fail(message)
    error({ parseError = message }, 0)
end

local function SkipSpace(text, position)
    return (string.find(text, "[^ \n\r\t]", position)) or (#text + 1)
end

local function ReadString(text, position)
    local pieces = {}
    position = position + 1

    while true do
        local character = string.sub(text, position, position)

        if character == "" then
            Fail("unterminated string")
        elseif character == '"' then
            return table.concat(pieces), position + 1
        elseif character == "\\" then
            local replacement = UNESCAPES[string.sub(text, position + 1, position + 1)]

            if not replacement then
                Fail("bad escape")
            end

            table.insert(pieces, replacement)
            position = position + 2
        else
            table.insert(pieces, character)
            position = position + 1
        end
    end
end

local function ReadValue(text, position, depth, counter)
    counter.nodes = counter.nodes + 1

    if counter.nodes > MAX_NODES or depth > MAX_DEPTH then
        Fail("too large")
    end

    position = SkipSpace(text, position)
    local character = string.sub(text, position, position)

    if character == '"' then
        return ReadString(text, position)
    elseif character == "{" then
        local result = {}
        position = SkipSpace(text, position + 1)

        if string.sub(text, position, position) == "}" then
            return result, position + 1
        end

        while true do
            position = SkipSpace(text, position)

            if string.sub(text, position, position) ~= '"' then
                Fail("key expected")
            end

            local key
            key, position = ReadString(text, position)
            position = SkipSpace(text, position)

            if string.sub(text, position, position) ~= ":" then
                Fail("colon expected")
            end

            local item
            item, position = ReadValue(text, position + 1, depth + 1, counter)
            result[key] = item
            position = SkipSpace(text, position)

            local separator = string.sub(text, position, position)

            if separator == "}" then
                return result, position + 1
            elseif separator ~= "," then
                Fail("comma expected")
            end

            position = position + 1
        end
    elseif string.sub(text, position, position + 3) == "true" then
        return true, position + 4
    elseif string.sub(text, position, position + 4) == "false" then
        return false, position + 5
    elseif string.sub(text, position, position + 3) == "null" then
        return nil, position + 4
    end

    local number = string.match(text, "^-?%d+%.?%d*[eE]?[+-]?%d*", position)

    if not number or number == "" or not tonumber(number) then
        Fail("value expected")
    end

    return tonumber(number), position + #number
end

-- Returns true and the value, or false and a reason.
function SN:Deserialize(text)
    if type(text) ~= "string" or #text > MAX_TEXT then
        return false, "too large"
    end

    local ok, value, position = pcall(ReadValue, text, 1, 1, { nodes = 0 })

    if not ok then
        return false, type(value) == "table" and value.parseError or "unreadable"
    end

    if SkipSpace(text, position) <= #text then
        return false, "extra text"
    end

    return true, value
end

-- Base64 and checksum ----------------------------------------------------------------------------------------------

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ALPHABET_INDEX = {}

for index = 1, #ALPHABET do
    ALPHABET_INDEX[string.sub(ALPHABET, index, index)] = index - 1
end

function SN:Base64Encode(data)
    local output = {}

    for position = 1, #data, 3 do
        local first, second, third = string.byte(data, position, position + 2)
        local block = first * 65536 + (second or 0) * 256 + (third or 0)
        local a = math.floor(block / 262144) % 64
        local b = math.floor(block / 4096) % 64
        local c = math.floor(block / 64) % 64
        local d = block % 64

        table.insert(output, string.sub(ALPHABET, a + 1, a + 1))
        table.insert(output, string.sub(ALPHABET, b + 1, b + 1))
        table.insert(output, second and string.sub(ALPHABET, c + 1, c + 1) or "=")
        table.insert(output, third and string.sub(ALPHABET, d + 1, d + 1) or "=")
    end

    return table.concat(output)
end

function SN:Base64Decode(text)
    if #text % 4 ~= 0 or string.find(text, "[^A-Za-z0-9+/=]") then
        return nil
    end

    local output = {}

    for position = 1, #text, 4 do
        local chunk = string.sub(text, position, position + 3)
        local padding = #string.match(chunk, "=*$")

        if padding > 2 or (padding > 0 and position + 3 < #text) then
            return nil
        end

        local block = 0

        for offset = 1, 4 do
            local character = string.sub(chunk, offset, offset)
            block = block * 64 + (character == "=" and 0 or ALPHABET_INDEX[character])
        end

        local first = math.floor(block / 65536) % 256
        local second = math.floor(block / 256) % 256
        local third = block % 256

        table.insert(output, string.char(first))

        if padding < 2 then
            table.insert(output, string.char(second))
        end

        if padding < 1 then
            table.insert(output, string.char(third))
        end
    end

    return table.concat(output)
end

local function Checksum(text)
    local hash = 5381

    for position = 1, #text do
        hash = (hash * 33 + string.byte(text, position)) % 4294967296
    end

    return string.format("%08x", hash)
end

-- Export ---------------------------------------------------------------------------------------------------------

function SN:BuildProfileData()
    local modules = {}

    for _, moduleName in ipairs(self:GetToggleableModules()) do
        local settings = self:GetModuleSettings(moduleName)

        if settings then
            local copy = { enabled = settings.enabled ~= false }
            local info = self:GetInfo(moduleName)

            for _, option in ipairs(info.options or {}) do
                if option.key and settings[option.key] ~= nil then
                    copy[option.key] = settings[option.key]
                end
            end

            modules[moduleName] = copy
        end
    end

    return {
        format = FORMAT_VERSION,
        family = self.config.family,
        flavor = self.config.flavor,
        version = self.version,
        modules = modules,
    }
end

function SN:ExportProfile()
    local payload = self:Serialize(self:BuildProfileData())
    return PREFIX .. ":" .. Checksum(payload) .. ":" .. self:Base64Encode(payload)
end

-- Import ---------------------------------------------------------------------------------------------------------

-- Reads and checks a profile text. Returns true and the data, or false and the key of the message to show.
function SN:ReadProfile(text)
    text = string.gsub(text or "", "%s+", "")

    if text == "" then
        return false, "profile_empty"
    end

    local prefix, checksum, encoded = string.match(text, "^(%w+):(%x+):([A-Za-z0-9+/=]*)$")

    if not prefix or string.sub(prefix, 1, 4) ~= "SNUI" then
        return false, "profile_err_format"
    end

    if prefix ~= PREFIX then
        local number = tonumber(string.sub(prefix, 5))
        return false, (number and number > FORMAT_VERSION) and "profile_err_version" or "profile_err_format"
    end

    local payload = self:Base64Decode(encoded)

    if not payload or Checksum(payload) ~= string.lower(checksum) then
        return false, "profile_err_checksum"
    end

    local ok, data = self:Deserialize(payload)

    if not ok or type(data) ~= "table" or type(data.modules) ~= "table" then
        return false, "profile_err_data"
    end

    if data.family ~= self.config.family then
        return false, "profile_err_family"
    end

    return true, data
end

-- Works out what an import would change, without changing anything. Returns a list of
-- { module = name, enabled = bool|nil, options = { key = value } } plus a "different game version" flag.
function SN:PlanProfileImport(data)
    local plan = {}

    for _, moduleName in ipairs(self:GetToggleableModules()) do
        local incoming = data.modules[moduleName]
        local settings = self:GetModuleSettings(moduleName)

        if type(incoming) == "table" and settings then
            local change = { module = moduleName, options = {} }
            local different = false

            if type(incoming.enabled) == "boolean" and incoming.enabled ~= (settings.enabled ~= false) then
                change.enabled = incoming.enabled
                different = true
            end

            for key, value in pairs(incoming) do
                local option = self:FindOption(moduleName, key)

                if option then
                    local valid, cleaned = self:ValidateOptionValue(option, value)

                    if valid and cleaned ~= self:GetOption(moduleName, key) then
                        change.options[key] = cleaned
                        different = true
                    end
                end
            end

            if different then
                table.insert(plan, change)
            end
        end
    end

    return plan, data.flavor ~= self.config.flavor
end

function SN:ApplyProfileImport(plan)
    for _, change in ipairs(plan) do
        for key, value in pairs(change.options) do
            self:SetOption(change.module, key, value)
        end

        if change.enabled ~= nil then
            self:SetModuleEnabled(change.module, change.enabled)
        end
    end

    -- An imported profile counts as an answer to the welcome question.
    self.db.firstRunDone = true
end
