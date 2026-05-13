-- fish_tunes: Mileage Tracking Module
-- Tracks vehicle mileage and applies mileage-based degradation

MileageTracker = {}
local Config = {}
local playerVehicles = {} -- Track active vehicles per player

-- Initialize mileage tracker
function MileageTracker.Init(config)
    Config = config
end

-- Register player vehicle
function MileageTracker.RegisterVehicle(src, vehicleNetId, plate)
    if not playerVehicles[src] then
        playerVehicles[src] = {}
    end
    
    playerVehicles[src][vehicleNetId] = {
        plate = plate,
        startMileage = 0,
        distanceTraveled = 0,
        lastPosition = nil,
        lastUpdate = os.time(),
        eventCounter = 0
    }
end

-- Unregister player vehicle and finalize mileage
function MileageTracker.UnregisterVehicle(src, vehicleNetId)
    if playerVehicles[src] and playerVehicles[src][vehicleNetId] then
        local vehicleInfo = playerVehicles[src][vehicleNetId]
        local plate = vehicleInfo.plate
        
        -- Save final mileage
        if plate and vehicleInfo.distanceTraveled > 0 then
            MileageTracker.SaveMileage(plate, vehicleInfo.distanceTraveled)
        end
        
        playerVehicles[src][vehicleNetId] = nil
    end
end

-- Unregister all vehicles for a player (on disconnect)
function MileageTracker.UnregisterAllPlayerVehicles(src)
    if playerVehicles[src] then
        for vehicleNetId, vehicleInfo in pairs(playerVehicles[src]) do
            local plate = vehicleInfo.plate
            if plate and vehicleInfo.distanceTraveled > 0 then
                MileageTracker.SaveMileage(plate, vehicleInfo.distanceTraveled)
            end
        end
        playerVehicles[src] = nil
    end
end

-- Update mileage for active vehicle
function MileageTracker.UpdateMileage(src, vehicleNetId, position)
    if not playerVehicles[src] or not playerVehicles[src][vehicleNetId] then
        return 0
    end
    
    local vehicleInfo = playerVehicles[src][vehicleNetId]
    local distance = 0
    
    if vehicleInfo.lastPosition then
        -- Calculate distance in meters
        local dx = position.x - vehicleInfo.lastPosition.x
        local dy = position.y - vehicleInfo.lastPosition.y
        local dz = position.z - vehicleInfo.lastPosition.z
        
        distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        vehicleInfo.distanceTraveled = vehicleInfo.distanceTraveled + distance
    end
    
    vehicleInfo.lastPosition = position
    vehicleInfo.lastUpdate = os.time()
    
    return vehicleInfo.distanceTraveled
end

-- Convert meters to kilometers
function MileageTracker.MetersToKilometers(meters)
    return math.floor(meters / 1000)
end

-- Save mileage to vehicle data
function MileageTracker.SaveMileage(plate, distance)
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if vehicleData then
        local distanceKm = MileageTracker.MetersToKilometers(distance)
        vehicleData.mileage = (vehicleData.mileage or 0) + distanceKm
        vehicleData.total_driven_distance = (vehicleData.total_driven_distance or 0) + distanceKm
        
        normalizer:SaveVehicleData(plate, vehicleData)
        
        return vehicleData.mileage
    end
    
    return 0
end

-- Get current vehicle distance traveled (in session)
function MileageTracker.GetSessionDistance(src, vehicleNetId)
    if playerVehicles[src] and playerVehicles[src][vehicleNetId] then
        return playerVehicles[src][vehicleNetId].distanceTraveled
    end
    return 0
end

-- Get total mileage for vehicle
function MileageTracker.GetTotalMileage(plate)
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if vehicleData then
        return vehicleData.mileage or 0
    end
    
    return 0
end

-- Format mileage for display
function MileageTracker.FormatMileage(kilometers)
    if kilometers < 1000 then
        return kilometers .. ' km'
    else
        return string.format('%.1f', kilometers / 1000) .. 'k km'
    end
end

-- Get next maintenance milestone
function MileageTracker.GetNextMaintenanceMileage(currentMileage)
    local milestones = {1000, 5000, 10000, 25000, 50000, 100000, 250000, 500000}
    
    for _, milestone in ipairs(milestones) do
        if currentMileage < milestone then
            return milestone
        end
    end
    
    return currentMileage + 100000
end

-- Calculate mileage percentage to next milestone
function MileageTracker.GetMileageToNextMilestone(currentMileage)
    local nextMilestone = MileageTracker.GetNextMaintenanceMileage(currentMileage)
    local lastMilestone = 0
    
    for _, milestone in ipairs({1000, 5000, 10000, 25000, 50000, 100000, 250000, 500000}) do
        if milestone < nextMilestone then
            lastMilestone = milestone
        end
    end
    
    if lastMilestone == 0 then lastMilestone = currentMileage end
    
    local progress = (currentMileage - lastMilestone) / (nextMilestone - lastMilestone)
    return {
        current = currentMileage,
        next = nextMilestone,
        progress = math.min(100, math.floor(progress * 100)),
        remaining = nextMilestone - currentMileage
    }
end

-- Track driving events (harsh acceleration, etc.)
function MileageTracker.RecordDrivingEvent(src, vehicleNetId, eventType)
    if playerVehicles[src] and playerVehicles[src][vehicleNetId] then
        local vehicleInfo = playerVehicles[src][vehicleNetId]
        vehicleInfo.eventCounter = vehicleInfo.eventCounter + 1
        
        -- Notify degradation system
        local degradation = exports['fish_tunes']:ApplyDegradation(vehicleInfo.plate, eventType, 1.0)
        
        return vehicleInfo.eventCounter
    end
    return 0
end

-- Get detailed mileage information
function MileageTracker.GetDetailedMileageInfo(plate)
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if vehicleData then
        local mileage = vehicleData.mileage or 0
        local nextMilestone = MileageTracker.GetNextMaintenanceMileage(mileage)
        
        return {
            current = mileage,
            formatted = MileageTracker.FormatMileage(mileage),
            nextMaintenance = nextMilestone,
            remainingToMaintenance = nextMilestone - mileage,
            totalDriven = vehicleData.total_driven_distance or 0,
            harshEvents = vehicleData.harsh_acceleration_events or 0,
            overspeedEvents = vehicleData.overspeed_events or 0,
            roughHandlingEvents = vehicleData.rough_handling_events or 0,
            lastUpdated = vehicleData.lastUpdated or 0
        }
    end
    
    return nil
end

return MileageTracker
