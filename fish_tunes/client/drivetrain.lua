-- fish_tunes: Client Drivetrain Physics

-- Function to apply drivetrain handling changes
function ApplyDrivetrainModifiers(vehicle, drivetrainType)
    if not DoesEntityExist(vehicle) then return end
    
    -- fDriveBiasFront is a value between 0.0 and 1.0
    -- 0.0 = RWD (100% rear)
    -- 1.0 = FWD (100% front)
    -- 0.5 = AWD (50% front, 50% rear)
    
    local driveBias = 0.5 -- Default to AWD
    
    if drivetrainType == "RWD" then
        driveBias = 0.0
    elseif drivetrainType == "FWD" then
        driveBias = 1.0
    elseif drivetrainType == "AWD" then
        driveBias = 0.5
    end
    
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveBiasFront', driveBias)
    
    -- Modify steering lock slightly based on drivetrain (RWD gets slightly more steering angle for drifting)
    local baseSteering = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock')
    if drivetrainType == "RWD" then
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', baseSteering * 1.05)
    else
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', baseSteering * 0.95)
    end
end

exports('ApplyDrivetrainModifiers', ApplyDrivetrainModifiers)
