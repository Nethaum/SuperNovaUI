local addonName, SN = ...

local PREFIX = "|cff38bdf8SuperNovaUI|r"

function SN:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. ": " .. tostring(message))
end

function SN:Debug(moduleName, message)
    if self.db and self.db.debug then
        self:Print("[" .. tostring(moduleName) .. "] " .. tostring(message))
    end
end
