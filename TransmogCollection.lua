-- Main initialization file - coordinates all modules
-- @author Abracadaniel22

local addonName, addon = ...

local function InitializeAddon()
    addon.API.Initialize()
    addon.TooltipsModule.Initialize()
    addon.ItemOverlayModule.Initialize()
    addon.ArkInventoryModule.Initialize()
    addon.API.PrintAddonMessage("Addon loaded. Type /tc for options.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        InitializeAddon()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)