-- fish_tunes: Client Tire Physics

-- Function to apply tire grip modifiers based on tire type and wear
function ApplyTireModifiers(vehicle, tireData)
    if not DoesEntityExist(vehicle) then return end
    
    local tireType = tireData.type or "street"
    local tireHealthAvg = tireData.health or 100 -- 0-100%
    
    local gripMult = 1.0
    
    -- Tire type modifiers
    if tireType == "street" then
        gripMult = 1.0
    elseif tireType == "sport" then
        gripMult = 1.10
    elseif tireType == "racing" then
        gripMult = 1.25
    elseif tireType == "drift" then
        gripMult = 0.85
    end
    
    -- Health impact (lower health = less grip, exponential curve)
    local healthFactor = (tireHealthAvg / 100.0)
    if healthFactor < 0.5 then
        -- Steep drop off below 50%
        gripMult = gripMult * (healthFactor * 1.5)
    else
        gripMult = gripMult * (0.75 + (healthFactor * 0.25))
    end
    
    -- Apply to handling data
    local baseTractionMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax')
    local baseTractionMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin')
    
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', baseTractionMax * gripMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', baseTractionMin * gripMult)
end

exports('ApplyTireModifiers', ApplyTireModifiers)
