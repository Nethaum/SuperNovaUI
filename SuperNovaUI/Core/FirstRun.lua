local addonName, SN = ...

--[[
    The question asked the first time the addon loads: "load all the modules that work with the addons you have?".
    Modules are on by default, so "yes" only records the answer; "no" turns everything off and opens the panel so the
    player chooses.
]]

function SN:ShouldAskFirstRun()
    return self.db ~= nil and not self.db.firstRunDone and #self:GetCompatibleModules() > 0
end

function SN:MaybeAskFirstRun()
    if self:ShouldAskFirstRun() and self.ShowWelcome then
        self:ShowWelcome()
    end
end

function SN:AnswerFirstRun(enableAll)
    self.db.firstRunDone = true
    self:SetAllEnabled(enableAll)

    if not enableAll and self.OpenPanel then
        self:OpenPanel()
    end
end

function SN:AskFirstRunAgain()
    self.db.firstRunDone = false
    self:MaybeAskFirstRun()
end
