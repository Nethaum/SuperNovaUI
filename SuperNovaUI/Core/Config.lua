local addonName, SN = ...

--[[
    The only Core file that differs between the Retail and the WoW Forever addons. Everything else in Core/ and
    Panel/ is shared (see tools/sync-shared.py) and reads its names from here.
]]

SN.config = {
    title = "SuperNovaUI",
    family = "SuperNovaUI",       -- profiles exported by one addon can be imported by the other
    flavor = "retail",
    database = "SuperNovaUIDB",
    characterDatabase = "SuperNovaUICharDB",
    compartmentFunction = "SuperNovaUI_AddonCompartmentFunc",
    slashCommands = { "/snui", "/supernova" },
    icon = "Interface\\AddOns\\SuperNovaUI\\Media\\Icons\\SuperNovaUI",
    panelName = "SuperNovaUIPanel",
    welcomeName = "SuperNovaUIWelcome",
}

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
SN.version = (getMetadata and getMetadata(addonName, "Version")) or "?"
