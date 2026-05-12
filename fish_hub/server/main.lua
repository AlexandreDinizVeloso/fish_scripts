-- ============================================================
-- FISH HUB - Server Main
-- ============================================================

-- DataStore is a global table, loaded before this script via server_scripts ordering in fxmanifest

local function GetSafePlayerName(src)
    return GetPlayerName(src) or 'Player_' .. src
end

local function DebugPrint(msg)
    print('[FISH HUB Server] ' .. tostring(msg))
end

-- ============================================================
-- Initialization
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DataStore.LoadAll()
    DebugPrint('Resource started, data loaded.')

    -- Periodic cleanup of expired listings
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(300000) -- every 5 minutes
            DataStore.CleanExpiredListings()
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DataStore.SaveAll()
    DebugPrint('Resource stopping, data saved.')
end)

-- Player join / leave for HEAT tracking
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    DebugPrint('Player connecting: ' .. name .. ' (ID: ' .. src .. ')')
end)

-- ============================================================
-- Request Data (full sync to client)
-- ============================================================

RegisterNetEvent('fish_hub:requestData')
AddEventHandler('fish_hub:requestData', function()
    local src = source
    local chips = DataStore.GetPlayerChips(src)
    local listings = DataStore.GetListings()
    local messages = DataStore.GetMessages()
    local heat = DataStore.GetHeatData()
    local ranking = DataStore.GetHeatRanking()

    TriggerClientEvent('fish_hub:receiveData', src, {
        chips = chips,
        listings = listings,
        messages = messages,
        heat = heat,
        ranking = ranking
    })
end)

-- ============================================================
-- Chat System
-- ============================================================

RegisterNetEvent('fish_hub:sendMessage')
AddEventHandler('fish_hub:sendMessage', function(channel, message)
    local src = source

    if not message or message == '' or #message > 500 then
        TriggerClientEvent('fish_hub:notification', src, 'Invalid message.', 'error')
        return
    end

    -- Validate channel
    if not Config.ChatChannels[channel] then
        TriggerClientEvent('fish_hub:notification', src, 'Invalid channel.', 'error')
        return
    end

    -- Check V2 requirement for underground
    if Config.ChatChannels[channel].requiresV2 then
        local chips = DataStore.GetPlayerChips(src)
        local hasV2 = false
        for _, chip in ipairs(chips) do
            if chip.type == 'v2' then hasV2 = true end
        end
        if not hasV2 then
            TriggerClientEvent('fish_hub:notification', src, 'V2 chip required for this channel.', 'error')
            return
        end
    end

    local playerName = GetSafePlayerName(src)
    local msg = DataStore.AddMessage(src, playerName, channel, message)

    -- Broadcast to all players
    TriggerClientEvent('fish_hub:newMessage', -1, msg)
end)

-- ============================================================
-- Marketplace
-- ============================================================

RegisterNetEvent('fish_hub:createListing')
AddEventHandler('fish_hub:createListing', function(data)
    local src = source

    if not data or not data.name or not data.price then
        TriggerClientEvent('fish_hub:notification', src, 'Missing listing data.', 'error')
        return
    end

    -- Check access for illegal listings
    if data.listingType == 'illegal' then
        local chips = DataStore.GetPlayerChips(src)
        local hasV2 = false
        for _, chip in ipairs(chips) do
            if chip.type == 'v2' then hasV2 = true end
        end
        if not hasV2 then
            TriggerClientEvent('fish_hub:notification', src, 'V2 chip required for illegal listings.', 'error')
            return
        end
    end

    data.sellerName = GetSafePlayerName(src)
    local success, result = DataStore.CreateListing(src, data)

    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Listing created: ' .. data.name, 'success')
        -- Broadcast updated listings
        local listings = DataStore.GetListings()
        TriggerClientEvent('fish_hub:listingUpdate', -1, listings)
    else
        TriggerClientEvent('fish_hub:notification', src, 'Failed: ' .. tostring(result), 'error')
    end
end)

RegisterNetEvent('fish_hub:acceptListing')
AddEventHandler('fish_hub:acceptListing', function(listingId)
    local src = source

    local success, listing = DataStore.AcceptListing(src, listingId)

    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Purchase accepted: ' .. listing.name, 'success')
        -- Notify seller
        if listing.sellerId then
            TriggerClientEvent('fish_hub:notification', listing.sellerId, 'Your listing "' .. listing.name .. '" was purchased!', 'success')
        end
        -- Broadcast updated listings
        local listings = DataStore.GetListings()
        TriggerClientEvent('fish_hub:listingUpdate', -1, listings)
    else
        TriggerClientEvent('fish_hub:notification', src, 'Failed: ' .. tostring(listing), 'error')
    end
end)

RegisterNetEvent('fish_hub:searchListings')
AddEventHandler('fish_hub:searchListings', function(query, filter)
    local src = source
    local listings = DataStore.GetListings()
    local results = {}

    for _, listing in ipairs(listings) do
        if listing.status == 'active' then
            local matchesQuery = query == '' or listing.name:lower():find(query) or (listing.description or ''):lower():find(query)
            local matchesFilter = filter == 'all' or listing.type == filter

            if matchesQuery and matchesFilter then
                table.insert(results, listing)
            end
        end
    end

    TriggerClientEvent('fish_hub:listingUpdate', src, results)
end)

RegisterNetEvent('fish_hub:reportListing')
AddEventHandler('fish_hub:reportListing', function(listingId)
    local src = source
    DebugPrint('Player ' .. src .. ' reported listing: ' .. listingId)
    TriggerClientEvent('fish_hub:notification', src, 'Listing reported. Thank you.', 'info')
end)

-- ============================================================
-- Services
-- ============================================================

RegisterNetEvent('fish_hub:requestPart')
AddEventHandler('fish_hub:requestPart', function(serviceType, details)
    local src = source

    if not serviceType or not details then
        TriggerClientEvent('fish_hub:notification', src, 'Missing service data.', 'error')
        return
    end

    -- Validate service type
    if not Config.ServiceTypes[serviceType] then
        TriggerClientEvent('fish_hub:notification', src, 'Invalid service type.', 'error')
        return
    end

    -- Check V2 requirement
    if Config.ServiceTypes[serviceType].requiresV2 then
        local chips = DataStore.GetPlayerChips(src)
        local hasV2 = false
        for _, chip in ipairs(chips) do
            if chip.type == 'v2' then hasV2 = true end
        end
        if not hasV2 then
            TriggerClientEvent('fish_hub:notification', src, 'V2 chip required for this service.', 'error')
            return
        end
    end

    local playerName = GetSafePlayerName(src)
    DebugPrint('Service request from ' .. playerName .. ': ' .. serviceType)

    -- Create a service listing
    local success, result = DataStore.CreateListing(src, {
        name = Config.ServiceTypes[serviceType].label .. ' Request',
        description = 'Service request: ' .. details,
        price = 0,
        listingType = 'service',
        category = serviceType,
        sellerName = playerName
    })

    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Service request submitted.', 'success')
    else
        TriggerClientEvent('fish_hub:notification', src, 'Failed to submit request.', 'error')
    end
end)

RegisterNetEvent('fish_hub:toggleService')
AddEventHandler('fish_hub:toggleService', function(serviceId)
    local src = source
    -- Toggle service availability (for service providers)
    TriggerClientEvent('fish_hub:notification', src, 'Service toggled: ' .. serviceId, 'info')
end)

-- ============================================================
-- Chip System
-- ============================================================

RegisterNetEvent('fish_hub:installChip')
AddEventHandler('fish_hub:installChip', function(chipType)
    local src = source

    if not Config.ChipTypes[chipType] then
        TriggerClientEvent('fish_hub:notification', src, 'Invalid chip type.', 'error')
        return
    end

    local success, msg = DataStore.InstallChip(src, chipType)

    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Chip installed: ' .. Config.ChipTypes[chipType].label, 'success')
        local chips = DataStore.GetPlayerChips(src)
        TriggerClientEvent('fish_hub:chipsUpdated', src, chips)
    else
        TriggerClientEvent('fish_hub:notification', src, 'Failed: ' .. msg, 'error')
    end
end)

RegisterNetEvent('fish_hub:removeChip')
AddEventHandler('fish_hub:removeChip', function(chipType)
    local src = source

    local success, msg = DataStore.RemoveChip(src, chipType)

    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Chip removed.', 'success')
        local chips = DataStore.GetPlayerChips(src)
        TriggerClientEvent('fish_hub:chipsUpdated', src, chips)
    else
        TriggerClientEvent('fish_hub:notification', src, 'Failed: ' .. msg, 'error')
    end
end)

-- ============================================================
-- HEAT System
-- ============================================================

RegisterNetEvent('fish_hub:updateHeat')
AddEventHandler('fish_hub:updateHeat', function(vehicleData)
    local src = source
    if not vehicleData then return end

    vehicleData.playerName = GetSafePlayerName(src)
    DataStore.UpdateHeat(src, vehicleData)

    -- Broadcast heat update
    local heat = DataStore.GetHeatData()
    local ranking = DataStore.GetHeatRanking()
    TriggerClientEvent('fish_hub:heatUpdate', -1, {
        heat = heat,
        ranking = ranking
    })
end)

RegisterNetEvent('fish_hub:requestHeatRanking')
AddEventHandler('fish_hub:requestHeatRanking', function()
    local src = source
    local ranking = DataStore.GetHeatRanking()
    TriggerClientEvent('fish_hub:heatUpdate', src, {
        ranking = ranking
    })
end)

-- ============================================================
-- DM System
-- ============================================================

RegisterNetEvent('fish_hub:dmPlayer')
AddEventHandler('fish_hub:dmPlayer', function(targetId, message)
    local src = source

    if not targetId or not message or message == '' then
        TriggerClientEvent('fish_hub:notification', src, 'Invalid DM data.', 'error')
        return
    end

    local playerName = GetSafePlayerName(src)
    local msg = DataStore.AddMessage(src, playerName, 'dm_' .. src .. '_' .. targetId, message)

    -- Send to both sender and target
    TriggerClientEvent('fish_hub:newMessage', src, msg)
    TriggerClientEvent('fish_hub:newMessage', targetId, msg)
end)

-- ============================================================
-- Admin / Cleanup
-- ============================================================

RegisterCommand('fishhub_clean', function(source, args)
    if source ~= 0 then return end -- Console only
    DataStore.CleanExpiredListings()
    print('[FISH HUB] Cleaned expired listings.')
end, true)

RegisterCommand('fishhub_save', function(source, args)
    if source ~= 0 then return end
    DataStore.SaveAll()
    print('[FISH HUB] All data saved.')
end, true)
