-- fish_tunes: Client Dyno physics

local currentTune = nil
local isEngineOverheating = false
local overheatDamageTimer = 0

-- Function to apply physics based on dyno tuning values
function ApplyDynoTuning(vehicle, dynoData)
    if not DoesEntityExist(vehicle) then return end
    
    currentTune = dynoData
    
    -- Calculate power multiplier (1.0 is stock)
    local powerMult = 1.0
    
    -- AFR impact
    if dynoData.afr < 13.2 then
        powerMult = 0.95 -- Lean loses power
    elseif dynoData.afr > 13.8 then
        powerMult = 0.90 -- Rich loses power
    else
        powerMult = 1.05 -- Optimal AFR bonus
    end
    
    -- Ignition Timing impact (-10 to +10)
    if dynoData.timing > 0 then
        powerMult = powerMult + (dynoData.timing * 0.01)
    end
    
    -- Boost Pressure (0 to 30)
    if dynoData.boost > 0 then
        powerMult = powerMult + (dynoData.boost / 30) * 0.4
    end
    
    -- Apply engine power multiplier native
    SetVehicleEnginePowerMultiplier(vehicle, powerMult)
    
    -- Final Drive modifications (Top Speed vs Acceleration)
    -- Stock is usually around 3.55. Higher = more accel, lower = more top speed
    local driveRatio = dynoData.drive or 3.55
    local handlingInitialDriveMaxFlatVel = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    
    if handlingInitialDriveMaxFlatVel > 0 then
        -- Modify top speed
        local speedModifier = (3.55 / driveRatio)
        local newMaxSpeed = handlingInitialDriveMaxFlatVel * speedModifier
        SetEntityMaxSpeed(vehicle, (newMaxSpeed * 1.3) / 2.236936) -- Convert mph to m/s with 1.3x factor
    end
end

-- Thread for monitoring engine temperature
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if currentTune and GetPedInVehicleSeat(vehicle, -1) == ped then
                local rpm = GetVehicleCurrentRpm(vehicle)
                local temp = 85 + (currentTune.boost * 1.5) + (rpm * 15)
                
                if currentTune.afr < 13.2 then
                    temp = temp + 20 -- Lean runs hotter
                end
                
                if temp > 115 then
                    isEngineOverheating = true
                    if GetGameTimer() > overheatDamageTimer then
                        local currentHealth = GetVehicleEngineHealth(vehicle)
                        SetVehicleEngineHealth(vehicle, currentHealth - 15.0)
                        overheatDamageTimer = GetGameTimer() + 2000
                    end
                else
                    isEngineOverheating = false
                end
            end
        else
            currentTune = nil
            isEngineOverheating = false
        end
    end
end)

exports('ApplyDynoTuning', ApplyDynoTuning)
