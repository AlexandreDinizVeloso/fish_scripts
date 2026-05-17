--[[
    FISH Normalizer - Performance Application
    Applies remap and tune bonuses to vehicles
    
    Architecture: Other resources PUSH data via events.
    This file accumulates all modifiers and applies them as a single combined operation.
]]

-- Per-plate caches
local originalHandlingCache = {}  -- Original base handling values
local remapData = {}              -- Remap data pushed from fish_remaps
local tuneData = {}               -- Tune data pushed from fish_tunes
local appliedPlates = {}          -- Track which plates have been applied this session

-- ============================================================
-- Data Push Event Handlers
-- ============================================================

-- Listen for remap updates from fish_remaps
RegisterNetEvent('fish_remaps:performanceUpdated')
AddEventHandler('fish_remaps:performanceUpdated', function(plate, data)
    remapData[plate] = data
    appliedPlates[plate] = nil  -- Force reapplication
    
    -- Reapply immediately if player is in this vehicle
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local currentPlate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
            if currentPlate == plate then
                ApplyPerformanceModifications(vehicle)
            end
        end
    end
end)

-- Listen for tune updates from fish_tunes
RegisterNetEvent('fish_tunes:performanceUpdated')
AddEventHandler('fish_tunes:performanceUpdated', function(plate, data)
    tuneData[plate] = data
    appliedPlates[plate] = nil  -- Force reapplication
    
    -- Reapply immediately if player is in this vehicle
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local currentPlate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
            if currentPlate == plate then
                ApplyPerformanceModifications(vehicle)
            end
        end
    end
end)

-- Listen for reapply requests from other resources
RegisterNetEvent('fish_normalizer:requestReapply')
AddEventHandler('fish_normalizer:requestReapply', function(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
        originalHandlingCache[plate] = nil  -- Reset cache to get fresh base values
        appliedPlates[plate] = nil
        ApplyPerformanceModifications(vehicle)
    end
end)

-- ============================================================
-- Remap Multiplier Calculation
-- ============================================================

local function GetRemapMultipliers(plate)
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

-- ============================================================
-- Tune Bonus Calculation
-- ============================================================

local function GetTuneMultipliers(plate)
    local tune = tuneData[plate]
    
    if not tune then
        return {
            top_speed = 0,
            acceleration = 0,
            handling = 0,
            braking = 0
        }
    end
    
    -- Calculate total bonuses from parts
    local totalBonuses = { top_speed = 0, acceleration = 0, handling = 0, braking = 0 }
    
    if tune.parts then
        for category, level in pairs(tune.parts) do
            -- Try to get bonuses from the tunes config
            local success, bonuses = pcall(function()
                return exports.fish_tunes:GetPartBonuses(category, level)
            end)
            if success and bonuses then
                for stat, val in pairs(bonuses) do
                    if stat ~= 'instability' and stat ~= 'durability_loss' and totalBonuses[stat] then
                        totalBonuses[stat] = totalBonuses[stat] + val
                    end
                end
            end
        end
    end
    
    -- If we have pre-calculated bonuses from the data, use those
    if tune.bonuses then
        for stat, val in pairs(tune.bonuses) do
            if totalBonuses[stat] ~= nil then
                totalBonuses[stat] = val
            end
        end
    end
    
    return totalBonuses
end

-- ============================================================
-- Main Performance Application
-- ============================================================

function ApplyPerformanceModifications(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
    
    -- Cache original handling values on first encounter
    if not originalHandlingCache[plate] then
        originalHandlingCache[plate] = {
            fInitialDriveMaxFlatVel = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel'),
            fInitialDriveForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce'),
            fBrakeForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce'),
            fTractionCurveMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax'),
            fTractionCurveMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin'),
            fInitialDragCoeff = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDragCoeff'),
            fClutchChangeRateScaleUpShift = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleUpShift'),
            fClutchChangeRateScaleDownShift = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleDownShift')
        }
    end
    
    local cache = originalHandlingCache[plate]
    
    -- Get remap multipliers
    local remapMult = GetRemapMultipliers(plate)
    
    -- Get tune bonuses (raw percentage values)
    local tuneBonus = GetTuneMultipliers(plate)
    
    -- Start from base values
    local finalTopSpeed = cache.fInitialDriveMaxFlatVel
    local finalAccel = cache.fInitialDriveForce
    local finalBraking = cache.fBrakeForce
    local finalTractionMax = cache.fTractionCurveMax
    local finalTractionMin = cache.fTractionCurveMin
    
    -- Layer 1: Apply remap multipliers (multiplicative from base)
    finalTopSpeed = finalTopSpeed * remapMult.top_speed
    finalAccel = finalAccel * remapMult.acceleration
    finalBraking = finalBraking * remapMult.braking
    finalTractionMax = finalTractionMax * remapMult.handling
    finalTractionMin = finalTractionMin * remapMult.handling
    
    -- Layer 2: Apply tune bonuses (percentage increase on top of remap)
    finalTopSpeed = finalTopSpeed * (1.0 + (tuneBonus.top_speed / 100.0))
    finalAccel = finalAccel * (1.0 + (tuneBonus.acceleration / 100.0))
    finalBraking = finalBraking * (1.0 + (tuneBonus.braking / 100.0))
    finalTractionMax = finalTractionMax * (1.0 + (tuneBonus.handling / 100.0))
    finalTractionMin = finalTractionMin * (1.0 + (tuneBonus.handling / 100.0))
    
    -- Apply combined modifications to vehicle handling
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel", finalTopSpeed)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", finalAccel)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", finalBraking)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", finalTractionMax)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin", finalTractionMin)

    local dragReduction = 1.0 - math.min(0.30, (tuneBonus.top_speed / 150.0))
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", cache.fInitialDragCoeff * dragReduction)
    
    -- Apply drag reduction if top speed tune is active
    if tuneBonus.top_speed > 0 then
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", cache.fInitialDragCoeff * 0.85)
    else
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", cache.fInitialDragCoeff)
    end
    
    -- Apply transmission shift speed bonus (from transmission tune parts)
    -- Higher transmission bonuses = faster shifts
    local shiftBonus = tuneBonus.acceleration or 0
    if shiftBonus > 0 then
        local shiftMult = 1.0 + (shiftBonus / 100.0) 
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fClutchChangeRateScaleUpShift", cache.fClutchChangeRateScaleUpShift * shiftMult)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fClutchChangeRateScaleDownShift", cache.fClutchChangeRateScaleDownShift * shiftMult)
    else
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fClutchChangeRateScaleUpShift", cache.fClutchChangeRateScaleUpShift)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fClutchChangeRateScaleDownShift", cache.fClutchChangeRateScaleDownShift)
    end
    
    -- Force handling changes to take effect (FiveM workaround)
    if GetResourceState('fish_tunes') == 'started' then
        pcall(function() exports.fish_tunes:ForceHandlingRefresh(vehicle) end)
    else
        SetVehicleModKit(vehicle, 0)
        for i = 0, 35 do
            SetVehicleMod(vehicle, i, GetVehicleMod(vehicle, i), false)
        end
    end

    local enginePowerBuff = 1.0 + (tuneBonus.acceleration / 250.0) 
    ModifyVehicleTopSpeed(vehicle, 1.0)
    SetVehicleEnginePowerMultiplier(vehicle, enginePowerBuff)
    
    -- Force physics engine to apply changes
    ModifyVehicleTopSpeed(vehicle, 1.0)
    SetVehicleEnginePowerMultiplier(vehicle, 1.0) -- trick for flatvel
    
    -- Set entity max speed (1.3x factor for handling-to-actual speed difference)
    -- fInitialDriveMaxFlatVel is in mph, convert to m/s
    SetEntityMaxSpeed(vehicle, (finalTopSpeed * 1.35) / 2.236936)
    SetVehicleMaxSpeed(vehicle, 0.0)
    
    appliedPlates[plate] = true
end

-- ============================================================
-- Vehicle Entry Detection Thread
-- ============================================================

Citizen.CreateThread(function()
    local lastVehicle = nil
    
    while true do
        Citizen.Wait(500)
        
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
                local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
                
                -- Apply on vehicle change OR if not yet applied
                if vehicle ~= lastVehicle or not appliedPlates[plate] then
                    lastVehicle = vehicle
                    ApplyPerformanceModifications(vehicle)
                end
            end
        else
            lastVehicle = nil
        end
    end
end)

-- ============================================================
-- Server Data Sync (receive saved data on connect)
-- ============================================================

RegisterNetEvent('fish_normalizer:receivePerformanceData')
AddEventHandler('fish_normalizer:receivePerformanceData', function(rData, tData)
    if rData then
        for plate, data in pairs(rData) do
            remapData[plate] = data
        end
    end
    if tData then
        for plate, data in pairs(tData) do
            tuneData[plate] = data
        end
    end
end)

-- Request saved performance data from server on spawn
Citizen.CreateThread(function()
    Citizen.Wait(5000)  -- Wait for other resources to load
    TriggerServerEvent('fish_normalizer:requestPerformanceData')
end)
