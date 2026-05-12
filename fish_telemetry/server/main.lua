--[[
    FISH Telemetry - Server Main Module
    Handles data persistence and cross-player queries
]]

local telemetryData = {}

-- Save telemetry results
RegisterNetEvent('fish_telemetry:saveResults')
AddEventHandler('fish_telemetry:saveResults', function(result)
    local src = source
    if not result or not result.plate then return end

    local plate = result.plate
    if not telemetryData[plate] then
        telemetryData[plate] = {
            vehicle_name = result.vehicle_name,
            plate = plate,
            best = result,
            last = result,
            versions = { result },
            owner = src
        }
    else
        -- Update last
        telemetryData[plate].last = result

        -- Update best (compare metrics)
        local best = telemetryData[plate].best
        if result.max_speed > (best.max_speed or 0) then
            best.max_speed = result.max_speed
        end
        if result.zero_to_100 and (best.zero_to_100 == nil or result.zero_to_100 < best.zero_to_100) then
            best.zero_to_100 = result.zero_to_100
        end
        if result.zero_to_200 and (best.zero_to_200 == nil or result.zero_to_200 < best.zero_to_200) then
            best.zero_to_200 = result.zero_to_200
        end
        if result.hundred_to_zero and (best.hundred_to_zero == nil or result.hundred_to_zero < best.hundred_to_zero) then
            best.hundred_to_zero = result.hundred_to_zero
        end
        if result.two_hundred_to_zero and (best.two_hundred_to_zero == nil or result.two_hundred_to_zero < best.two_hundred_to_zero) then
            best.two_hundred_to_zero = result.two_hundred_to_zero
        end
        if math.abs(result.lateral_gforce or 0) > math.abs(best.lateral_gforce or 0) then
            best.lateral_gforce = result.lateral_gforce
        end

        -- Add version
        table.insert(telemetryData[plate].versions, result)
    end

    -- Save to file
    SaveTelemetryData()
end)

-- Request data for a specific plate
RegisterNetEvent('fish_telemetry:requestData')
AddEventHandler('fish_telemetry:requestData', function(plate)
    local src = source
    if telemetryData[plate] then
        TriggerClientEvent('fish_telemetry:receiveData', src, telemetryData[plate])
    end
end)

-- Request nearby vehicle data
RegisterNetEvent('fish_telemetry:requestNearbyData')
AddEventHandler('fish_telemetry:requestNearbyData', function(nearbyVehicles)
    local src = source
    local results = {}

    for _, veh in ipairs(nearbyVehicles) do
        if telemetryData[veh.plate] then
            table.insert(results, {
                plate = veh.plate,
                name = veh.name,
                distance = veh.distance,
                best = telemetryData[veh.plate].best,
                last = telemetryData[veh.plate].last,
                versionCount = #telemetryData[veh.plate].versions
            })
        end
    end

    TriggerClientEvent('fish_telemetry:receiveNearbyData', src, results)
end)

-- Request all stored data
RegisterNetEvent('fish_telemetry:requestAllData')
AddEventHandler('fish_telemetry:requestAllData', function()
    local src = source
    -- Load from file if not in memory
    if not next(telemetryData) then
        LoadTelemetryData()
    end
    TriggerClientEvent('fish_telemetry:receiveAllData', src, telemetryData)
end)

-- Clear data for a plate
RegisterNetEvent('fish_telemetry:clearData')
AddEventHandler('fish_telemetry:clearData', function()
    local src = source
    -- Find and clear data owned by this player
    for plate, data in pairs(telemetryData) do
        if data.owner == src then
            telemetryData[plate] = nil
        end
    end
    SaveTelemetryData()
end)
