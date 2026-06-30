local addonName, SN = ...

local DEFAULT_DATABASE = {
    debug = false,
    modules = {
        frameMover = {
            enabled = true,
            locked = false,
            modifier = "SHIFT",
            allowScaling = true,
            scaleModifier = "CTRL",
            scaleStep = 0.05,
            minScale = 0.70,
            maxScale = 1.80,
            frames = {
                "CharacterFrame",
                "SpellBookFrame",
                "PlayerSpellsFrame",
                "ProfessionsFrame",
                "CollectionsJournal",
                "EncounterJournal",
                "PVEFrame",
                "FriendsFrame",
                "GuildFrame",
                "CommunitiesFrame",
                "AuctionHouseFrame",
                "ItemUpgradeFrame",
                "CovenantMissionFrame",
                "GarrisonLandingPage",
                "WorldMapFrame",
            },
            placements = {},
        },
        chatHistory = {
            enabled = true,
            maxLines = 64,
            useArrowKeys = true,
        },
    },
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
    SuperNovaUIDB = SuperNovaUIDB or {}
    SuperNovaUICharDB = SuperNovaUICharDB or {}

    CopyDefaults(DEFAULT_DATABASE, SuperNovaUIDB)

    self.db = SuperNovaUIDB
    self.charDB = SuperNovaUICharDB
end

function SN:GetModuleSettings(moduleName)
    if not self.db or not self.db.modules then
        return nil
    end

    return self.db.modules[moduleName]
end

function SN:ResetFramePlacements()
    local settings = self:GetModuleSettings("frameMover")
    if not settings then
        return
    end

    settings.placements = {}
end
