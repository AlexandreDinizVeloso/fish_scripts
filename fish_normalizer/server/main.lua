-- ============================================================
-- fish_normalizer: Server Main (oxmysql + Entity State Bags)
-- Vehicle normalization open to all players. Provides exports for all modules.
-- ============================================================

local vehicleDataCache = {}  -- in-memory cache keyed by plate
local tunesCache = {}        -- L1 cache: tunes data keyed by plate
local remapsCache = {}       -- L1 cache: remaps data keyed by plate

-- DB is set as global FishDB by shared/database.lua (loaded before this file)

-- ============================================================
-- Startup
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local DB = FishDB
    FishDB.CreateTables()
    vehicleDataCache = FishDB.GetAllVehicles()

    -- L1 Cache: preload all tunes and remaps into RAM (O(1) lookup at runtime)
    local allTunes = MySQL.query.await('SELECT * FROM fish_vehicle_tunes', {})
    if allTunes then
        for _, row in ipairs(allTunes) do
            if row.plate then
                local data = row
                if data.parts and type(data.parts) == 'string' then
                    data.parts = json.decode(data.parts) or {}
                end
                tunesCache[row.plate] = data
            end
        end
    end

    local allRemaps = MySQL.query.await('SELECT * FROM fish_vehicle_remaps', {})
    if allRemaps then
        for _, row in ipairs(allRemaps) do
            if row.plate then
                local data = row
                if data.stats and type(data.stats) == 'string' then
                    data.stats = json.decode(data.stats) or {}
                end
                if data.final_stats and type(data.final_stats) == 'string' then
                    data.final_stats = json.decode(data.final_stats) or {}
                end
                remapsCache[row.plate] = data
            end
        end
    end

    local count = 0
    for _ in pairs(vehicleDataCache) do count = count + 1 end
    local tunesCount = 0
    for _ in pairs(tunesCache) do tunesCount = tunesCount + 1 end
    local remapsCount = 0
    for _ in pairs(remapsCache) do remapsCount = remapsCount + 1 end
    print(('[fish_normalizer] Started. %d vehicles, %d tunes, %d remaps in cache.'):format(count, tunesCount, remapsCount))
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

    local partsTable = type(parts) == 'string' and json.decode(parts) or parts

    local levelPI = {
        stock = 0,
        l1 = 10,
        l2 = 18,
        l3 = 26,
        l4 = 34,
        l5 = 40
    }

    for cat, lv in pairs(partsTable) do
        if levelPI[lv] then
            tunePI = tunePI + levelPI[lv]
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
-- ============================================================
-- Calculate display PI = base normalization score + tune bonus + remap bonus
-- ============================================================

local function GetDampedPI(base_score)
    local lowerBound = math.floor(base_score)
    local upperBound = math.ceil(base_score)
    
    lowerBound = math.max(0, math.min(1000, lowerBound))
    upperBound = math.max(0, math.min(1000, upperBound))
    
    if lowerBound == upperBound then
        return PI_LUT[lowerBound] or 0.0
    end
    
    -- O(1) Linear Interpolation in RAM to prevent floating-point Cache Misses
    local weight = base_score - lowerBound
    return (PI_LUT[lowerBound] or 0.0) * (1 - weight) + (PI_LUT[upperBound] or 0.0) * weight
end

-- ============================================================
-- PI Cascade: M_final = (M_base + ΔT) × λ_remap
--   M_base  = normalizer-derived base PI (dbScore)
--   ΔT      = tunes additive PI (part bonuses)
--   λ_remap = remap multiplicative coefficient [0.92 .. 1.08]
-- ============================================================

local function CalculateDisplayScore(dbScore, tunePI, remapData)
    local basePI = dbScore or 500
    local deltaT = tunePI or 0

    -- Step 1: additive tune delta
    local afterTune = basePI + deltaT

    -- Step 2: multiplicative remap coefficient (λ)
    -- λ derived from remap final_stats average deviation from 50 (neutral).
    -- Range: 0.92 (all stats at 0) to 1.08 (all stats at 100).
    -- 50 = neutral = λ 1.0 (no change from remap)
    local lambda = 1.0
    if remapData then
        local stats = remapData.final_stats or remapData.finalStats
        if stats then
            local avg = ((stats.top_speed or 50) + (stats.acceleration or 50)
                       + (stats.handling or 50) + (stats.braking or 50)) / 4
            lambda = 0.92 + ((avg / 100) * 0.16)
        end
    end

    return math.max(0, math.min(1000, math.floor(afterTune * lambda)))
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
-- Only a display score (normScore + tunePI + remapPI) is pushed to state bag.
-- ============================================================

function PushVehicleState(netId, data, remapData, tuneData)
    if not netId or netId == 0 then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end
    local entityState = Entity(entity).state
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

    -- PI Cascade: M_final = (M_base + ΔT) × λ_remap
    -- M_base = dbScore (normalizer), ΔT = tunePI (additive), λ = remap coefficient (multiplicative)
    local displayScore = CalculateDisplayScore(dbScore, tunePI, remapData)
    local displayRank = GetRankFromScore(displayScore)
    local drivetrain = (tuneData and tuneData.drivetrain) or 'FWD'

    -- Bitfield Packing: empacota estados booleanos em um único int32 para reduzir payload MsgPack
    -- Bit 0 (1): vehicle has custom parts (isTuned)
    -- Bit 1 (2): vehicle has damage on any component
    -- Bits 2-31: reservados para flags futuras
    local flags = 0
    if tuneData and tuneData.parts and next(tuneData.parts) then
        flags = flags | 1  -- bit 0: isTuned
    end
    local hasDamage = (data.engine_health or 100) < 100
                   or (data.brakes_health or 100) < 100
                   or (data.suspension_health or 100) < 100
    if hasDamage then
        flags = flags | 2  -- bit 1: hasDamage
    end

    -- Consolidated Physics Matrix: ALL entity state in a SINGLE MsgPack payload
    -- Eliminates redundant state bags: fish:heat, fish:tire_compound, fish:tire_handling,
    -- fish:vehicle_flags, fish:ecu_tune — reducing network propagation from N packets to 1
    local physicsMatrix = {
        score = displayScore,
        rank = displayRank,
        archetype = archetype,
        handling = handlingProfile,
        heat = (tuneData and tuneData.heat) or 0,
        drivetrain = drivetrain,
        flags = flags,
        -- Consolidated tuning state (previously separate state bags)
        tire_compound = (tuneData and tuneData.tire_compound) or nil,
        tire_handling = (tuneData and tuneData.tire_handling) or nil,
        vehicle_flags = (tuneData and tuneData.vehicle_flags) or nil,
        ecu_tune = (tuneData and tuneData.ecu_tune) or nil,
    }
    entityState:set('fish_physics_matrix', physicsMatrix, true)

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
-- Entity Spawn: Fila de Reconciliação (elimina corrotinas zumbis)
-- ============================================================

local serverReconciliationQueue = {}
local RECONCILIATION_MAX_RETRIES = 5

-- Consumidor Único Não-Bloqueante da fila de reconciliação
CreateThread(function()
    while true do
        for entity, data in pairs(serverReconciliationQueue) do
            if DoesEntityExist(entity) and GetEntityType(entity) == 2 then
                if GetEntityPopulationType(entity) >= 6 then
                    local plate = GetVehicleNumberPlateText(entity):gsub('%s+', '')
                    if plate ~= '' then
                        local vehData = vehicleDataCache[plate] or FishDB.GetVehicle(plate)
                        if vehData then
                            local remapData = FishDB.GetRemap(plate)
                            local tuneData  = FishDB.GetTunes(plate)
                            vehicleDataCache[plate] = vehData
                            local netId = NetworkGetNetworkIdFromEntity(entity)
                            if netId and netId > 0 then
                                PushVehicleState(netId, vehData, remapData, tuneData)
                            end
                        end
                    end
                    serverReconciliationQueue[entity] = nil -- Remove da fila
                end
            else
                -- Incrementa contagem de tentativas, descarta após exceder limite
                data.retries = (data.retries or 0) + 1
                if data.retries >= RECONCILIATION_MAX_RETRIES then
                    serverReconciliationQueue[entity] = nil
                end
            end
        end
        Wait(500) -- Polling mitigado a cada 500ms para estabilidade de rede
    end
end)

AddEventHandler('entityCreated', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    -- Adiciona à fila de reconciliação em vez de criar corrotina bloqueante
    serverReconciliationQueue[entity] = { retries = 0 }
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
    -- L1 Cache: read from RAM in O(1), fallback to DB only on cache miss
    if remapsCache[plate] then return remapsCache[plate] end
    local row = FishDB.GetRemap(plate)
    if row then
        if row.stats and type(row.stats) == 'string' then
            row.stats = json.decode(row.stats) or {}
        end
        if row.final_stats and type(row.final_stats) == 'string' then
            row.final_stats = json.decode(row.final_stats) or {}
        end
        remapsCache[plate] = row
    end
    return row
end)
exports('DBSaveRemap', function(plate, data, owner)
    local success = FishDB.SaveRemap(plate, data, owner)
    if success then
        -- Write-through: update L1 cache immediately
        remapsCache[plate] = data
        local rData = {
            [plate] = {
                plate = plate,
                category = data.category,
                sub_category = data.sub_category,
                stats = data.stats,
                finalStats = data.finalStats or data.final_stats or data.finalStats
            }
        }
        TriggerClientEvent('fish_normalizer:receivePerformanceData', -1, rData, nil)
    end
    return success
end)
exports('DBGetTunes', function(plate)
    -- L1 Cache: read from RAM in O(1), fallback to DB only on cache miss
    if tunesCache[plate] then return tunesCache[plate] end
    local row = FishDB.GetTunes(plate)
    if row then
        if row.parts and type(row.parts) == 'string' then
            row.parts = json.decode(row.parts) or {}
        end
        tunesCache[plate] = row
    end
    return row
end)
exports('DBSaveTunes', function(plate, data, owner)
    local success = FishDB.SaveTunes(plate, data, owner)
    if success then
        -- Write-through: update L1 cache immediately
        tunesCache[plate] = data
        local tData = {
            [plate] = {
                plate = plate,
                parts = data.parts or {},
                drivetrain = data.drivetrain or 'FWD',
                heat = data.heat or 0,
                tire_compound = data.tire_compound,
                vehicle_flags = data.vehicle_flags,
                ecu_tune = data.ecu_tune,
            }
        }
        TriggerClientEvent('fish_normalizer:receivePerformanceData', -1, nil, tData)
    end
    return success
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

-- ============================================================
-- Client Database Synchronizer Event
-- ============================================================

RegisterNetEvent('fish_normalizer:requestPerformanceData')
AddEventHandler('fish_normalizer:requestPerformanceData', function()
    local src = source

    -- Serve from L1 cache (already populated at startup), no DB round-trip
    local rData = {}
    for plate, row in pairs(remapsCache) do
        rData[plate] = {
            plate = plate,
            category = row.category,
            sub_category = row.sub_category,
            stats = row.stats or {},
            finalStats = row.final_stats or row.finalStats or {}
        }
    end

    local tData = {}
    for plate, row in pairs(tunesCache) do
        tData[plate] = {
            plate = plate,
            parts = row.parts or {},
            drivetrain = row.drivetrain or 'FWD',
            heat = row.heat or 0,
            tire_compound = row.tire_compound,
            vehicle_flags = row.vehicle_flags,
            ecu_tune = row.ecu_tune,
        }
    end

    TriggerClientEvent('fish_normalizer:receivePerformanceData', src, rData, tData)
end)