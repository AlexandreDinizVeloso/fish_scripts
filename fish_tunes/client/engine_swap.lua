-- fish_tunes: Client Engine Swap Physics

function ApplyEngineSwapModifiers(vehicle, engineData)
    if not DoesEntityExist(vehicle) then return end
    
    local engineType = engineData.type or "stock"
    
    -- Update Audio
    local audioHash = "elegy"
    if engineType == "racing_v8" then audioHash = "dominator"
    elseif engineType == "supercharged" then audioHash = "franklin"
    elseif engineType == "twin_turbo" then audioHash = "banshee"
    elseif engineType == "hybrid" then audioHash = "tezeract"
    elseif engineType == "drift_spec" then audioHash = "futo"
    end
    
    ForceVehicleEngineAudio(vehicle, audioHash)
    
    -- Get the BASE force from the vehicle model (not current modified value)
    local baseInitialDriveForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce')
    
    -- Calculate power multiplier based on engine data
    -- Stock is 100, so we calculate relative improvement
    local basePower = engineData.base_power or 100
    local healthMult = 1.0
    if engineData.current_power and engineData.base_power and engineData.base_power > 0 then
        healthMult = engineData.current_power / engineData.base_power
    end
    
    -- Power scaling: each 50 points above 100 = 50% more force
    local powerScale = 1.0 + ((basePower - 100) / 200.0)  -- 100=1.0x, 150=1.25x, 200=1.5x, 250=1.75x
    powerScale = powerScale * healthMult
    
    -- Apply to handling
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', baseInitialDriveForce * powerScale)
    
    -- Also increase top speed for more powerful engines
    if basePower > 100 then
        local currentMaxVel = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel')
        local speedBonus = 1.0 + ((basePower - 100) / 500.0)  -- Subtle speed increase
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel', currentMaxVel * speedBonus)
        
        -- Update max entity speed with 1.3x factor
        SetEntityMaxSpeed(vehicle, (currentMaxVel * speedBonus * 1.3) / 2.236936)
    end
    
    -- Force handling changes to take effect (FiveM workaround)
    if GetResourceState('fish_tunes') == 'started' then
        pcall(function() exports.fish_tunes:ForceHandlingRefresh(vehicle) end)
    end
    
    -- Force physics update
    ModifyVehicleTopSpeed(vehicle, 1.0)
    SetVehicleEnginePowerMultiplier(vehicle, 1.0) -- trick for flatvel
end

exports('ApplyEngineSwapModifiers', ApplyEngineSwapModifiers)
