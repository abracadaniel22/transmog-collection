-- Handles displaying transmog status icons over items on bag and bank
-- @author Abracadaniel22

-- Implementation note: the game has 12 fixed bag slots (ContainerFrame1..ContainerFrame12)
-- and they will hold bags interchangeably depending on the order that the player opened/closed bags.
-- So we can't assume bag zero will always be on ContainerFrame1.
-- Furthermore, there are no ContainerFrameN... either, it's ContainerFrameNItemM for the individual items,
-- no container holding items.
-- So that's why we have to listen to when the frames open/close and only then try to figure out which
-- bag is being assigned to which container.
-- Luckly the bank frame buttons are fixed slots and frames.

local addonName, addon = ...
local API = addon.API
-- default item slots in the main bank tab. different from bags
local NUM_BANK_ITEM_SLOTS = 28
-- 5 bags plus 7 that can be purchased and added to the bank
local NUM_BAG_SLOTS = 12

local ItemOverlayModule = {}
local overlayTextures = {}
local containerToBagMap = {}

function CreateBagIconOverlay(button, container, slot)
    local id = button:GetName()
    if not overlayTextures[id] then
        local overlay = button:CreateTexture(nil, "OVERLAY")
        overlay:SetSize(16, 16)
        overlay:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
        overlayTextures[id] = overlay
    end
    return overlayTextures[id]
end

function GetItemInfoFromContainer(container, slot)
    local itemId = GetContainerItemID(container, slot)
    if not itemId then
        return nil, nil, nil, nil
    end
    local _, _, _, _, _, itemClass, itemSubClass, _, itemInventoryType = GetItemInfo(itemId)
    return itemId, itemClass, itemSubClass, itemInventoryType
end

function UpdateSlotIcon(button, bag, slot, forceServerCheck)
    local overlay = CreateBagIconOverlay(button, bag, slot)
    local itemId, itemClass, itemSubClass, itemInventoryType = GetItemInfoFromContainer(bag, slot)
    if not itemId or not API.CanBeTransmogrified(itemClass, itemSubClass, itemInventoryType) then
        overlay:Hide()
    else
        API.QueryAppearanceCollection(itemId, forceServerCheck)
        local appearanceCollected = API.IsAppearanceCollected(itemId)
        if appearanceCollected == true then
            overlay:SetTexture(API.ICON_TEXTURES.COLLECTED)
        elseif appearanceCollected == false then
            overlay:SetTexture(API.ICON_TEXTURES.NOT_COLLECTED)
        end
        overlay:Show()
    end
end

local function UpdateBankItemSlots()
    for slot = 1, NUM_BANK_ITEM_SLOTS do
        local frame = _G["BankFrameItem"..slot]
        if frame then
            UpdateSlotIcon(frame, -1, slot)
        end
    end
end

local function UpdateSingleBagContainer(bag, containerName, forceServerCheck)
    local numSlots = GetContainerNumSlots(bag)
    for slot = 1, numSlots do
        local button = _G[containerName.."Item"..(GetContainerNumSlots(bag) - slot + 1)]
        UpdateSlotIcon(button, bag, slot, forceServerCheck)
    end
end

local function UpdateCharacterAndBankBags()
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local button = _G["ContainerFrame"..(bag + 1).."Item"..(GetContainerNumSlots(bag) - slot + 1)]
            UpdateSlotIcon(button, bag, slot)
        end
    end
end

function HideAllOverlays()
    for id, overlay in pairs(overlayTextures) do
        overlay:Hide()
    end
end

local function UpdateBags()
    UpdateCharacterAndBankBags()
    UpdateBankItemSlots()
end

function HookContainerFrame(container)
    -- Hook the OnShow function to update icons when container opens
    local originalOnShow = container:GetScript("OnShow")
    container:SetScript("OnShow", function(self, ...)
        if originalOnShow then
            originalOnShow(self, ...)
        end
        local bag = self:GetID()
        containerToBagMap[self:GetName()] = bag
        local updateFrame = CreateFrame("Frame")
        updateFrame:SetScript("OnUpdate", function(frame, elapsed)
            if self:IsVisible() then
                local bag = self:GetID()
                UpdateSingleBagContainer(bag, self:GetName())
            end
            frame:SetScript("OnUpdate", nil)
        end)
    end)
    
    -- Hook the OnHide function to clean up overlays
    local originalOnHide = container:GetScript("OnHide")
    container:SetScript("OnHide", function(self, ...)
        if originalOnHide then
            originalOnHide(self, ...)
        end
        containerToBagMap[self:GetName()] = nil
        -- Hide all overlays for this container
        for slot = 1, GetContainerNumSlots(self:GetID() - 1) do
            local button = _G[self:GetName() .. "Item" .. slot]
            if button and button.TransmogCollectionOverlay then
                button.TransmogCollectionOverlay:Hide()
            end
        end
    end)
end

function UpdateAllVisibleContainers()
    for containerName, bagId in pairs(containerToBagMap) do
        UpdateSingleBagContainer(bagId, containerName)
    end
end

function ItemOverlayModule.Initialize()
    if not TransmogCollectionDB.showBagIcons or IsAddOnLoaded("ArkInventory") then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")                 -- once and before player_entering_world
    frame:RegisterEvent("BAG_UPDATE")                   -- moving between bag slots, equiping, unequiping, bank deposit/withdrawal
    frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")      -- change in main bank inventory. Will fire multiple per changed slot (e.g.: moved item from slot 1 to 2)
    frame:RegisterEvent("BANKFRAME_OPENED")             -- when opening bank
    frame:RegisterEvent("UNIT_INVENTORY_CHANGED")       -- when equip/unequip. May fire when BAG_UPDATE doesn't, for example, switching from the same slot.
    
    local function HookContainerWhenCreated(containerName)
        local container = _G[containerName]
        if container and not container.TransmogCollectionHooked then
            HookContainerFrame(container)
        end
    end

    frame:SetScript("OnEvent", function(self, event, arg)
        if event == "PLAYER_LOGIN" then
            local loginFrame = CreateFrame("Frame")
            loginFrame:SetScript("OnUpdate", function(frame, elapsed)
                frame.elapsed = (frame.elapsed or 0) + elapsed
                if frame.elapsed >= 1 then
                    for i = 1, NUM_BAG_SLOTS do
                        HookContainerWhenCreated("ContainerFrame" .. i)
                    end
                    frame:SetScript("OnUpdate", nil)
                end
            end)
        elseif event =="BAG_UPDATE" then
            for containerName, bagId in pairs(containerToBagMap) do
                if bagId == arg then
                    UpdateSingleBagContainer(arg, containerName)
                    break
                end
            end
        elseif event =="UNIT_INVENTORY_CHANGED" then
            for containerName, bagId in pairs(containerToBagMap) do
                -- In this event, cache is ignored for it may fire when item is equipped
                UpdateSingleBagContainer(bagId, containerName, true)
            end
        elseif event =="BANKFRAME_OPENED" or event=="PLAYERBANKSLOTS_CHANGED" then
            UpdateBankItemSlots()
        end
    end)

    -- Cache updates callback
    local originalOnCacheUpdated = API.OnCacheUpdated
    API.OnCacheUpdated = function(itemId, status)
        if originalOnCacheUpdated then
            originalOnCacheUpdated(itemId, status)
        end
        UpdateAllVisibleContainers()
    end

    -- /tc icons callback
    local originalOnIconsToggled = API.OnIconsToggled
    API.OnIconsToggled = function(enabled)
        if originalOnIconsToggled then
            originalOnIconsToggled(enabled)
        end
        if enabled then
            UpdateAllVisibleContainers()
            UpdateBankItemSlots()
        else
            HideAllOverlays()
        end
    end
end

addon.ItemOverlayModule = ItemOverlayModule