-- fish_tunes: Client Engine Swap Physics

function ApplyEngineSwapModifiers(vehicle, engineData)
    if not DoesEntityExist(vehicle) then return end
    
    local engineType = engineData.type or "stock"
    
    -- Update Audio
    local audioHash = "elegy" -- default fallback
    
    if engineType == "racing_v8" then
        audioHash = "dominator"
    elseif engineType == "supercharged" then
        audioHash = "franklin"
    elseif engineType == "twin_turbo" then
        audioHash = "banshee"
    elseif engineType == "hybrid" then
        audioHash = "tezeract"
    elseif engineType == "drift_spec" then
        audioHash = "futo"
    end
    
    ForceVehicleEngineAudio(vehicle, audioHash)
    
    -- Adjust native engine parameters
    local baseInitialDriveForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce')
    local powerMult = (engineData.current_power or engineData.base_power or 100) / 100.0
    
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', baseInitialDriveForce * powerMult)
end

exports('ApplyEngineSwapModifiers', ApplyEngineSwapModifiers)
