-- Tooltips Module handles showing transmog collection status on item tooltips
-- @author Abracadaniel22

local addonName, addon = ...
local TooltipsModule = {}
local API = addon.API

function GetItemInfoFromTooltip(tooltip)
    local name, link = tooltip:GetItem()
    if not link then
        return nil, nil, nil, nil
    end
    
    local itemId = tonumber(link:match("item:(%d+)"))
    if not itemId then
        return nil, nil, nil, nil
    end
    
    local _, _, _, _, _, itemClass, itemSubClass, _, itemInventoryType = GetItemInfo(itemId)
    return itemId, itemClass, itemSubClass, itemInventoryType
end

function UpdateTooltip(tooltip)
    local itemId, itemClass, itemSubClass, itemInventoryType = GetItemInfoFromTooltip(tooltip)
    if not itemId then
        return
    end
    if not API.CanBeTransmogrified(itemClass, itemSubClass, itemInventoryType) then
        return
    end
    API.QueryAppearanceCollection(itemId)
    local status = API.IsAppearanceCollected(itemId)
    if status ~= nil then
        local text = status and API.ColourText("Collected") or "Not Collected"
        tooltip:AddDoubleLine("Appearance", text)
    end
end

function HookTooltip(tooltip)
    if tooltip.TransmogCollectionHooked then
        return
    end
    tooltip.TransmogCollectionHooked = true
    local originalOnTooltipSetItem = tooltip:GetScript("OnTooltipSetItem")
    tooltip:SetScript("OnTooltipSetItem", function(self, ...)
        if originalOnTooltipSetItem then
            originalOnTooltipSetItem(self, ...)
        end
        UpdateTooltip(self)
    end)
end

function TooltipsModule.Initialize()
    HookTooltip(GameTooltip)
    HookTooltip(ItemRefTooltip)
    if ShoppingTooltip1 then HookTooltip(ShoppingTooltip1) end
    if ShoppingTooltip2 then HookTooltip(ShoppingTooltip2) end

    local frame = CreateFrame("Frame")
end

addon.TooltipsModule = TooltipsModule