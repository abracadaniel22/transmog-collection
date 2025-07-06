-- This file contains shared functionality used by other modules
-- @author Abracadaniel22

local addonName, addon = ...
local API = {}
local pendingQueries = {}

TransmogCollectionDB = TransmogCollectionDB or {
    showBagIcons = true,
    cache = {},
    debug = false
}

TRANSMOG_QUERY_PREFIX = "TRANSMOG_QUERY_RESULT:"
EQUIPPABLE_ITEM_CLASSES = {
    ["Weapon"] = true,
    ["Armor"] = true
}
EQUIPPABLE_INVTYPE = {
    ["INVTYPE_NON_EQUIP"] = false,
    ["INVTYPE_HEAD"] = true,
    ["INVTYPE_NECK"] = false,
    ["INVTYPE_SHOULDER"] = true,
    ["INVTYPE_BODY"] = true,
    ["INVTYPE_CHEST"] = true,
    ["INVTYPE_WAIST"] = true,
    ["INVTYPE_LEGS"] = true,
    ["INVTYPE_FEET"] = true,
    ["INVTYPE_WRIST"] = true,
    ["INVTYPE_HAND"] = true,
    ["INVTYPE_FINGER"] = false,
    ["INVTYPE_TRINKET"] = false,
    ["INVTYPE_WEAPON"] = true,
    ["INVTYPE_SHIELD"] = true,
    ["INVTYPE_RANGED"] = true,
    ["INVTYPE_CLOAK"] = true,
    ["INVTYPE_2HWEAPON"] = true,
    ["INVTYPE_BAG"] = false,
    ["INVTYPE_TABARD"] = true,
    ["INVTYPE_ROBE"] = true,
    ["INVTYPE_WEAPONMAINHAND"] = true,
    ["INVTYPE_WEAPONOFFHAND"] = true,
    ["INVTYPE_HOLDABLE"] = true,
    ["INVTYPE_AMMO"] = false,
    ["INVTYPE_THROWN"] = false,
    ["INVTYPE_RANGEDRIGHT"] = false,
    ["INVTYPE_QUIVER"] = false,
    ["INVTYPE_RELIC"] = false,
    ["INVTYPE_PROFESSION_TOOL"] = false,
    ["INVTYPE_PROFESSION_GEAR"] = true,
    ["INVTYPE_EQUIPABLESPELL_OFFENSIVE"] = false,
    ["INVTYPE_EQUIPABLESPELL_UTILITY"] = false,
    ["INVTYPE_EQUIPABLESPELL_DEFENSIVE"] = false,
    ["INVTYPE_EQUIPABLESPELL_WEAPON"] = false,
}

TRANSMOG_COLOUR="FE80FE"
COLOUR_TEXT="|cFF" .. TRANSMOG_COLOUR .. "%s|r"

API.ICON_TEXTURES = {
    COLLECTED = "Interface\\RaidFrame\\ReadyCheck-Ready",
    NOT_COLLECTED = "Interface\\RaidFrame\\ReadyCheck-NotReady"
}

function API.ColourText(text)
    return string.format(COLOUR_TEXT, text)
end

function API.PrintAddonMessage(text)
    print(string.format(COLOUR_TEXT, "[TransmogCollection]") .. " " .. text)
end

-- TODO add support for querying multiple items at once and make addon batch queries if they happen less than .2s apart
function API.QueryAppearanceCollection(itemId, forceServerCheck)
    if not forceServerCheck and TransmogCollectionDB.cache[itemId] ~= nil then
        return TransmogCollectionDB.cache[itemId]
    end
    if pendingQueries[itemId] then
        return
    end
    
    pendingQueries[itemId] = true
    SendChatMessage(".transmog has " .. itemId, "GUILD")
end

function API.HandleChatMessage(message)
    if message:find("^" .. TRANSMOG_QUERY_PREFIX) then
        local hideServerMessage = not TransmogCollectionDB.debug
        local itemId, status, itemName = message:match("TRANSMOG_QUERY_RESULT:(%d+):(%d+):(.+)")
        if itemId and status then
            itemId = tonumber(itemId)
            status = tonumber(status) == 1
            
            TransmogCollectionDB.cache[itemId] = status
            pendingQueries[itemId] = nil

            if API.OnCacheUpdated then
                API.OnCacheUpdated(itemId, status)
            end
        end
        return hideServerMessage
    end
    
    return false -- Message not handled by us. Don't hide it.
end

function API.IsAppearanceCollected(itemId)
    return TransmogCollectionDB.cache[itemId]
end

function API.CanBeTransmogrified(itemClass, itemSubClass, itemInventoryType)
    if not EQUIPPABLE_ITEM_CLASSES[itemClass] then
        return false
    end
    if not EQUIPPABLE_INVTYPE[itemInventoryType] then
        return false
    end
    return true
end

function API.HandleSlashCommand(msg)
    msg = msg:lower()
    
    if msg == "icons" then
        TransmogCollectionDB.showBagIcons = not TransmogCollectionDB.showBagIcons
        API.PrintAddonMessage("Bag icons: " .. (TransmogCollectionDB.showBagIcons and "Enabled" or "Disabled"))
        if API.OnIconsToggled then
            API.OnIconsToggled(TransmogCollectionDB.showBagIcons)
        end
    elseif msg == "debug" then
        TransmogCollectionDB.debug = not TransmogCollectionDB.debug
        API.PrintAddonMessage("Server messages will" .. (TransmogCollectionDB.debug and " " or " not ") .. "be shown.")
    elseif msg == "clear" then
        TransmogCollectionDB.cache = {}
        pendingQueries = {}
        API.PrintAddonMessage("Cache cleared.")
    elseif msg == "status" then
        local cacheSize = 0
        for _ in pairs(TransmogCollectionDB.cache) do
            cacheSize = cacheSize + 1
        end
        API.PrintAddonMessage("Status:")
        print("  Bag icons: " .. (TransmogCollectionDB.showBagIcons and "Yes" or "No"))
        print("  Server messages: " .. (TransmogCollectionDB.debug and "Not hidden" or "Hidden"))
        print("  Cached items: " .. cacheSize)
    else
        API.PrintAddonMessage("Commands:")
        print("  /tc icons - Toggle bag icons")
        print("  /tc clear - Clear the cache")
        print("  /tc debug - Toggle hiding or showing server messages")
        print("  /tc status - Show addon status")
    end
end 

function API.Initialize()
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, message, ...)
        return API.HandleChatMessage(message)
    end)

    SLASH_TRANSMOGCOLLECTION1 = "/tc"
    SLASH_TRANSMOGCOLLECTION2 = "/transmogcollection"
    SlashCmdList["TRANSMOGCOLLECTION"] = addon.API.HandleSlashCommand
end

addon.API = API