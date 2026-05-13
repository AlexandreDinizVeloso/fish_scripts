-- fish_tunes: Client Drivetrain Physics

-- Function to apply drivetrain handling changes
function ApplyDrivetrainModifiers(vehicle, drivetrainType)
    if not DoesEntityExist(vehicle) then return end
    
    local driveBias = 0.5 
    local baseSteering = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock')
    local baseForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce')
    
    if drivetrainType == "RWD" then
        driveBias = 0.0
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', baseSteering * 1.05)
        -- Shift traction bias back so the rear wheels can actually grip and push the car
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionBiasFront', 0.45)
        
    elseif drivetrainType == "FWD" then
        driveBias = 1.0
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', baseSteering * 0.95)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionBiasFront', 0.55)
        
    elseif drivetrainType == "AWD" then
        driveBias = 0.5
        -- AWD splits power 50/50. To stop it feeling sluggish, artificially boost the drive force
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', baseForce * 1.20)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionBiasFront', 0.5)
    end
    
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveBiasFront', driveBias)
end

exports('ApplyDrivetrainModifiers', ApplyDrivetrainModifiers)
