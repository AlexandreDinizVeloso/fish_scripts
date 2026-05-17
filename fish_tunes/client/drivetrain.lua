-- fish_tunes: Client Drivetrain Physics

-- Cache original handling values per vehicle
local originalHandlingCache = {}

-- ============================================================
-- Utility: Force handling changes to take effect
-- Known FiveM workaround: re-applying vehicle mods forces the
-- physics engine to pick up SetVehicleHandlingFloat changes.
-- Reference: renzu_tuners applyVehicleMods pattern
-- ============================================================
function ForceHandlingRefresh(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleModKit(vehicle, 0)
    for i = 0, 35 do
        SetVehicleMod(vehicle, i, GetVehicleMod(vehicle, i), false)
    end
end

-- ============================================================
-- Utility: Set wheel power for proper drivetrain simulation
-- Uses SetVehicleWheelIsPowered for accurate drivetrain behavior
-- ============================================================
function SetWheelPower(vehicle, drivetrainType)
    if not DoesEntityExist(vehicle) then return end
    local wheels = GetVehicleNumberOfWheels(vehicle)
    
    -- Reset all wheels first
    for i = 0, wheels - 1 do
        SetVehicleWheelIsPowered(vehicle, i, false)
    end
    
    if drivetrainType == "RWD" then
        -- Power rear wheels only (indices 2,3 for 4-wheel, 1 for 2-wheel/motorcycle)
        if wheels <= 2 then
            SetVehicleWheelIsPowered(vehicle, wheels - 1, true)
        else
            for i = 2, wheels - 1 do
                SetVehicleWheelIsPowered(vehicle, i, true)
            end
        end
    elseif drivetrainType == "FWD" then
        -- Power front wheels only (indices 0,1)
        for i = 0, math.min(1, wheels - 1) do
            SetVehicleWheelIsPowered(vehicle, i, true)
        end
    elseif drivetrainType == "AWD" then
        -- Power all wheels
        for i = 0, wheels - 1 do
            SetVehicleWheelIsPowered(vehicle, i, true)
        end
    end
end

-- ============================================================
-- Main Drivetrain Application
-- ============================================================
function ApplyDrivetrainModifiers(vehicle, drivetrainType)
    if not DoesEntityExist(vehicle) then return end
    
    local driveBias = 0.5
    local tractionFrontBias = 0.5
    
    if drivetrainType == "RWD" then
        driveBias = 0.0
        tractionFrontBias = 0.45
    elseif drivetrainType == "FWD" then
        driveBias = 1.0
        tractionFrontBias = 0.55
    elseif drivetrainType == "AWD" then
        driveBias = 0.5
        tractionFrontBias = 0.5
    end
    
    -- Apply drive layout configuration only (safe fields)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveBiasFront', driveBias)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionBiasFront', tractionFrontBias)
    
    -- Force handling changes to take effect (FiveM workaround)
    ForceHandlingRefresh(vehicle)
    
    -- Set individual wheel power for accurate drivetrain simulation
    SetWheelPower(vehicle, drivetrainType)
end

function ClearDrivetrainCache(plate)
    originalHandlingCache[plate] = nil
end

exports('ApplyDrivetrainModifiers', ApplyDrivetrainModifiers)
exports('ClearDrivetrainCache', ClearDrivetrainCache)
exports('ForceHandlingRefresh', ForceHandlingRefresh)

-- ============================================================
-- OneSync State Bag Observer Pattern: Drivetrain Synchronization
-- Reacts instantly to 'fish_drivetrain' state bag changes
-- ============================================================
AddStateBagChangeHandler('fish_drivetrain', nil, function(bagName, key, value, _, replicated)
    if not value then return end
    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end
    
    Citizen.CreateThread(function()
        local veh = NetworkGetEntityFromNetworkId(netId)
        local attempts = 0
        while not DoesEntityExist(veh) and attempts < 20 do
            Citizen.Wait(100)
            veh = NetworkGetEntityFromNetworkId(netId)
            attempts = attempts + 1
        end
        if DoesEntityExist(veh) then
            local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
            
            -- Update client tunes cache if GetRawTunesData is globally exposed
            if GetRawTunesData then
                local tData = GetRawTunesData()
                if tData then
                    if not tData[plate] then tData[plate] = {} end
                    tData[plate].drivetrain = value
                end
            end
            
            -- Apply drive layout configuration physically
            ApplyDrivetrainModifiers(veh, value)
            
            -- Force Bullet vector physics recalculation for the local mesh
            ModifyVehicleTopSpeed(veh, 1.0)
            
            -- Clear local cache to force reapplication of normalized multipliers
            if exports.fish_normalizer and exports.fish_normalizer.ClearDrivetrainCache then
                exports.fish_normalizer:ClearDrivetrainCache(plate)
            end
            
            TriggerEvent('fish_tunes:performanceUpdated', plate, { drivetrain = value })
        end
    end)
end)
