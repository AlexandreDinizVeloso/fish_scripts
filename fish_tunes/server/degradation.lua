-- fish_tunes: Degradation Module
-- Handles vehicle part degradation, health tracking, and maintenance

Degradation = {}
local Config = {}

-- Initialize degradation module
function Degradation.Init(config)
    Config = config
end

-- Calculate degradation based on driving behavior
function Degradation.CalculateBehaviorDegradation(vehicleData, eventType, intensity, tuneQuality)
    if not Config.Degradation.enabled then return {} end
    
    local degradationApplied = {}
    local afrStatus = vehicleData.tuning_efficiency or 100
    local afrMultiplier = Degradation.GetAFRMultiplier(afrStatus)
    
    if eventType == 'harsh_acceleration' then
        degradationApplied = {
            engine = Config.DegradationRates.engine.harsh_acceleration_multiplier * intensity * afrMultiplier,
            transmission = Config.DegradationRates.transmission.harsh_acceleration_multiplier * intensity,
            turbo = (vehicleData.turbo_health and vehicleData.turbo_health < 100) and Config.DegradationRates.turbo.harsh_acceleration_multiplier * intensity * 0.5 or 0
        }
    elseif eventType == 'overspeed' then
        degradationApplied = {
            engine = Config.DegradationRates.engine.overspeed_multiplier * intensity,
            transmission = Config.DegradationRates.transmission.overspeed_multiplier * intensity,
            tires = Config.DegradationRates.tires.overspeed_multiplier * intensity,
            suspension = Config.DegradationRates.suspension.rough_handling_multiplier * intensity * 0.5
        }
    elseif eventType == 'harsh_braking' then
        degradationApplied = {
            brakes = Config.DegradationRates.brakes.harsh_braking_multiplier * intensity,
            tires = Config.DegradationRates.tires.rough_handling_multiplier * intensity * 0.5
        }
    elseif eventType == 'rough_handling' then
        degradationApplied = {
            suspension = Config.DegradationRates.suspension.rough_handling_multiplier * intensity,
            tires = Config.DegradationRates.tires.rough_handling_multiplier * intensity,
            brakes = Config.DegradationRates.brakes.harsh_braking_multiplier * intensity * 0.3
        }
    elseif eventType == 'drifting' then
        degradationApplied = {
            tires = Config.DegradationRates.tires.drifting_multiplier * intensity,
            suspension = Config.DegradationRates.suspension.rough_handling_multiplier * intensity * 0.8
        }
    elseif eventType == 'idle_high_rpm' then
        degradationApplied = {
            engine = Config.DegradationRates.engine.base_rate * 0.5 * intensity,
            turbo = Config.DegradationRates.turbo.base_rate * 0.3 * intensity
        }
    end
    
    return degradationApplied
end

-- Get AFR multiplier for tuning quality
function Degradation.GetAFRMultiplier(afrStatus)
    if afrStatus < Config.AFRTuning.optimal_range_min or afrStatus > Config.AFRTuning.optimal_range_max then
        return 1.5
    elseif afrStatus < Config.AFRTuning.lean_threshold or afrStatus > Config.AFRTuning.rich_threshold then
        return 2.5
    end
    return 1.0
end

-- Apply calculated degradation to vehicle data
function Degradation.ApplyDegradation(vehicleData, degradationTable)
    for partType, amount in pairs(degradationTable) do
        local healthKey = partType .. '_health'
        if vehicleData[healthKey] then
            vehicleData[healthKey] = math.max(0, vehicleData[healthKey] - amount)
        end
    end
    vehicleData.lastUpdated = os.time()
end

-- Calculate mileage-based degradation
function Degradation.GetMileageDegradation(mileage)
    for i = #Config.MileageThresholds, 1, -1 do
        if mileage >= Config.MileageThresholds[i].distance then
            return Config.MileageThresholds[i].degradation
        end
    end
    return 0
end

-- Get health status with color and label
function Degradation.GetPartStatus(health)
    if health >= Config.HealthStatus.excellent.min then
        return Config.HealthStatus.excellent
    elseif health >= Config.HealthStatus.good.min then
        return Config.HealthStatus.good
    elseif health >= Config.HealthStatus.fair.min then
        return Config.HealthStatus.fair
    elseif health >= Config.HealthStatus.poor.min then
        return Config.HealthStatus.poor
    else
        return Config.HealthStatus.critical
    end
end

-- Calculate performance impact from degradation
function Degradation.GetPerformanceMultiplier(partType, health)
    if Config.HealthPerformanceImpact[partType] then
        return Config.HealthPerformanceImpact[partType](health)
    end
    return 1.0
end

-- Get overall health percentage
function Degradation.GetOverallHealth(vehicleData)
    local parts = {'engine', 'transmission', 'suspension', 'brakes', 'tires'}
    local totalHealth = 0
    
    for _, part in ipairs(parts) do
        local healthKey = part .. '_health'
        totalHealth = totalHealth + (vehicleData[healthKey] or 100)
    end
    
    return math.floor(totalHealth / #parts)
end

-- Check if maintenance is needed
function Degradation.NeedsMaintenance(vehicleData, part)
    local healthKey = part .. '_health'
    local health = vehicleData[healthKey] or 100
    
    if health <= Config.HealthStatus.poor.min then
        return true, 'critical'
    elseif health <= Config.HealthStatus.fair.min then
        return true, 'warning'
    end
    
    return false
end

-- Get maintenance recommendations
function Degradation.GetMaintenanceRecommendations(vehicleData)
    local recommendations = {}
    local parts = {'engine', 'transmission', 'suspension', 'brakes', 'tires', 'turbo'}
    
    for _, part in ipairs(parts) do
        local healthKey = part .. '_health'
        local health = vehicleData[healthKey] or 100
        
        if health < 50 then
            table.insert(recommendations, {
                part = part,
                urgency = health < 25 and 'critical' or 'high',
                health = health,
                repairCost = math.ceil((100 - health) * 10) -- Example cost calculation
            })
        end
    end
    
    return recommendations
end

-- Simulate engine temperature increase during dyno tuning
function Degradation.CalculateEngineTemperature(afrStatus, ignitionTiming, boostPressure)
    local baseTemp = 90
    
    -- Lean condition increases temperature
    if afrStatus < Config.AFRTuning.optimal_range_min then
        baseTemp = baseTemp + (Config.AFRTuning.optimal_range_min - afrStatus) * 2
    end
    
    -- Ignition timing affects temperature
    if ignitionTiming > 5 then
        baseTemp = baseTemp + (ignitionTiming - 5) * 1.5
    end
    
    -- Boost pressure increases temperature
    if boostPressure > 10 then
        baseTemp = baseTemp + (boostPressure - 10) * 0.5
    end
    
    return math.floor(baseTemp)
end

-- Check for engine damage from high temperature
function Degradation.CheckEngineDamage(engineTemp, vehicleData)
    if engineTemp > Config.DynoTuning.engine_max_temp then
        local excessTemp = engineTemp - Config.DynoTuning.engine_max_temp
        local damage = excessTemp * Config.DynoTuning.damage_rate_per_degree_above_max
        vehicleData.engine_health = math.max(0, vehicleData.engine_health - damage)
        return true, damage
    end
    return false
end

return Degradation
