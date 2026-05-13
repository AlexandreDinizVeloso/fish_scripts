-- fish_normalizer: Server Data Management
-- Handles data persistence and retrieval

local DataStore = {}

-- Initialize data store
function DataStore.Init()
    local data = LoadResourceFile(GetCurrentResourceName(), 'server/vehicle_data.json')
    if data then
        return json.decode(data) or {}
    end
    return {}
end

-- Save data to file
function DataStore.Save(data)
    SaveResourceFile(GetCurrentResourceName(), 'server/vehicle_data.json', json.encode(data), -1)
end

-- Get vehicle by plate
function DataStore.GetVehicle(data, plate)
    return data[plate]
end

-- Set vehicle data
function DataStore.SetVehicle(data, plate, vehicleInfo)
    -- Ensure all required maintenance fields exist
    if vehicleInfo then
        vehicleInfo.mileage = vehicleInfo.mileage or 0
        vehicleInfo.engine_health = vehicleInfo.engine_health or 100
        vehicleInfo.transmission_health = vehicleInfo.transmission_health or 100
        vehicleInfo.suspension_health = vehicleInfo.suspension_health or 100
        vehicleInfo.brakes_health = vehicleInfo.brakes_health or 100
        vehicleInfo.tires_health = vehicleInfo.tires_health or 100
        vehicleInfo.turbo_health = vehicleInfo.turbo_health or 100
        vehicleInfo.tuning_efficiency = vehicleInfo.tuning_efficiency or 100
        vehicleInfo.drivetrain_type = vehicleInfo.drivetrain_type or 'FWD'
        vehicleInfo.transmission_mode = vehicleInfo.transmission_mode or 'auto'
        vehicleInfo.current_gear_ratio = vehicleInfo.current_gear_ratio or 1.0
        vehicleInfo.created = vehicleInfo.created or os.time()
        vehicleInfo.lastUpdated = os.time()
        vehicleInfo.lastMaintained = vehicleInfo.lastMaintained or os.time()
        vehicleInfo.total_driven_distance = vehicleInfo.total_driven_distance or 0
        vehicleInfo.harsh_acceleration_events = vehicleInfo.harsh_acceleration_events or 0
        vehicleInfo.overspeed_events = vehicleInfo.overspeed_events or 0
        vehicleInfo.rough_handling_events = vehicleInfo.rough_handling_events or 0
    end
    data[plate] = vehicleInfo
    DataStore.Save(data)
    return true
end

-- Delete vehicle data
function DataStore.DeleteVehicle(data, plate)
    data[plate] = nil
    DataStore.Save(data)
    return true
end

-- Get vehicles by owner
function DataStore.GetVehiclesByOwner(data, owner)
    local results = {}
    for plate, info in pairs(data) do
        if info.owner == owner then
            results[plate] = info
        end
    end
    return results
end

-- Get vehicles by archetype
function DataStore.GetVehiclesByArchetype(data, archetype)
    local results = {}
    for plate, info in pairs(data) do
        if info.archetype == archetype then
            results[plate] = info
        end
    end
    return results
end

-- Get vehicles by rank
function DataStore.GetVehiclesByRank(data, rankName)
    local results = {}
    local Config = exports['fish_normalizer']:GetConfig()
    for plate, info in pairs(data) do
        if info.score then
            for _, rank in ipairs(Config.Ranks) do
                if rank.name == rankName and info.score >= rank.min and info.score <= rank.max then
                    results[plate] = info
                end
            end
        end
    end
    return results
end

-- Get statistics
function DataStore.GetStats(data)
    local stats = {
        total = 0,
        byRank = {},
        byArchetype = {},
        avgScore = 0
    }

    local totalScore = 0
    for plate, info in pairs(data) do
        stats.total = stats.total + 1
        totalScore = totalScore + (info.score or 0)

        local arch = info.archetype or 'unknown'
        stats.byArchetype[arch] = (stats.byArchetype[arch] or 0) + 1
    end

    if stats.total > 0 then
        stats.avgScore = math.floor(totalScore / stats.total)
    end

    return stats
end

return DataStore
