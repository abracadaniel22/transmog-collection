-- Handles bag icon overlays for ArkInventory addon
-- @author Abracadaniel22

local addonName, addon = ...
local API = addon.API

local ArkInventoryModule = {}
local overlayTextures = {}

function ArkInventoryModule.CreateOverlay(button)
    local id = button:GetName()
    if not overlayTextures[id] then
        local overlay = button:CreateTexture(nil, "OVERLAY")
        overlay:SetSize(16, 16)
        overlay:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
        overlayTextures[id] = overlay
    end
    return overlayTextures[id]
end

function ArkInventoryModule.UpdateItemIcon(button)
    local overlay = ArkInventoryModule.CreateOverlay(button)
    
    -- Get item info from ArkInventory's data structure
    local itemData = button.ARK_Data
    if not itemData then
        overlay:Hide()
        return
    end
    
    -- Get the item from ArkInventory's database
    local item = ArkInventory.Frame_Item_GetDB(button)
    if not item or not item.h then
        overlay:Hide()
        return
    end
    
    -- Extract item ID from hyperlink
    local itemId = ArkInventory.ObjectStringDecodeItem(item.h)
    if not itemId then
        overlay:Hide()
        return
    end
    
    local _, _, _, _, _, itemClass, itemSubClass, _, itemInventoryType = GetItemInfo(itemId)
    if not itemClass or not API.CanBeTransmogrified(itemClass, itemSubClass, itemInventoryType) then
        overlay:Hide()
        return
    end
    
    API.QueryAppearanceCollection(itemId)
    
    local status = API.IsAppearanceCollected(itemId)
    if status == true then
        overlay:SetTexture(API.ICON_TEXTURES.COLLECTED)
        overlay:Show()
    elseif status == false then
        overlay:SetTexture(API.ICON_TEXTURES.NOT_COLLECTED)
        overlay:Show()
    else
        overlay:Hide()
    end
end

function ArkInventoryModule.UpdateAllVisibleItems()
    for frameNum = 1, 10 do -- Reasonable limit for frame numbers
        local frameName = string.format("ARKINV_Frame%d", frameNum)
        local frame = _G[frameName]
        if frame and frame:IsVisible() then
            local loc_id = frame.ARK_Data and frame.ARK_Data.loc_id
            if loc_id then
                ArkInventoryModule.UpdateSingleFrameItems(frame, loc_id)
            end
        end
    end
end

function ArkInventoryModule.UpdateSingleFrameItems(frame, loc_id)
    for bagNum = 1, 12 do -- Reasonable limit for bags
        for slotNum = 1, 100 do -- Reasonable limit for slots per bag
            local itemFrameName = string.format("%sContainerBag%dItem%d", frame:GetName(), bagNum, slotNum)
            local button = _G[itemFrameName]
            if button and button:IsVisible() then
                ArkInventoryModule.UpdateItemIcon(button)
            end
        end
    end
end

function ArkInventoryModule.HideAllOverlays()
    for id, overlay in pairs(overlayTextures) do
        overlay:Hide()
    end
end

function ArkInventoryModule.HookArkInventoryItemUpdate()
    if ArkInventory and ArkInventory.Frame_Item_Update then
        local originalUpdate = ArkInventory.Frame_Item_Update
        ArkInventory.Frame_Item_Update = function(loc_id, bag_id, slot_id, ...)
            local result = originalUpdate(loc_id, bag_id, slot_id, ...)
            
            local frameThatWasUpdatedName = ArkInventory.ContainerItemNameGet(loc_id, bag_id, slot_id)
            if frameThatWasUpdatedName then
                local button = _G[frameThatWasUpdatedName]
                if button and button:IsVisible() then
                    ArkInventoryModule.UpdateItemIcon(button)
                end
            end
            
            return result
        end
    end
end

function ArkInventoryModule.HookAllArkInventoryFrames()
    for frameNum = 1, 10 do
        local frameName = string.format("ARKINV_Frame%d", frameNum)
        local frame = _G[frameName]
        if frame and not frame.TransmogCollectionHooked then
            frame.TransmogCollectionHooked = true
            
            local originalOnShow = frame:GetScript("OnShow")
            frame:SetScript("OnShow", function(self, ...)
                if originalOnShow then
                    originalOnShow(self, ...)
                end
                
                local updateFrame = CreateFrame("Frame")
                updateFrame:SetScript("OnUpdate", function(frame, elapsed)
                    frame.elapsed = (frame.elapsed or 0) + elapsed
                    if frame.elapsed >= 0.1 then
                        if self:IsVisible() then
                            local loc_id = self.ARK_Data and self.ARK_Data.loc_id
                            if loc_id then
                                ArkInventoryModule.UpdateSingleFrameItems(self, loc_id)
                            end
                        end
                        frame:SetScript("OnUpdate", nil)
                    end
                end)
            end)
        end
    end
end

function ArkInventoryModule.Initialize()
    if not TransmogCollectionDB.showBagIcons or not IsAddOnLoaded("ArkInventory") then
        return
    end
    
    ArkInventoryModule.HookArkInventoryItemUpdate()
    ArkInventoryModule.HookAllArkInventoryFrames()
    
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(self, event, arg)
        if event == "PLAYER_LOGIN" then
            -- Wait for ArkInventory to fully load
            local loginFrame = CreateFrame("Frame")
            loginFrame:SetScript("OnUpdate", function(frame, elapsed)
                frame.elapsed = (frame.elapsed or 0) + elapsed
                if frame.elapsed >= 2 then
                    ArkInventoryModule.UpdateAllVisibleItems()
                    frame:SetScript("OnUpdate", nil)
                end
            end)
        elseif event == "BAG_UPDATE" then
            ArkInventoryModule.UpdateAllVisibleItems()
        elseif event == "UNIT_INVENTORY_CHANGED" then
            ArkInventoryModule.UpdateAllVisibleItems()
        end
    end)

    -- Cache updates callback
    local originalOnCacheUpdated = API.OnCacheUpdated
    API.OnCacheUpdated = function(itemId, status)
        if originalOnCacheUpdated then
            originalOnCacheUpdated(itemId, status)
        end
        ArkInventoryModule.UpdateAllVisibleItems()
    end

    -- /tc icons callback
    local originalOnIconsToggled = API.OnIconsToggled
    API.OnIconsToggled = function(enabled)
        if originalOnIconsToggled then
            originalOnIconsToggled(enabled)
        end
        if enabled then
            ArkInventoryModule.UpdateAllVisibleItems()
        else
            ArkInventoryModule.HideAllOverlays()
        end
    end
end

addon.ArkInventoryModule = ArkInventoryModule 