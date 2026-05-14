-- fish_tunes: Client Tire Physics
-- Enhanced with per-wheel tire health tracking (inspired by renzu_tuners)

-- Per-plate tire health cache: [plate] = { [wheelIndex] = health }
local tireHealthCache = {}

-- ============================================================
-- Initialize per-wheel tire health for a vehicle
-- ============================================================
local function InitTireHealth(vehicle, plate)
    if tireHealthCache[plate] then return end
    
    local wheelCount = GetVehicleNumberOfWheels(vehicle)
    tireHealthCache[plate] = {}
    for i = 0, wheelCount - 1 do
        tireHealthCache[plate][i] = 100.0
    end
end

-- ============================================================
-- Apply tire grip modifiers based on tire type and per-wheel wear
-- ============================================================
function ApplyTireModifiers(vehicle, tireData)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local tireType = tireData.type or "street"
    
    -- Initialize per-wheel health if needed
    InitTireHealth(vehicle, plate)
    
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
    elseif tireType == "offroad" then
        gripMult = 0.95  -- slightly less on-road grip
    end
    
    -- Apply per-wheel health degradation
    local wheels = GetVehicleNumberOfWheels(vehicle)
    local totalHealth = 0
    
    if tireData.wearPerWheel then
        -- Use per-wheel data if provided
        for i = 0, wheels - 1 do
            local wear = tireData.wearPerWheel[i] or 0
            tireHealthCache[plate][i] = math.max(0, math.min(100, 100 - wear))
            totalHealth = totalHealth + tireHealthCache[plate][i]
        end
    else
        -- Use average health from tireData
        local avgHealth = tireData.health or 100
        for i = 0, wheels - 1 do
            tireHealthCache[plate][i] = avgHealth
            totalHealth = totalHealth + avgHealth
        end
    end
    
    -- Calculate average health factor (renzu_tuners pattern: total / (wheels * 100))
    local healthFactor = totalHealth / (wheels * 100.0)
    
    -- Steep drop off below 50% average
    if healthFactor < 0.5 then
        gripMult = gripMult * (healthFactor * 1.5)
    else
        gripMult = gripMult * (0.75 + (healthFactor * 0.25))
    end
    
    -- Get base handling values (use cache if available via normalizer)
    local baseTractionMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax')
    local baseTractionMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin')
    local baseTractionLateral = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveLateral')
    local baseLowSpeedTractionLoss = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fLowSpeedTractionLossMult')
    local baseTractionLoss = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionLossMult')
    
    -- Apply grip multiplier to all traction-related handling fields
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', baseTractionMax * gripMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', baseTractionMin * gripMult)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveLateral', baseTractionLateral * gripMult)
    
    -- Low speed traction and loss mult also affected by tire health
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fLowSpeedTractionLossMult', baseLowSpeedTractionLoss * healthFactor)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionLossMult', baseTractionLoss * healthFactor)
end

-- ============================================================
-- Degrade tires (called periodically while driving)
-- ============================================================
function DegradeTires(vehicle, intensity)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    InitTireHealth(vehicle, plate)
    
    local wheels = GetVehicleNumberOfWheels(vehicle)
    local degraded = false
    
    for i = 0, wheels - 1 do
        -- Random degradation per wheel (not uniform - some tires wear faster)
        if math.random(1, 100) < 50 then
            local degradeAmount = (intensity or 0.1) * (0.5 + math.random() * 1.0)
            tireHealthCache[plate][i] = math.max(0, tireHealthCache[plate][i] - degradeAmount)
            degraded = true
        end
    end
    
    return degraded, tireHealthCache[plate]
end

-- ============================================================
-- Get per-wheel tire health
-- ============================================================
function GetTireHealth(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    return tireHealthCache[plate]
end

-- ============================================================
-- Set tire health (for repairs)
-- ============================================================
function SetTireHealth(vehicle, health)
    if not DoesEntityExist(vehicle) then return end
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local wheels = GetVehicleNumberOfWheels(vehicle)
    tireHealthCache[plate] = {}
    for i = 0, wheels - 1 do
        tireHealthCache[plate][i] = health or 100.0
    end
end

-- ============================================================
-- Clear tire cache for a plate
-- ============================================================
function ClearTireCache(plate)
    tireHealthCache[plate] = nil
end

exports('ApplyTireModifiers', ApplyTireModifiers)
exports('DegradeTires', DegradeTires)
exports('GetTireHealth', GetTireHealth)
exports('SetTireHealth', SetTireHealth)
exports('ClearTireCache', ClearTireCache)
