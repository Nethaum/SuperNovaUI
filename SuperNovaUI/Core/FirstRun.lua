local addonName, SN = ...

--[[
    The question asked the first time the addon loads: "load the modules that work with the addons you have?".
    Only the recommended modules are offered (not the ones that would be useless or duplicate another addon), and they
    are already on, so "yes" only records the answer; "no" turns everything off and opens the panel so the player
    chooses.
]]

function SN:ShouldAskFirstRun()
    return self.db ~= nil and not self.db.firstRunDone and #self:GetRecommendedModules() > 0
end

function SN:MaybeAskFirstRun()
    if self:ShouldAskFirstRun() and self.ShowWelcome then
        self:ShowWelcome()
    end
end

function SN:AnswerFirstRun(enableAll)
    self.db.firstRunDone = true

    if enableAll then
        self:ResolveDefaultEnabled()
        self:NotifyChange()
    else
        self:SetAllEnabled(false)

        if self.OpenPanel then
            self:OpenPanel()
        end
    end
end

function SN:AskFirstRunAgain()
    self.db.firstRunDone = false
    self:MaybeAskFirstRun()
end
