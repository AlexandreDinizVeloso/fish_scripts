-- ============================================================
-- fish_hub: Server Main
-- Marketplace, Chat (global + DM), HEAT ranking,
-- Chip management, weekly cleanup, police trigger hook.
-- ============================================================

local DB = nil
local connectedClients = {}  -- { [identifier] = src }
local weeklyCleanupTimer = 7 * 24 * 60 * 60  -- 7 days in seconds

-- ============================================================
-- Startup
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DB = FishDB
    if not DB then
        print('[fish_hub] ERROR: FishDB not available. Is fish_normalizer running?')
        return
    end
    -- Clean expired listings on start
    DB.CleanExpiredListings()
    DB.CleanOldMessages()

    print('[fish_hub] Started.')

    -- Weekly cleanup timer
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(weeklyCleanupTimer * 1000)
            DB.CleanExpiredListings()
            DB.CleanOldMessages()
            print('[fish_hub] Weekly cleanup completed.')
        end
    end)
end)

-- ============================================================
-- Helpers
-- ============================================================

local function GetIdentifier(src)
    return GetPlayerIdentifier(src, 0) or ('player:' .. src)
end

local function GetPlayerName_Safe(src)
    return GetPlayerName(src) or 'Unknown'
end

-- Build private DM channel key (always sorted alphabetically for consistency)
local function DMChannel(identA, identB)
    local ids = {identA, identB}
    table.sort(ids)
    return 'dm:' .. ids[1] .. ':' .. ids[2]
end

-- ============================================================
-- Hub Open / Chip Management
-- ============================================================

RegisterNetEvent('fish_hub:open')
AddEventHandler('fish_hub:open', function()
    local src = source
    local identifier = GetIdentifier(src)

    -- Track client
    connectedClients[identifier] = src

    -- Get player's chips from QBX metadata
    local player = exports.qbx_core:GetPlayer(src)
    local chips = { v1 = false, v2 = false }
    if player then
        local meta = player.PlayerData.metadata or {}
        chips.v1 = meta.fish_chip_v1 or false
        chips.v2 = meta.fish_chip_v2 or false
    end

    -- Get player's vehicle HEAT if in vehicle
    local heatData = {}
    local ped = GetPlayerPed(src)
    if IsPedInAnyVehicle(ped, false) then
        local veh   = GetVehiclePedIsIn(ped, false)
        local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
        local heat  = exports['fish_tunes']:GetHeatLevel(plate)
        heatData[plate] = heat
    end

    TriggerClientEvent('fish_hub:opened', src, {
        chips    = chips,
        heatData = heatData,
        name     = GetPlayerName_Safe(src)
    })
end)

RegisterNetEvent('fish_hub:close')
AddEventHandler('fish_hub:close', function()
    local src = source
    local identifier = GetIdentifier(src)
    connectedClients[identifier] = nil
end)

-- ============================================================
-- Chip Installation (dev: free, no item check)
-- ============================================================

RegisterNetEvent('fish_hub:installChip')
AddEventHandler('fish_hub:installChip', function(chipType)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    -- Validate chip type
    if chipType ~= 'v1' and chipType ~= 'v2' then
        TriggerClientEvent('fish_hub:notify', src, {type='error', message='Invalid chip type.'})
        return
    end

    -- V2 requires V1
    if chipType == 'v2' then
        local meta = player.PlayerData.metadata or {}
        if not meta.fish_chip_v1 then
            TriggerClientEvent('fish_hub:notify', src, {type='error', message='You need a V1 chip installed first.'})
            return
        end
    end

    -- Set metadata
    local metaKey = 'fish_chip_' .. chipType
    player.Functions.SetMetaData(metaKey, true)

    TriggerClientEvent('fish_hub:chipInstalled', src, chipType)
    TriggerClientEvent('fish_hub:notify', src, {
        type    = 'success',
        message = ('Chip %s installed successfully!'):format(chipType:upper())
    })
end)

-- ============================================================
-- Marketplace
-- ============================================================

RegisterNetEvent('fish_hub:getListings')
AddEventHandler('fish_hub:getListings', function(isIllegal)
    local src = source

    -- V2 required for illegal listings
    if isIllegal then
        local player = exports.qbx_core:GetPlayer(src)
        local meta   = player and player.PlayerData.metadata or {}
        if not meta.fish_chip_v2 then
            TriggerClientEvent('fish_hub:notify', src, {type='error', message='V2 chip required for illegal marketplace.'})
            return
        end
    end

    local listings = DB.GetListings(isIllegal)
    TriggerClientEvent('fish_hub:receiveListings', src, listings, isIllegal)
end)

RegisterNetEvent('fish_hub:createListing')
AddEventHandler('fish_hub:createListing', function(data)
    local src        = source
    local identifier = GetIdentifier(src)
    local playerName = GetPlayerName_Safe(src)
    local player     = exports.qbx_core:GetPlayer(src)
    local meta       = player and player.PlayerData.metadata or {}

    -- Validate chip
    if data.is_illegal and not meta.fish_chip_v2 then
        TriggerClientEvent('fish_hub:notify', src, {type='error', message='V2 chip required to post illegal listings.'})
        return
    end
    if not data.is_illegal and not meta.fish_chip_v1 then
        TriggerClientEvent('fish_hub:notify', src, {type='error', message='V1 chip required to post listings.'})
        return
    end

    -- Sanitize
    data.seller_identifier = identifier
    data.seller_name       = playerName
    data.description       = (data.description or ''):sub(1, 300)

    local id = DB.CreateListing(data)

    -- Broadcast to all hub clients
    TriggerClientEvent('fish_hub:listingCreated', -1, {
        id         = id,
        seller_name = playerName,
        type       = data.type,
        category   = data.category,
        level      = data.level,
        price      = data.price,
        description = data.description,
        is_illegal = data.is_illegal,
    })

    TriggerClientEvent('fish_hub:notify', src, {type='success', message='Listing posted!'})
end)

RegisterNetEvent('fish_hub:deleteListing')
AddEventHandler('fish_hub:deleteListing', function(listingId)
    local src        = source
    local identifier = GetIdentifier(src)
    DB.DeleteListing(listingId, identifier)
    TriggerClientEvent('fish_hub:listingDeleted', -1, listingId)
    TriggerClientEvent('fish_hub:notify', src, {type='success', message='Listing removed.'})
end)

-- ============================================================
-- Chat
-- ============================================================

RegisterNetEvent('fish_hub:getMessages')
AddEventHandler('fish_hub:getMessages', function(channel)
    local src = source
    -- For DM channels, verify the player is one of the participants
    if channel:sub(1, 3) == 'dm:' then
        local identifier = GetIdentifier(src)
        if not channel:find(identifier, 1, true) then
            TriggerClientEvent('fish_hub:notify', src, {type='error', message='Access denied to this channel.'})
            return
        end
    end
    local messages = DB.GetMessages(channel, 80)
    TriggerClientEvent('fish_hub:receiveMessages', src, channel, messages)
end)

RegisterNetEvent('fish_hub:sendMessage')
AddEventHandler('fish_hub:sendMessage', function(channel, message)
    local src        = source
    local identifier = GetIdentifier(src)
    local playerName = GetPlayerName_Safe(src)
    local player     = exports.qbx_core:GetPlayer(src)
    local meta       = player and player.PlayerData.metadata or {}

    -- Channel permission check
    if channel == 'illegal' and not meta.fish_chip_v2 then
        TriggerClientEvent('fish_hub:notify', src, {type='error', message='V2 chip required for underground channel.'})
        return
    end
    if channel ~= 'illegal' and channel:sub(1, 3) ~= 'dm:' and not meta.fish_chip_v1 then
        TriggerClientEvent('fish_hub:notify', src, {type='error', message='V1 chip required for community chat.'})
        return
    end

    -- DM: verify participant
    if channel:sub(1, 3) == 'dm:' then
        if not channel:find(identifier, 1, true) then
            TriggerClientEvent('fish_hub:notify', src, {type='error', message='Cannot send to this DM.'})
            return
        end
    end

    -- Sanitize
    message = message:sub(1, 500)
    if #message == 0 then return end

    DB.SendMessage(channel, identifier, playerName, message)

    local msgData = {
        channel        = channel,
        sender_identifier = identifier,
        sender_name    = playerName,
        message        = message,
        sent_at        = os.date('%Y-%m-%d %H:%M:%S')
    }

    -- Broadcast to all hub clients (they filter by channel client-side)
    TriggerClientEvent('fish_hub:newMessage', -1, msgData)
end)

-- Start a private DM conversation
RegisterNetEvent('fish_hub:startDM')
AddEventHandler('fish_hub:startDM', function(targetIdentifier)
    local src        = source
    local identifier = GetIdentifier(src)
    local channel    = DMChannel(identifier, targetIdentifier)
    local messages   = DB.GetMessages(channel, 50)
    TriggerClientEvent('fish_hub:dmOpened', src, channel, messages, targetIdentifier)
end)

-- ============================================================
-- HEAT Ranking
-- ============================================================

RegisterNetEvent('fish_hub:getHeatRanking')
AddEventHandler('fish_hub:getHeatRanking', function()
    local src = source
    local ranking = exports['fish_tunes']:GetHeatLeaderboard()
    TriggerClientEvent('fish_hub:receiveHeatRanking', src, ranking)
end)

-- ============================================================
-- Player Data for Hub (own vehicles + HEAT)
-- ============================================================

RegisterNetEvent('fish_hub:getMyData')
AddEventHandler('fish_hub:getMyData', function()
    local src        = source
    local identifier = GetIdentifier(src)

    -- Get all player vehicles from normalizer
    local vehicles = DB.GetVehiclesByOwner(identifier)

    -- Enrich with HEAT data
    local vehicleList = {}
    for plate, data in pairs(vehicles) do
        local tuneData = DB.GetTunes(plate)
        table.insert(vehicleList, {
            plate    = plate,
            archetype = data.archetype,
            rank     = data.rank,
            score    = data.score,
            heat     = (tuneData and tuneData.heat) or 0
        })
    end

    TriggerClientEvent('fish_hub:receiveMyData', src, vehicleList)
end)

-- ============================================================
-- Server Exports for other resources
-- ============================================================

exports('GetHubListings', function(isIllegal)
    return DB.GetListings(isIllegal)
end)
