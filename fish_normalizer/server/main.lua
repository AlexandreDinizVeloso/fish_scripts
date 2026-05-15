-- ============================================================
-- fish_normalizer: Server Main (oxmysql + Entity State Bags)
-- Vehicle normalization open to all players. Provides exports for all modules.
-- ============================================================

local vehicleDataCache = {}  -- in-memory cache keyed by plate

-- DB is set as global FishDB by shared/database.lua (loaded before this file)
-- We alias it here for readability.

-- ============================================================
-- Startup
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- FishDB is the global set by shared/database.lua
    local DB = FishDB

    -- Create tables
    FishDB.CreateTables()

    -- Warm cache
    vehicleDataCache = FishDB.GetAllVehicles()

    local count = 0
    for _ in pairs(vehicleDataCache) do count = count + 1 end
    print(('[fish_normalizer] Started. %d vehicles in database.'):format(count))
end)

-- ============================================================
-- Helper: Check if player is admin (QBX permission)
-- ============================================================

local function IsAdmin(src)
    -- QBX uses ox_lib permission system or native ace permissions
    return IsPlayerAceAllowed(src, 'command.normalize') or
           IsPlayerAceAllowed(src, 'group.admin') or
           IsPlayerAceAllowed(src, 'group.superadmin')
end

-- ============================================================
-- Helper: Get player identifier
-- ============================================================

local function GetIdentifier(src)
    return GetPlayerIdentifier(src, 0) or ('player:' .. src)
end

-- ============================================================
-- Helper: Push vehicle state to Entity State Bag
-- Called after any normalization/remap/tune update.
-- ============================================================

local function PushVehicleState(netId, data, remapData, tuneData)
    if not netId or netId == 0 then return end
    local entityState = Entity(NetworkGetEntityFromNetworkId(netId)).state
    if not entityState then return end

    entityState:set('fish:score',     data.score or 0,             true)
    entityState:set('fish:rank',      data.rank or 'C',            true)
    entityState:set('fish:archetype', data.archetype or 'esportivo', true)

    -- Build and push handling profile
    local instability = 0
    local parts = {}
    if tuneData and tuneData.parts then
        parts = type(tuneData.parts) == 'string' and json.decode(tuneData.parts) or tuneData.parts
    end

    -- Calculate total instability from installed parts
    -- PartBonuses/PartLevels live in fish_tunes config, not normalizer.
    -- Try to get them via fish_tunes export or use hardcoded fallback.
    local PartBonuses = nil
    if GetResourceState('fish_tunes') == 'started' then
        -- fish_tunes doesn't export config tables, so use pcall on config access
        local ok, tunesConfig = pcall(function() return exports['fish_tunes']:GetPartBonuses() end)
        if ok and tunesConfig then
            PartBonuses = tunesConfig
        end
    end
    -- Hardcoded fallback for instability values (L4/L5 per category)
    if not PartBonuses then
        PartBonuses = {
            engine       = { l4 = {instability=5},  l5 = {instability=12} },
            transmission = { l4 = {instability=3},  l5 = {instability=8}  },
            turbo        = { l4 = {instability=8},  l5 = {instability=18} },
            suspension   = { l4 = {instability=3},  l5 = {instability=6}  },
            brakes       = { l4 = {instability=2},  l5 = {instability=5}  },
            tires        = { l4 = {instability=4},  l5 = {instability=8}  },
            weight       = { l4 = {instability=4},  l5 = {instability=10} },
            ecu          = { l4 = {instability=6},  l5 = {instability=14} },
        }
    end
    for cat, lv in pairs(parts) do
        local bonus = PartBonuses[cat] and PartBonuses[cat][lv]
        if bonus and bonus.instability then
            instability = instability + bonus.instability
        end
    end

    if not HandlingEngine or not HandlingEngine.BuildHandlingProfile then
        print('[fish_normalizer] WARNING: HandlingEngine not ready yet, skipping state bag push.')
        return
    end

    local ok, handlingProfile = pcall(HandlingEngine.BuildHandlingProfile, {
        score             = data.score or 0,
        archetype         = data.archetype or 'esportivo',
        subArchetype      = data.sub_archetype,
        originalArchetype = (remapData and remapData.original_archetype) or data.original_archetype,
        remapBlend        = 0.75,
        instability       = instability,
        healthData        = {
            engine     = data.engine_health     or 100,
            tires      = data.tires_health      or 100,
            suspension = data.suspension_health or 100,
            brakes     = data.brakes_health     or 100,
        }
    })

    if not ok or not handlingProfile then
        print('[fish_normalizer] WARNING: BuildHandlingProfile failed: ' .. tostring(handlingProfile))
        return
    end

    entityState:set('fish:handling', handlingProfile, true)
    entityState:set('fish:heat',     (tuneData and tuneData.heat) or 0, true)
end

-- ============================================================
-- Net Event: Player requests their own vehicle data on spawn
-- ============================================================

RegisterNetEvent('fish_normalizer:requestData')
AddEventHandler('fish_normalizer:requestData', function()
    local src = source
    local identifier = GetIdentifier(src)
    local ownerData = FishDB.GetVehiclesByOwner(identifier)
    -- Merge into cache
    for plate, row in pairs(ownerData) do
        vehicleDataCache[plate] = row
    end
    TriggerClientEvent('fish_normalizer:receiveData', src, ownerData)
end)

-- ============================================================
-- Net Event: Save normalization data
-- ============================================================

RegisterNetEvent('fish_normalizer:saveData')
AddEventHandler('fish_normalizer:saveData', function(plate, data, vehicleNetId)
    local src = source
    if not plate or not data then return end

    local identifier = GetIdentifier(src)
    data.owner_identifier = identifier

    -- Persist to DB
    FishDB.SaveVehicle(plate, data, identifier)
    vehicleDataCache[plate] = data

    print(('[fish_normalizer] %s normalized vehicle %s → %s (%d PI)'):format(
        GetPlayerName(src), plate, data.rank or '?', data.score or 0
    ))

    -- Push state bag if we have the netId
    if vehicleNetId and vehicleNetId > 0 then
        local remapData = FishDB.GetRemap(plate)
        local tuneData  = FishDB.GetTunes(plate)
        PushVehicleState(vehicleNetId, data, remapData, tuneData)
    end

    -- Notify client
    TriggerClientEvent('fish_normalizer:notify', src, {
        type    = 'success',
        message = ('Vehicle normalized: %s | %s (%d PI)'):format(plate, data.rank, data.score)
    })
end)

-- ============================================================
-- Net Event: Request normalization NUI open
-- ============================================================

RegisterNetEvent('fish_normalizer:requestOpen')
AddEventHandler('fish_normalizer:requestOpen', function(plate, vehicleNetId)
    local src = source

    -- Load existing data
    local existing  = vehicleDataCache[plate] or FishDB.GetVehicle(plate) or {}
    local remapData = FishDB.GetRemap(plate)
    local tuneData  = FishDB.GetTunes(plate)

    TriggerClientEvent('fish_normalizer:openNUI', src, {
        plate       = plate,
        vehicleNetId = vehicleNetId,
        existing    = existing,
        remapData   = remapData,
        tuneData    = tuneData,
    })
end)

-- ============================================================
-- Net Event: Admin status check
-- ============================================================

RegisterNetEvent('fish_normalizer:checkAdminStatus')
AddEventHandler('fish_normalizer:checkAdminStatus', function()
    local src = source
    TriggerClientEvent('fish_normalizer:setAdminStatus', src, IsAdmin(src))
end)

-- ============================================================
-- Net Event: Push state bag manually (e.g., on vehicle spawn)
-- ============================================================

RegisterNetEvent('fish_normalizer:pushVehicleState')
AddEventHandler('fish_normalizer:pushVehicleState', function(plate, vehicleNetId)
    if not plate or not vehicleNetId then return end
    local data      = vehicleDataCache[plate] or FishDB.GetVehicle(plate)
    if not data then return end
    local remapData = FishDB.GetRemap(plate)
    local tuneData  = FishDB.GetTunes(plate)
    vehicleDataCache[plate] = data
    PushVehicleState(vehicleNetId, data, remapData, tuneData)
end)

-- ============================================================
-- Entity Spawn/Despawn: Restore & Save state bags
-- Ensures all vehicles keep their fish:handling, fish:score, etc.
-- even after server restart, vehicle respawn, or player sync.
-- ============================================================

AddEventHandler('entityCreated', function(entity)
    -- Wait for entity to be fully synced
    Wait(3000)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    if GetEntityPopulationType(entity) < 6 then return end

    local plate = GetVehicleNumberPlateText(entity):gsub('%s+', '')
    if plate == '' then return end

    local data = vehicleDataCache[plate] or FishDB.GetVehicle(plate)
    if not data then return end

    local remapData = FishDB.GetRemap(plate)
    local tuneData  = FishDB.GetTunes(plate)

    -- Store in cache
    vehicleDataCache[plate] = data

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId > 0 then
        PushVehicleState(netId, data, remapData, tuneData)
    end
end)

AddEventHandler('entityRemoved', function(entity)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    if GetEntityPopulationType(entity) ~= 7 then return end

    local plate = GetVehicleNumberPlateText(entity):gsub('%s+', '')
    if plate == '' then return end

    local data = vehicleDataCache[plate]
    if not data then return end

    -- Save current state back to DB
    FishDB.SaveVehicle(plate, data, data.owner_identifier)
end)

-- ============================================================
-- Server Exports (for fish_remaps, fish_tunes, fish_hub)
-- ============================================================

function GetVehicleRankServer(plate)
    return vehicleDataCache[plate] or FishDB.GetVehicle(plate)
end

function GetVehicleDataServer(plate)
    if vehicleDataCache[plate] then return vehicleDataCache[plate] end
    local row = FishDB.GetVehicle(plate)
    if row then vehicleDataCache[plate] = row end
    return row
end

function SaveVehicleData(plate, data)
    if not plate or not data then return false end
    FishDB.SaveVehicle(plate, data, data.owner_identifier)
    vehicleDataCache[plate] = data
    return true
end

function GetAllNormalizedVehicles()
    return vehicleDataCache
end

exports('GetVehicleRankServer',       GetVehicleRankServer)
exports('GetVehicleDataServer',       GetVehicleDataServer)
exports('SaveVehicleData',            SaveVehicleData)
exports('GetAllNormalizedVehicles',   GetAllNormalizedVehicles)
exports('PushVehicleState',           PushVehicleState)

-- ============================================================
-- DB Exports (for fish_remaps, fish_tunes, fish_hub)
-- These wrap FishDB functions so other resources can call them.
-- ============================================================

exports('DBGetVehicle', function(plate)
    return FishDB.GetVehicle(plate)
end)
exports('DBSaveVehicle', function(plate, data, owner)
    return FishDB.SaveVehicle(plate, data, owner)
end)
exports('DBGetVehiclesByOwner', function(owner)
    return FishDB.GetVehiclesByOwner(owner)
end)
exports('DBGetAllVehicles', function()
    return FishDB.GetAllVehicles()
end)
exports('DBGetRemap', function(plate)
    return FishDB.GetRemap(plate)
end)
exports('DBSaveRemap', function(plate, data, owner)
    return FishDB.SaveRemap(plate, data, owner)
end)
exports('DBGetTunes', function(plate)
    return FishDB.GetTunes(plate)
end)
exports('DBSaveTunes', function(plate, data, owner)
    return FishDB.SaveTunes(plate, data, owner)
end)
exports('DBGetListings', function(isIllegal)
    return FishDB.GetListings(isIllegal)
end)
exports('DBCreateListing', function(data)
    return FishDB.CreateListing(data)
end)
exports('DBDeleteListing', function(id, sellerId)
    return FishDB.DeleteListing(id, sellerId)
end)
exports('DBCleanExpiredListings', function()
    return FishDB.CleanExpiredListings()
end)
exports('DBGetMessages', function(channel, limit)
    return FishDB.GetMessages(channel, limit)
end)
exports('DBSendMessage', function(channel, senderId, senderName, message)
    return FishDB.SendMessage(channel, senderId, senderName, message)
end)
exports('DBCleanOldMessages', function()
    return FishDB.CleanOldMessages()
end)
