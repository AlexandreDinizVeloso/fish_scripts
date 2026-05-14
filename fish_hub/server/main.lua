-- ============================================================
-- FISH HUB - Server Main
-- ============================================================

local function GetSafePlayerName(src)
    return GetPlayerName(src) or 'Player_' .. src
end

local function DebugPrint(msg)
    print('[FISH HUB Server] ' .. tostring(msg))
end

local function PlayerHasChipType(src, chipType)
    local chips = DataStore.GetPlayerChips(src)
    for _, chip in ipairs(chips) do
        if chip.type == chipType then return true end
    end
    return false
end

local function PlayerHasV1(src)
    return PlayerHasChipType(src, 'v1') or PlayerHasChipType(src, 'v2')
end

local function PlayerHasV2(src)
    return PlayerHasChipType(src, 'v2')
end

-- ============================================================
-- Initialization
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DataStore.LoadAll()
    DebugPrint('Resource started, data loaded.')

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(300000)
            DataStore.CleanExpiredListings()
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DataStore.SaveAll()
    DebugPrint('Resource stopping, data saved.')
end)

-- ============================================================
-- Request Data (full sync to client)
-- ============================================================

RegisterNetEvent('fish_hub:requestData')
AddEventHandler('fish_hub:requestData', function()
    local src = source
    TriggerClientEvent('fish_hub:receiveData', src, {
        chips     = DataStore.GetPlayerChips(src),
        listings  = DataStore.GetListings(),
        messages  = DataStore.GetMessages(),
        heat      = DataStore.GetHeatData(),
        ranking   = DataStore.GetHeatRanking(),
        profile   = DataStore.GetProfile(src),
        channels  = DataStore.GetPlayerChannels(src)
    })
end)

-- ============================================================
-- Profile System
-- ============================================================

RegisterNetEvent('fish_hub:updateProfile')
AddEventHandler('fish_hub:updateProfile', function(data)
    local src = source
    if not data then
        TriggerClientEvent('fish_hub:notification', src, 'Missing profile data.', 'error')
        return
    end

    if data.username and #data.username > 32 then
        TriggerClientEvent('fish_hub:notification', src, 'Username too long (max 32).', 'error')
        return
    end

    if data.profilePic and #data.profilePic > 512 then
        TriggerClientEvent('fish_hub:notification', src, 'URL too long (max 512).', 'error')
        return
    end

    DataStore.UpdateProfile(src, data)
    TriggerClientEvent('fish_hub:notification', src, 'Profile updated.', 'success')
    TriggerClientEvent('fish_hub:profileUpdated', src, DataStore.GetProfile(src))
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

    -- Validate channel exists and player has access
    local playerChannels = DataStore.GetPlayerChannels(src)
    if not playerChannels[channel] then
        TriggerClientEvent('fish_hub:notification', src, 'No access to this channel.', 'error')
        return
    end

    local playerName = GetSafePlayerName(src)
    local profile = DataStore.GetProfile(src)
    if profile.username and profile.username ~= '' then
        playerName = profile.username
    end

    local msg = DataStore.AddMessage(src, playerName, channel, message)

    -- Broadcast to all players who have access to this channel
    local players = GetPlayers()
    for _, pid in ipairs(players) do
        local pidNum = tonumber(pid)
        local pChannels = DataStore.GetPlayerChannels(pidNum)
        if pChannels[channel] then
            TriggerClientEvent('fish_hub:newMessage', pidNum, msg)
        end
    end
end)

RegisterNetEvent('fish_hub:createChannel')
AddEventHandler('fish_hub:createChannel', function(name)
    local src = source
    if not name or name == '' or #name > 32 then
        TriggerClientEvent('fish_hub:notification', src, 'Invalid channel name (max 32).', 'error')
        return
    end

    local channelId = DataStore.CreateChannel(src, name)
    TriggerClientEvent('fish_hub:notification', src, 'Channel created: ' .. name, 'success')
    TriggerClientEvent('fish_hub:channelsUpdated', src, DataStore.GetPlayerChannels(src))
end)

RegisterNetEvent('fish_hub:inviteToChannel')
AddEventHandler('fish_hub:inviteToChannel', function(channelId, targetId)
    local src = source

    if not channelId or not targetId then
        TriggerClientEvent('fish_hub:notification', src, 'Missing channel or target.', 'error')
        return
    end

    -- Verify the inviter is a member of the channel
    local playerChannels = DataStore.GetPlayerChannels(src)
    if not playerChannels[channelId] then
        TriggerClientEvent('fish_hub:notification', src, 'You are not in this channel.', 'error')
        return
    end

    local success, msg = DataStore.InviteToChannel(channelId, targetId)
    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Player invited.', 'success')
        TriggerClientEvent('fish_hub:notification', targetId, 'You were invited to a channel!', 'info')
        -- Refresh channels for the invited player
        TriggerClientEvent('fish_hub:channelsUpdated', targetId, DataStore.GetPlayerChannels(targetId))
    else
        TriggerClientEvent('fish_hub:notification', src, msg, 'error')
    end
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

    -- Check V2 for illegal listings
    if data.listingType == 'illegal' and not PlayerHasV2(src) then
        TriggerClientEvent('fish_hub:notification', src, 'V2 chip required for illegal listings.', 'error')
        return
    end

    local profile = DataStore.GetProfile(src)
    data.sellerName = (profile.username and profile.username ~= '') and profile.username or GetSafePlayerName(src)

    local success, result = DataStore.CreateListing(src, data)
    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Listing created: ' .. data.name, 'success')
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
        if listing.sellerId then
            TriggerClientEvent('fish_hub:notification', listing.sellerId, 'Your listing "' .. listing.name .. '" was purchased!', 'success')
        end
        TriggerClientEvent('fish_hub:listingUpdate', -1, DataStore.GetListings())
    else
        TriggerClientEvent('fish_hub:notification', src, 'Failed: ' .. tostring(listing), 'error')
    end
end)

RegisterNetEvent('fish_hub:contactSeller')
AddEventHandler('fish_hub:contactSeller', function(listingId, sellerId)
    local src = source

    if not PlayerHasV1(src) then
        TriggerClientEvent('fish_hub:notification', src, 'V1 chip required to contact sellers.', 'error')
        return
    end

    if not listingId or not sellerId then
        TriggerClientEvent('fish_hub:notification', src, 'Missing data.', 'error')
        return
    end

    local channelId = DataStore.GetOrCreateDMChannel(src, sellerId)

    -- Find listing name for context message
    local listingName = 'a listing'
    for _, l in ipairs(DataStore.listings) do
        if l.id == listingId then
            listingName = l.name
            break
        end
    end

    local playerName = GetSafePlayerName(src)
    local profile = DataStore.GetProfile(src)
    if profile.username and profile.username ~= '' then
        playerName = profile.username
    end

    DataStore.AddMessage(src, playerName, channelId, 'Interested in: ' .. listingName)

    -- Notify buyer to open DM channel
    TriggerClientEvent('fish_hub:dmChannelCreated', src, channelId)

    -- Notify seller
    TriggerClientEvent('fish_hub:notification', sellerId, 'Someone is interested in your listing!', 'info')
    TriggerClientEvent('fish_hub:channelsUpdated', sellerId, DataStore.GetPlayerChannels(sellerId))
end)

RegisterNetEvent('fish_hub:searchListings')
AddEventHandler('fish_hub:searchListings', function(query, filter)
    local src = source
    local listings = DataStore.GetListings()
    local results = {}

    for _, listing in ipairs(listings) do
        if listing.status == 'active' then
            local matchesQuery = query == '' or
                listing.name:lower():find(query) or
                (listing.description or ''):lower():find(query)
            local matchesFilter = filter == 'all' or listing.tag == filter

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

    if not Config.ServiceTypes[serviceType] then
        TriggerClientEvent('fish_hub:notification', src, 'Invalid service type.', 'error')
        return
    end

    local svc = Config.ServiceTypes[serviceType]
    if svc.requiresV1 and not PlayerHasV1(src) then
        TriggerClientEvent('fish_hub:notification', src, 'V1 chip required for this service.', 'error')
        return
    end

    local playerName = GetSafePlayerName(src)
    local profile = DataStore.GetProfile(src)
    if profile.username and profile.username ~= '' then
        playerName = profile.username
    end

    DebugPrint('Service request from ' .. playerName .. ': ' .. serviceType)

    local success, result = DataStore.CreateListing(src, {
        name        = svc.label .. ' Request',
        description = 'Service request: ' .. details,
        price       = 0,
        tag         = 'buying',
        listingType = 'service',
        sellerName  = playerName
    })

    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Service request submitted.', 'success')
    else
        TriggerClientEvent('fish_hub:notification', src, 'Failed to submit request.', 'error')
    end
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
        TriggerClientEvent('fish_hub:chipsUpdated', src, DataStore.GetPlayerChips(src))
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
        TriggerClientEvent('fish_hub:chipsUpdated', src, DataStore.GetPlayerChips(src))
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
    local profile = DataStore.GetProfile(src)
    if profile.username and profile.username ~= '' then
        vehicleData.playerName = profile.username
    end

    DataStore.UpdateHeat(src, vehicleData)

    TriggerClientEvent('fish_hub:heatUpdate', -1, {
        heat    = DataStore.GetHeatData(),
        ranking = DataStore.GetHeatRanking()
    })
end)

RegisterNetEvent('fish_hub:uploadCarPhoto')
AddEventHandler('fish_hub:uploadCarPhoto', function(vehicleModel, photoUrl)
    local src = source
    if not vehicleModel then
        TriggerClientEvent('fish_hub:notification', src, 'Missing vehicle model.', 'error')
        return
    end

    if photoUrl and #photoUrl > 512 then
        TriggerClientEvent('fish_hub:notification', src, 'URL too long.', 'error')
        return
    end

    local success, err = DataStore.SetVehiclePhoto(src, vehicleModel, photoUrl or '')
    if success then
        TriggerClientEvent('fish_hub:notification', src, 'Photo updated.', 'success')
        TriggerClientEvent('fish_hub:heatUpdate', -1, {
            heat    = DataStore.GetHeatData(),
            ranking = DataStore.GetHeatRanking()
        })
    else
        TriggerClientEvent('fish_hub:notification', src, 'Vehicle not found.', 'error')
    end
end)

RegisterNetEvent('fish_hub:requestHeatRanking')
AddEventHandler('fish_hub:requestHeatRanking', function()
    local src = source
    TriggerClientEvent('fish_hub:heatUpdate', src, {
        ranking = DataStore.GetHeatRanking()
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

    local channelId = DataStore.GetOrCreateDMChannel(src, targetId)
    local playerName = GetSafePlayerName(src)
    local profile = DataStore.GetProfile(src)
    if profile.username and profile.username ~= '' then
        playerName = profile.username
    end

    local msg = DataStore.AddMessage(src, playerName, channelId, message)

    -- Send to both players
    TriggerClientEvent('fish_hub:newMessage', src, msg)
    TriggerClientEvent('fish_hub:newMessage', targetId, msg)
end)

-- ============================================================
-- Admin / Cleanup
-- ============================================================

RegisterCommand('fishhub_clean', function(source, args)
    if source ~= 0 then return end
    DataStore.CleanExpiredListings()
    print('[FISH HUB] Cleaned expired listings.')
end, true)

RegisterCommand('fishhub_save', function(source, args)
    if source ~= 0 then return end
    DataStore.SaveAll()
    print('[FISH HUB] All data saved.')
end, true)
