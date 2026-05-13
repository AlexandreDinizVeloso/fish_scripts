--[[
    FISH Normalizer - Performance Application
    Applies remap and tune bonuses to vehicles
]]

local vehicleCache = {}
local remapData = {}
local tuneData = {}

-- Load remap data from fish_remaps
local function LoadRemapData()
    if GetResourceState('fish_remaps') == 'started' then
        TriggerEvent('fish_remaps:requestPerformanceData', function(data)
            remapData = data or {}
        end)
    end
end

-- Load tune data from fish_tunes
local function LoadTuneData()
    if GetResourceState('fish_tunes') == 'started' then
        TriggerEvent('fish_tunes:requestPerformanceData', function(data)
            tuneData = data or {}
        end)
    end
end

-- Get remap multipliers for a vehicle
function GetRemapMultipliers(vehicle)
    if not DoesEntityExist(vehicle) then return {} end
    
    local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
    local remap = remapData[plate]
    
    if not remap or not remap.finalStats then
        return {
            top_speed = 1.0,
            acceleration = 1.0,
            handling = 1.0,
            braking = 1.0
        }
    end
    
    -- Normalize stats from 0-100 to multipliers (0.8x to 1.2x)
    local stats = remap.finalStats
    return {
        top_speed = 0.8 + (stats.top_speed or 50) / 100 * 0.4,
        acceleration = 0.8 + (stats.acceleration or 50) / 100 * 0.4,
        handling = 0.8 + (stats.handling or 50) / 100 * 0.4,
        braking = 0.8 + (stats.braking or 50) / 100 * 0.4
    }
end

-- Get tune bonuses for a vehicle
function GetTuneMultipliers(vehicle)
    if not DoesEntityExist(vehicle) then return {} end
    
    local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
    local tune = tuneData[plate]
    
    if not tune or not tune.bonuses then
        return {
            top_speed = 0,
            acceleration = 0,
            handling = 0,
            braking = 0
        }
    end
    
    -- Convert bonuses from percentage (0-100) to raw increments
    return {
        top_speed = (tune.bonuses.top_speed or 0) * 0.5,
        acceleration = (tune.bonuses.acceleration or 0) * 0.5,
        handling = (tune.bonuses.handling or 0) * 0.5,
        braking = (tune.bonuses.braking or 0) * 0.5
    }
end

-- Apply performance modifications to vehicle
function ApplyPerformanceModifications(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
    
    -- Ensure cache exists
    if type(vehicleCache[plate]) ~= 'table' then
        vehicleCache[plate] = {
            fInitialDriveMaxFlatVel = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel'),
            fInitialDriveForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce'),
            fBrakeForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce'),
            fTractionCurveMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax'),
            fTractionCurveMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin')
        }
    end

    local cache = vehicleCache[plate]
    local remapMult = GetRemapMultipliers(vehicle)
    local tuneMult = GetTuneMultipliers(vehicle)
    
    -- Base handling values from cache
    local baseTopSpeed = cache.fInitialDriveMaxFlatVel
    local baseAccel = cache.fInitialDriveForce
    local baseBraking = cache.fBrakeForce
    local baseTractionMax = cache.fTractionCurveMax
    local baseTractionMin = cache.fTractionCurveMin
    
    -- Apply remap multipliers
    local finalTopSpeed = baseTopSpeed * remapMult.top_speed
    local finalAccel = baseAccel * remapMult.acceleration
    local finalBraking = baseBraking * remapMult.braking
    local finalTractionMax = baseTractionMax * remapMult.handling
    local finalTractionMin = baseTractionMin * remapMult.handling
    
    -- Apply tune bonuses (treat tuneMult as percentage increase)
    finalTopSpeed = finalTopSpeed * (1.0 + (tuneMult.top_speed / 100.0))
    finalAccel = finalAccel * (1.0 + (tuneMult.acceleration / 100.0))
    finalBraking = finalBraking * (1.0 + (tuneMult.braking / 100.0))
    finalTractionMax = finalTractionMax * (1.0 + (tuneMult.handling / 100.0))
    finalTractionMin = finalTractionMin * (1.0 + (tuneMult.handling / 100.0))
    
    -- Apply modifications using FiveM natives (per-vehicle instance)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel", finalTopSpeed)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", finalAccel)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", finalBraking)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", finalTractionMax)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin", finalTractionMin)

    local baseDrag = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDragCoeff')
    if tuneMult.top_speed > 0 then
        -- Lower drag by 15% if it has a top speed tune
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", baseDrag * 0.85)
    end

    -- Force update vehicle handling (may be required depending on FiveM version)
    ModifyVehicleTopSpeed(vehicle, 1.0)

    SetEntityMaxSpeed(vehicle, finalTopSpeed / 2.8)
end

-- Update vehicle performance when entering it
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
                
                if not vehicleCache[plate] then
                    ApplyPerformanceModifications(vehicle)
                end
            end
        end
    end
end)

-- Request data on startup
Citizen.CreateThread(function()
    Citizen.Wait(3000)
    LoadRemapData()
    LoadTuneData()
end)

-- Listen for remap updates
RegisterNetEvent('fish_remaps:performanceUpdated')
AddEventHandler('fish_remaps:performanceUpdated', function(plate, data)
    remapData[plate] = data
    -- Reapply immediately if player is in the vehicle
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local currentPlate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
        if currentPlate == plate then
            ApplyPerformanceModifications(vehicle)
        else
            vehicleCache[plate] = nil -- Force re-read next time
        end
    else
        vehicleCache[plate] = nil
    end
end)

-- Listen for tune updates
RegisterNetEvent('fish_tunes:performanceUpdated')
AddEventHandler('fish_tunes:performanceUpdated', function(plate, data)
    tuneData[plate] = data
    -- Reapply immediately if player is in the vehicle
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local currentPlate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
        if currentPlate == plate then
            ApplyPerformanceModifications(vehicle)
        else
            vehicleCache[plate] = nil
        end
    else
        vehicleCache[plate] = nil
    end
end)
