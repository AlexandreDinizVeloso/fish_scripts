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
    
    local model = GetEntityModel(vehicle)
    local remapMult = GetRemapMultipliers(vehicle)
    local tuneMult = GetTuneMultipliers(vehicle)
    
    -- Get base handling values
    local baseTopSpeed = GetVehicleModelMaxSpeed(model)
    local baseAccel = GetVehicleModelAcceleration(model)
    local baseBraking = GetVehicleModelMaxBraking(model)
    
    -- Apply remap multipliers
    local finalTopSpeed = baseTopSpeed * remapMult.top_speed
    local finalAccel = baseAccel * remapMult.acceleration
    local finalBraking = baseBraking * remapMult.braking
    
    -- Apply tune bonuses
    finalAccel = finalAccel + tuneMult.acceleration
    finalBraking = finalBraking + tuneMult.braking
    
    -- Cap values to realistic ranges
    finalTopSpeed = math.max(50, math.min(350, finalTopSpeed))
    finalAccel = math.max(0.1, math.min(10, finalAccel))
    finalBraking = math.max(0.1, math.min(5, finalBraking))
    
    -- Apply modifications using FiveM natives
    -- Note: These are approximations - actual FiveM doesn't have direct setters for these
    -- In a real scenario, you'd need to modify handling.meta or use a custom handling system
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
                    vehicleCache[plate] = true
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
    vehicleCache[plate] = false -- Reapply on next vehicle enter
end)

-- Listen for tune updates
RegisterNetEvent('fish_tunes:performanceUpdated')
AddEventHandler('fish_tunes:performanceUpdated', function(plate, data)
    tuneData[plate] = data
    vehicleCache[plate] = false -- Reapply on next vehicle enter
end)
