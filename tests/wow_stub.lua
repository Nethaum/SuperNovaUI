-- A small stand-in for the parts of the WoW API the addon uses, so the Lua runs outside the game.
--
-- Frames only answer the methods listed in KNOWN: a call to anything else raises "attempt to call method ...",
-- which is how a typo (or a method the real client does not have) shows up in the tests.

local KNOWN_NOOP = {
    "EnableKeyboard", "SetFrameLevel", "SetMovable", "EnableMouse", "SetClampedToScreen",
    "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetJustifyH", "SetJustifyV", "SetTextColor", "SetWordWrap",
    "SetOrientation", "SetMinMaxValues", "SetValueStep", "SetThumbTexture", "SetVertexColor", "SetAutoFocus",
    "SetMultiLine", "SetTextInsets", "ClearFocus", "EnableMouseWheel", "SetScrollChild",
    "UpdateScrollChildRect", "SetColorTexture", "SetTexture", "SetAlpha", "RegisterEvent", "UnregisterEvent",
    "SetFocus", "HighlightText", "SetValue", "SetVerticalScroll", "SetParent", "SetNumeric", "SetMaxLetters",
}

local KNOWN_NOOP_SET = {}
for _, name in ipairs(KNOWN_NOOP) do KNOWN_NOOP_SET[name] = true end

local BACKDROP_METHODS = { SetBackdrop = true, SetBackdropColor = true, SetBackdropBorderColor = true }

STUB = { printed = {}, reloaded = 0, installed = {}, frames = {}, locale = "enUS" }

local function NewFrame(kind, name, parent, template)
    local frame = { __kind = kind, __scripts = {}, __shown = true, __text = "", __width = 100, __height = 20, __template = template, __children = {}, __points = {} }
    local methods = {}

    function methods.SetScript(self, event, fn) self.__scripts[event] = fn end
    function methods.GetScript(self, event) return self.__scripts[event] end
    function methods.SetFrameStrata(self, strata) self.__strata = strata end
    function methods.GetFrameStrata(self) return self.__strata or "MEDIUM" end
    function methods.Show(self) self.__shown = true end
    function methods.Hide(self) self.__shown = false end
    function methods.IsShown(self) return self.__shown end
    function methods.SetShown(self, value) self.__shown = value and true or false end
    function methods.SetText(self, text) self.__text = tostring(text or "") end
    function methods.GetText(self) return self.__text end
    function methods.GetStringHeight() return 14 end
    function methods.GetStringWidth(self) return #self.__text * 7 end
    function methods.SetFontObject(self, font) self.__font = font end
    function methods.SetWidth(self, width) self.__width = width end
    function methods.SetHeight(self, height) self.__height = height end
    function methods.SetSize(self, width, height) self.__width = width; self.__height = height end
    function methods.GetWidth(self) return self.__width end
    function methods.GetHeight(self) return self.__height end
    function methods.GetVerticalScrollRange() return 0 end
    function methods.GetVerticalScroll() return 0 end
    function methods.GetThumbTexture(self) return self.__thumb end
    function methods.CreateTexture(self) return NewFrame("Texture", nil, self) end
    function methods.CreateFontString(self) return NewFrame("FontString", nil, self) end
    function methods.IsMouseOver() return false end
    function methods.SetPropagateKeyboardInput(self, value) self.__propagate = value end
    function methods.SetPoint(self, ...) table.insert(self.__points, { ... }) end
    function methods.ClearAllPoints(self) self.__points = {} end
    function methods.GetPoint(self, index)
        local p = self.__points[index or 1]
        if p then return p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0 end
    end

    if kind == "Slider" then
        function methods.SetThumbTexture(self) self.__thumb = NewFrame("Texture", nil, self) end
    end

    setmetatable(frame, {
        __index = function(_, key)
            if methods[key] then return methods[key] end
            if KNOWN_NOOP_SET[key] then return function() end end
            if BACKDROP_METHODS[key] and template and string.find(template, "Backdrop") then return function() end end
            return nil
        end,
    })

    if name then _G[name] = frame end
    table.insert(STUB.frames, frame)
    return frame
end

function CreateFrame(kind, name, parent, template) return NewFrame(kind, name, parent, template) end

-- Font objects: they take any setter and remember their name.
function CreateFont(name)
    local font = setmetatable({ __name = name }, { __index = function() return function() end end })
    font.SetFont = function(self, file, size) self.__file = file; self.__size = size end
    _G[name] = font
    return font
end

-- Runs a frame's script, the way the game would after a click or a key press.
function STUB.fire(frame, event, ...)
    local fn = frame.__scripts[event]
    if fn then fn(frame, ...) end
end

-- Finds frames by the text on them (buttons keep their text in .label).
function STUB.findButton(text)
    for _, frame in ipairs(STUB.frames) do
        if frame.label and frame.label.__text == text then return frame end
    end
end

UIParent = NewFrame("Frame", "UIParent")
UISpecialFrames = {}
BackdropTemplateMixin = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(STUB.printed, message) end }

function GetLocale() return STUB.locale end
function ReloadUI() STUB.reloaded = STUB.reloaded + 1 end
function GetBuildInfo() return "1.0", "1", "Jan 1 2026", STUB.tocVersion or 120105 end
C_AddOns = {
    DoesAddOnExist = function(name) return STUB.installed[name] == true end,
    GetAddOnEnableState = function(name) return (STUB.addonDisabled and STUB.addonDisabled[name]) and 0 or 2 end,
    GetAddOnMetadata = function() return "9.9.9" end,
}

-- Loads one addon file the way the client does: chunk(addonName, namespaceTable).
function STUB.load(path, addonName, namespace)
    local chunk, err = loadfile(path)
    if not chunk then error(err, 0) end
    chunk(addonName, namespace)
end

StaticPopupDialogs = {}
function StaticPopup_Show() end
OKAY = "OK"

tinsert = table.insert
UNKNOWN = "Unknown"

GameTooltip = NewFrame("GameTooltip", "GameTooltip")
GameTooltip.__lines = {}
function GameTooltip.SetOwner(self, owner) self.__owner = owner; self.__lines = {} end
function GameTooltip.SetText(self, text) self.__title = text end
function GameTooltip.AddLine(self, text) table.insert(self.__lines, text) end
function InCombatLockdown() return STUB.inCombat == true end

-- Macros and spells: a few functions the "Macro by cooldown" module uses.
STUB.macros = {}
STUB.now = 1000
STUB.timers = {}
function GetTime() return STUB.now end
C_Timer = { After = function(delay, fn) table.insert(STUB.timers, { at = STUB.now + delay, fn = fn }) end }
-- Moves the clock and runs the timers that are due, in order.
function STUB.advance(seconds)
    STUB.now = STUB.now + seconds
    table.sort(STUB.timers, function(a, b) return a.at < b.at end)
    while STUB.timers[1] and STUB.timers[1].at <= STUB.now do
        table.remove(STUB.timers, 1).fn()
    end
end
STUB.cooldowns = {}
STUB.spellNames = {}
MAX_CHARACTER_MACROS = 18
function GetNumMacros() return 0, #STUB.macros end
function GetMacroIndexByName(name)
    for index, macro in ipairs(STUB.macros) do
        if macro.name == name then return index end
    end
    return 0
end
function GetMacroBody(index) return STUB.macros[index] and STUB.macros[index].body end
function EditMacro(index, name, icon, body)
    if STUB.inCombat then error("macros cannot be edited in combat") end
    STUB.macros[index].body = body
    return index
end
function CreateMacro(name, icon, body, perCharacter)
    if STUB.inCombat then error("macros cannot be created in combat") end
    if STUB.failCreate then error(STUB.failCreate) end
    if #STUB.macros >= (STUB.macroLimit or MAX_CHARACTER_MACROS) then error("too many macros") end
    if STUB.numericIconOnly and type(icon) == "string" then error("bad icon") end
    table.insert(STUB.macros, { name = name, icon = icon, body = body, perCharacter = perCharacter })
    return #STUB.macros
end
function GetSpellCooldown(spell)
    local entry = STUB.cooldowns[spell]
    if entry == nil then return nil end
    return entry[1], entry[2], 1
end
function GetSpellInfo(id) return STUB.spellNames[id] end
function IsControlKeyDown() return STUB.ctrl == true end
