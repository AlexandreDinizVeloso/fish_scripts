-- ============================================================
-- fish_normalizer: Server Main (oxmysql + Entity State Bags)
-- Vehicle normalization open to all players. Provides exports for all modules.
-- ============================================================

local vehicleDataCache = {}  -- in-memory cache keyed by plate

-- DB is set as global FishDB by shared/database.lua (loaded before this file)

-- ============================================================
-- Startup
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local DB = FishDB
    FishDB.CreateTables()
    vehicleDataCache = FishDB.GetAllVehicles()

    local count = 0
    for _ in pairs(vehicleDataCache) do count = count + 1 end
    print(('[fish_normalizer] Started. %d vehicles in database.'):format(count))
end)

-- ============================================================
-- Helper: Check if player is admin (QBX permission)
-- ============================================================

local function IsAdmin(src)
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
-- Calculate Tune PI contribution from part bonuses
-- Used to add tune-based score to the handling-derived PI
-- ============================================================

local function CalculateTunePI(parts)
    local tunePI = 0
    if not parts then return 0 end

    -- Hardcoded fallback for part bonuses (matching fish_tunes/config.lua)
    local PartBonuses = {
        engine       = { stock={}, l1={acceleration=3,top_speed=2}, l2={acceleration=6,top_speed=4}, l3={acceleration=10,top_speed=7}, l4={acceleration=16,top_speed=11,instability=5}, l5={acceleration=24,top_speed=16,instability=12} },
        transmission = { stock={}, l1={acceleration=2,handling=1}, l2={acceleration=4,handling=3}, l3={acceleration=7,handling=5}, l4={acceleration=11,handling=7,instability=3}, l5={acceleration=16,handling=10,instability=8} },
        turbo        = { stock={}, l1={acceleration=4,top_speed=1}, l2={acceleration=8,top_speed=3}, l3={acceleration=13,top_speed=5}, l4={acceleration=20,top_speed=8,instability=8}, l5={acceleration=30,top_speed=12,instability=18} },
        suspension   = { stock={}, l1={handling=2,braking=1}, l2={handling=5,braking=3}, l3={handling=8,braking=5}, l4={handling=12,braking=7,instability=3}, l5={handling=18,braking=10,instability=6} },
        brakes       = { stock={}, l1={braking=3,handling=1}, l2={braking=6,handling=2}, l3={braking=10,handling=4}, l4={braking=15,handling=5,instability=2}, l5={braking=22,handling=7,instability=5} },
        tires        = { stock={}, l1={handling=2,braking=2}, l2={handling=5,braking=4}, l3={handling=8,braking=7}, l4={handling=13,braking=10,instability=4}, l5={handling=18,braking=14,instability=8} },
        weight       = { stock={}, l1={acceleration=1,handling=2}, l2={acceleration=3,handling=4}, l3={acceleration=5,handling=7}, l4={acceleration=8,handling=11,instability=4}, l5={acceleration=12,handling=16,instability=10} },
        ecu          = { stock={}, l1={acceleration=2,top_speed=1,handling=1}, l2={acceleration=4,top_speed=2,handling=2}, l3={acceleration=7,top_speed=4,handling=3}, l4={acceleration=12,top_speed=7,handling=5,instability=6}, l5={acceleration=18,top_speed=10,handling=7,instability=14} },
    }

    local partsTable = type(parts) == 'string' and json.decode(parts) or parts

    for cat, lv in pairs(partsTable) do
        local bonus = PartBonuses[cat] and PartBonuses[cat][lv]
        if bonus then
            local ts = bonus.top_speed or 0
            local ac = bonus.acceleration or 0
            local hd = bonus.handling or 0
            local br = bonus.braking or 0
            -- FIX: Reduced multipliers from ~2-2.5x to ~0.5x so tune contribution
            -- is meaningful (max ~130) without dominating the base PI score (~500-750)
            tunePI = tunePI + (ts * 0.5) + (ac * 0.5) + (hd * 0.5) + (br * 0.5)
        end
    end

    return tunePI
end

-- ============================================================
-- Calculate total instability from installed parts
-- ============================================================

local function CalculateInstability(parts)
    local instability = 0
    if not parts then return 0 end

    local instabilityMap = {
        engine = { l4 = 5, l5 = 12 },
        transmission = { l4 = 3, l5 = 8 },
        turbo = { l4 = 8, l5 = 18 },
        suspension = { l4 = 3, l5 = 6 },
        brakes = { l4 = 2, l5 = 5 },
        tires = { l4 = 4, l5 = 8 },
        weight = { l4 = 4, l5 = 10 },
        ecu = { l4 = 6, l5 = 14 },
    }

    local partsTable = type(parts) == 'string' and json.decode(parts) or parts

    for cat, lv in pairs(partsTable) do
        local inst = instabilityMap[cat] and instabilityMap[cat][lv]
        if inst then
            instability = instability + inst
        end
    end

    return instability
end

-- ============================================================
-- Calculate display PI = base normalization score + tune bonus
-- FIX: This properly combines the normalization score with tune
-- without corrupting the authoritative DB score.
-- ============================================================

local function CalculateDisplayScore(dbScore, tunePI)
    return math.max(0, math.min(1000, math.floor(dbScore + (tunePI or 0))))
end

-- ============================================================
-- Determine rank from score
-- ============================================================

local function GetRankFromScore(score)
    if score >= 900 then return 'S'
    elseif score >= 750 then return 'A'
    elseif score >= 500 then return 'B'
    elseif score >= 300 then return 'C'
    else return 'D' end
end

-- ============================================================
-- Push vehicle state to Entity State Bag (SERVER-AUTHORITATIVE)
-- Calculates PI from the handling profile using shared function
-- FIX: The authoritative score (dbScore) is NEVER overwritten.
-- Only a display score (normScore + tunePI) is pushed to state bag.
-- ============================================================

function PushVehicleState(netId, data, remapData, tuneData)
    if not netId or netId == 0 then return end
    local entityState = Entity(NetworkGetEntityFromNetworkId(netId)).state
    if not entityState then return end

    local parts = {}
    if tuneData and tuneData.parts then
        parts = type(tuneData.parts) == 'string' and json.decode(tuneData.parts) or tuneData.parts
    end

    -- Calculate instability and tune PI contribution
    local instability = CalculateInstability(parts)
    local tunePI = CalculateTunePI(parts)

    -- Build the handling profile
    local archetype = data.archetype or 'esportivo'
    local subArchetype = data.sub_archetype or data.subArchetype

    -- If archetype was changed via remap, track original for DNA blend
    local originalArchetype = nil
    if remapData and remapData.original_archetype then
        originalArchetype = remapData.original_archetype
    end

    if not HandlingEngine or not HandlingEngine.BuildHandlingProfile then
        print('[fish_normalizer] WARNING: HandlingEngine not ready yet, skipping state bag push.')
        return
    end

    -- Use the authoritative DB score to build the handling profile
    -- FIX: Always use the original normalized score, never an overwritten one
    local dbScore = data.score or 500

    local ok, handlingProfile = pcall(HandlingEngine.BuildHandlingProfile, {
        score             = dbScore,
        archetype         = archetype,
        subArchetype      = subArchetype,
        originalArchetype = originalArchetype,
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

    -- FIX: Calculate display score = base PI + tune contribution
    -- Do NOT recalculate PI from handling profile (which uses a different 0-100 scale)
    -- Do NOT overwrite data.score in the cache
    local displayScore = CalculateDisplayScore(dbScore, tunePI)
    local displayRank = GetRankFromScore(displayScore)

    -- Push state bag
    entityState:set('fish:score',     displayScore,    true)
    entityState:set('fish:rank',      displayRank,     true)
    entityState:set('fish:archetype', archetype,       true)
    entityState:set('fish:handling',  handlingProfile, true)
    entityState:set('fish:heat',      (tuneData and tuneData.heat) or 0, true)

    -- FIX: Do NOT overwrite data.score or data.rank in the cache.
    -- The authoritative normalization score must be preserved.
end

-- ============================================================
-- Save normalization data (called from client NUI)
-- ============================================================

RegisterNetEvent('fish_normalizer:saveData')
AddEventHandler('fish_normalizer:saveData', function(plate, data, vehicleNetId)
    local src = source
    if not plate or not data then return end

    local identifier = GetIdentifier(src)

    -- Build the vehicle data record
    -- Normalize key names: client may send subArchetype or sub_archetype
    local clientSub = data.subArchetype or data.sub_archetype
    local vehicleRecord = {
        plate = plate,
        owner_identifier = identifier,
        archetype = data.archetype or 'esportivo',
        sub_archetype = clientSub,
        rank = data.rank or 'C',
        score = data.score or 500,
        normalized = true,
        normalizedAt = os.time(),
        engine_health = 100,
        transmission_health = 100,
        suspension_health = 100,
        brakes_health = 100,
        tires_health = 100,
        turbo_health = 100,
    }

    -- Persist to DB
    FishDB.SaveVehicle(plate, vehicleRecord, identifier)
    vehicleDataCache[plate] = vehicleRecord

    print(('[fish_normalizer] %s normalized vehicle %s → %s (%d PI)'):format(
        GetPlayerName(src), plate, vehicleRecord.rank or '?', vehicleRecord.score or 0
    ))

    -- Push state bag with full recalculation
    if vehicleNetId and vehicleNetId > 0 then
        local remapData = FishDB.GetRemap(plate)
        local tuneData  = FishDB.GetTunes(plate)
        PushVehicleState(vehicleNetId, vehicleRecord, remapData, tuneData)
    end

    -- Notify client
    TriggerClientEvent('fish_normalizer:notify', src, {
        type    = 'success',
        message = ('Vehicle normalized: %s | %s (%d PI)'):format(plate, vehicleRecord.rank or '?', vehicleRecord.score or 0)
    })
end)

-- ============================================================
-- Request normalization NUI open
-- ============================================================

RegisterNetEvent('fish_normalizer:requestOpen')
AddEventHandler('fish_normalizer:requestOpen', function(plate, vehicleNetId)
    local src = source
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
-- Admin status check
-- ============================================================

RegisterNetEvent('fish_normalizer:checkAdminStatus')
AddEventHandler('fish_normalizer:checkAdminStatus', function()
    local src = source
    TriggerClientEvent('fish_normalizer:setAdminStatus', src, IsAdmin(src))
end)

-- ============================================================
-- Push state bag manually (e.g., on vehicle spawn)
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
-- Entity Spawn: Restore state bags
-- ============================================================

AddEventHandler('entityCreated', function(entity)
    Wait(3000)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    if GetEntityPopulationType(entity) < 6 then return end

    local plate = GetVehicleNumberPlateText(entity):gsub('%s+', '')
    if plate == '' then return end

    local data = vehicleDataCache[plate] or FishDB.GetVehicle(plate)
    if not data then return end

    local remapData = FishDB.GetRemap(plate)
    local tuneData  = FishDB.GetTunes(plate)

    vehicleDataCache[plate] = data

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId > 0 then
        PushVehicleState(netId, data, remapData, tuneData)
    end
end)

-- ============================================================
-- Entity Despawn: Save state
-- ============================================================

AddEventHandler('entityRemoved', function(entity)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    if GetEntityPopulationType(entity) ~= 7 then return end

    local plate = GetVehicleNumberPlateText(entity):gsub('%s+', '')
    if plate == '' then return end

    local data = vehicleDataCache[plate]
    if not data then return end

    FishDB.SaveVehicle(plate, data, data.owner_identifier)
end)

-- ============================================================
-- Server Exports
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

-- ============================================================
-- DB Exports
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