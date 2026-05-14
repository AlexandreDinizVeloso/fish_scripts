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
    
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    
    -- Store original values on first call
    if not originalHandlingCache[plate] then
        originalHandlingCache[plate] = {
            fInitialDriveForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce'),
            fInitialDriveMaxFlatVel = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel'),
            fSteeringLock = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock'),
            fTractionBiasFront = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionBiasFront'),
            fTractionCurveMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax'),
            fTractionCurveMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin')
        }
    end
    
    local orig = originalHandlingCache[plate]
    local driveBias = 0.5
    local forceMult = 1.0
    local topSpeedMult = 1.0
    local steeringMult = 1.0
    local tractionFrontBias = 0.5
    local tractionMult = 1.0
    
    if drivetrainType == "RWD" then
        driveBias = 0.0
        forceMult = 1.10      -- 10% more force to compensate for rear-only
        topSpeedMult = 1.0     -- no top speed change
        steeringMult = 1.05    -- slightly more responsive
        tractionFrontBias = 0.45
        tractionMult = 0.95    -- slightly less front grip
        
    elseif drivetrainType == "FWD" then
        driveBias = 1.0
        forceMult = 1.10      -- 10% more force
        topSpeedMult = 0.95    -- 5% less top speed
        steeringMult = 0.95    -- slightly less responsive
        tractionFrontBias = 0.55
        tractionMult = 1.05    -- more front grip
        
    elseif drivetrainType == "AWD" then
        driveBias = 0.5
        forceMult = 1.25      -- 25% more force to compensate for drivetrain loss
        topSpeedMult = 0.90    -- 10% less top speed
        steeringMult = 1.0
        tractionFrontBias = 0.5
        tractionMult = 1.15    -- more grip overall for AWD
    end
    
    -- Apply all handling changes
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveBiasFront', driveBias)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', orig.fInitialDriveForce * forceMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', orig.fSteeringLock * steeringMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionBiasFront', tractionFrontBias)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', orig.fTractionCurveMax * tractionMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', orig.fTractionCurveMin * tractionMult)
    
    -- Apply top speed change
    local newMaxSpeed = orig.fInitialDriveMaxFlatVel * topSpeedMult
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel', newMaxSpeed)
    
    -- Force handling changes to take effect (FiveM workaround)
    ForceHandlingRefresh(vehicle)
    
    -- Set individual wheel power for accurate drivetrain simulation
    SetWheelPower(vehicle, drivetrainType)
    
    -- Force physics update with actual speed multiplier
    ModifyVehicleTopSpeed(vehicle, topSpeedMult)
    
    -- Set entity max speed (1.3x factor accounts for handling-to-actual speed difference)
    -- fInitialDriveMaxFlatVel is in mph, convert to m/s
    SetEntityMaxSpeed(vehicle, (newMaxSpeed * 1.3) / 2.236936)
end

function ClearDrivetrainCache(plate)
    originalHandlingCache[plate] = nil
end

exports('ApplyDrivetrainModifiers', ApplyDrivetrainModifiers)
exports('ClearDrivetrainCache', ClearDrivetrainCache)
exports('ForceHandlingRefresh', ForceHandlingRefresh)
