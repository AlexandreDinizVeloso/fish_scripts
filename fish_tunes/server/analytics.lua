-- fish_tunes: Performance Analytics Module
-- Comprehensive vehicle performance statistics and calculations

local Analytics = {}
local Config = {}

-- Initialize analytics module
function Analytics.Init(config)
    Config = config
end

-- Calculate 0-100 km/h time
function Analytics.Calculate0To100Time(power, weight, drivetrainType)
    -- Simplified formula: time = weight / power * adjustment factor
    local adjustment = 1.0
    
    -- Drivetrain affects launch
    if drivetrainType == 'AWD' then
        adjustment = 0.85  -- Best traction
    elseif drivetrainType == 'RWD' then
        adjustment = 0.95  -- Wheel slip possible
    else  -- FWD
        adjustment = 1.05  -- Torque steer effect
    end
    
    -- Time = (weight / power) * 100 * adjustment * 0.01
    -- Normalized for typical car (power 100, weight 1400kg)
    local time = (weight / power) * 100 * adjustment * 0.12
    
    return math.max(3.0, math.floor(time * 10) / 10)  -- Min 3.0 seconds
end

-- Calculate 60-0 km/h braking distance
function Analytics.CalculateBrakingDistance(speed, braking, tireHealth)
    -- v² = u² + 2as
    -- s = (v² - u²) / 2a
    -- Braking deceleration in m/s²
    
    local baseDeceleration = 8.0  -- m/s² (typical car)
    local brakingModifier = (braking / 100) * 1.5  -- Up to 1.5x
    local tireModifier = tireHealth / 100  -- Tire health affects grip
    
    local actualDeceleration = baseDeceleration * brakingModifier * tireModifier
    
    -- Convert speed from km/h to m/s
    local speedMs = speed / 3.6
    
    -- Calculate distance
    local distance = (speedMs * speedMs) / (2 * actualDeceleration)
    
    return math.floor(distance)
end

-- Calculate top speed
function Analytics.CalculateTopSpeed(basePower, airResistance, weight, finalDrive)
    -- Top speed ≈ (Power * 3.6) / (Drag coefficient * area)
    -- Simplified: topSpeed = (power / (weight * drag)) * multiplier
    
    weight = weight or 1400  -- Default weight in kg
    airResistance = airResistance or 0.30
    finalDrive = finalDrive or 3.55
    
    -- Higher final drive = lower top speed but higher acceleration
    local speedModifier = (3.55 / finalDrive)
    
    local topSpeed = ((basePower / (weight * airResistance)) * 0.8) * speedModifier
    
    return math.floor(topSpeed)
end

-- Calculate acceleration (0-60 km/h more detailed)
function Analytics.CalculateAccelerationCurve(power, weight, torque, finalDrive)
    -- Acceleration depends on power, weight, and torque distribution
    
    weight = weight or 1400
    finalDrive = finalDrive or 3.55
    
    -- Force = Torque * Final Drive / Wheel Radius (simplified)
    -- Acceleration = Force / Mass
    
    local forceMultiplier = finalDrive * 2.5  -- Effective force multiplier
    local baseAccel = (power * forceMultiplier) / weight
    
    -- Create acceleration curve for gears
    local curve = {}
    for gear = 1, 6 do
        local gearEfficiency = 1.0 - ((gear - 1) * 0.05)  -- Diminishing returns per gear
        curve[gear] = math.floor(baseAccel * gearEfficiency * 10) / 10
    end
    
    return curve
end

-- Calculate estimated lap time
function Analytics.EstimateLapTime(power, handling, braking, weight, circuitLength)
    -- Simplified lap time calculation
    -- Based on average speed throughout circuit
    
    circuitLength = circuitLength or 5000  -- 5km default circuit
    weight = weight or 1400
    
    -- Straight section speed (80% of top speed average)
    local topSpeed = Analytics.CalculateTopSpeed(power, 0.30, weight, 3.55)
    local straightSpeed = topSpeed * 0.8
    
    -- Corner section affected by handling
    local cornerSpeed = (topSpeed * 0.5) * (handling / 100) * 1.2
    
    -- Acceleration sections
    local accelPenalty = (weight / power) * 2  -- Time penalty for acceleration
    
    -- Estimate lap time
    -- 50% on straights, 30% on corners, 20% accelerating
    local estimatedSpeed = (straightSpeed * 0.5) + (cornerSpeed * 0.3) + 
                           ((straightSpeed - cornerSpeed) * 0.2)
    
    local lapTime = (circuitLength / estimatedSpeed) * 3.6  -- Convert back to km/h calc
    
    return {
        time = math.floor(lapTime * 100) / 100,
        average_speed = math.floor(estimatedSpeed),
        top_speed_section = topSpeed,
        corner_speed = math.floor(cornerSpeed),
        straight_speed = math.floor(straightSpeed)
    }
end

-- Calculate handling rating
function Analytics.CalculateHandlingRating(handling, suspension, braking, weight)
    -- Handling rating from 0-100
    -- Based on multiple factors
    
    weight = weight or 1400
    
    -- Base handling stat
    local rating = handling or 50
    
    -- Suspension improves handling
    local suspensionBonus = (suspension / 100) * 20
    rating = rating + suspensionBonus
    
    -- Braking affects cornering ability
    local brakingBonus = (braking / 100) * 10
    rating = rating + brakingBonus
    
    -- Weight penalty
    local weightPenalty = ((weight - 1000) / 1000) * 5
    rating = rating - weightPenalty
    
    return math.max(0, math.min(100, math.floor(rating)))
end

-- Get comprehensive performance analysis
function Analytics.GetPerformanceAnalysis(vehicleData, baseStats)
    if not vehicleData then return nil end
    
    baseStats = baseStats or {
        power = 100,
        torque = 100,
        handling = 50,
        braking = 50,
        weight = 1400
    }
    
    -- Get actual stats with degradation applied
    local effectivePower = math.floor(baseStats.power * (vehicleData.engine_health / 100 or 1))
    local effectiveHandling = math.floor(baseStats.handling * (vehicleData.suspension_health / 100 or 1))
    local effectiveBraking = math.floor(baseStats.braking * (vehicleData.brakes_health / 100 or 1))
    
    local analysis = {
        acceleration = {
            zero_to_100 = Analytics.Calculate0To100Time(effectivePower, baseStats.weight, vehicleData.drivetrain_type or 'FWD'),
            zero_to_60 = Analytics.Calculate0To100Time(effectivePower, baseStats.weight, vehicleData.drivetrain_type) * 0.75,
            curve = Analytics.CalculateAccelerationCurve(effectivePower, baseStats.weight, baseStats.torque, vehicleData.current_gear_ratio or 3.55)
        },
        top_speed = Analytics.CalculateTopSpeed(effectivePower, 0.30, baseStats.weight, vehicleData.current_gear_ratio or 3.55),
        braking = {
            braking_distance_60_0 = Analytics.CalculateBrakingDistance(100, effectiveBraking, vehicleData.tires_health or 100),
            braking_distance_100_0 = Analytics.CalculateBrakingDistance(160, effectiveBraking, vehicleData.tires_health or 100),
            braking_rating = effectiveBraking
        },
        handling = {
            rating = Analytics.CalculateHandlingRating(effectiveHandling, vehicleData.suspension_health or 100, effectiveBraking, baseStats.weight),
            suspension_health = vehicleData.suspension_health or 100,
            tire_condition = vehicleData.tires_health or 100
        },
        efficiency = {
            fuel_efficiency = vehicleData.transmission_mode == 'auto_eco' and 1.3 or 1.0,
            engine_efficiency = vehicleData.engine_health or 100,
            transmission_efficiency = vehicleData.transmission_health or 100
        },
        estimated_lap_time = Analytics.EstimateLapTime(effectivePower, effectiveHandling, effectiveBraking, baseStats.weight, 5000),
        health_summary = {
            engine = vehicleData.engine_health or 100,
            transmission = vehicleData.transmission_health or 100,
            suspension = vehicleData.suspension_health or 100,
            brakes = vehicleData.brakes_health or 100,
            tires = vehicleData.tires_health or 100,
            overall = math.floor((vehicleData.engine_health + vehicleData.transmission_health + vehicleData.suspension_health + vehicleData.brakes_health + vehicleData.tires_health) / 5)
        }
    }
    
    return analysis
end

-- Compare two vehicles
function Analytics.CompareVehicles(vehicle1Data, vehicle2Data, baseStats1, baseStats2)
    local analysis1 = Analytics.GetPerformanceAnalysis(vehicle1Data, baseStats1)
    local analysis2 = Analytics.GetPerformanceAnalysis(vehicle2Data, baseStats2)
    
    return {
        vehicle1 = analysis1,
        vehicle2 = analysis2,
        comparison = {
            acceleration_advantage = analysis1.acceleration.zero_to_100 < analysis2.acceleration.zero_to_100 and 'Vehicle 1' or 'Vehicle 2',
            top_speed_advantage = analysis1.top_speed > analysis2.top_speed and 'Vehicle 1' or 'Vehicle 2',
            handling_advantage = analysis1.handling.rating > analysis2.handling.rating and 'Vehicle 1' or 'Vehicle 2',
            braking_advantage = analysis1.braking.braking_distance_100_0 < analysis2.braking.braking_distance_100_0 and 'Vehicle 1' or 'Vehicle 2'
        }
    }
end

-- Get performance improvement suggestions
function Analytics.GetImprovementSuggestions(vehicleData, baseStats)
    local suggestions = {}
    
    -- Engine health issues
    if vehicleData.engine_health and vehicleData.engine_health < 75 then
        table.insert(suggestions, {
            priority = 'high',
            issue = 'Engine Health Low',
            suggestion = 'Engine repair or rebuild recommended',
            impact = 'Engine health affects acceleration and top speed'
        })
    end
    
    -- Tire condition
    if vehicleData.tires_health and vehicleData.tires_health < 60 then
        table.insert(suggestions, {
            priority = 'high',
            issue = 'Tire Condition Poor',
            suggestion = 'Replace tires for better grip',
            impact = 'Better traction and braking'
        })
    end
    
    -- Suspension issues
    if vehicleData.suspension_health and vehicleData.suspension_health < 50 then
        table.insert(suggestions, {
            priority = 'medium',
            issue = 'Suspension Worn',
            suggestion = 'Suspension upgrade recommended',
            impact = 'Improved handling and cornering'
        })
    end
    
    -- Brakes
    if vehicleData.brakes_health and vehicleData.brakes_health < 50 then
        table.insert(suggestions, {
            priority = 'high',
            issue = 'Brakes Degraded',
            suggestion = 'Brake service needed',
            impact = 'Shorter braking distances'
        })
    end
    
    -- Transmission mode
    if vehicleData.transmission_mode == 'auto' then
        table.insert(suggestions, {
            priority = 'low',
            issue = 'Transmission Mode',
            suggestion = 'Switch to Eco mode for better fuel economy',
            impact = 'Better fuel efficiency'
        })
    end
    
    -- Mileage service
    if vehicleData.mileage and vehicleData.mileage > 50000 then
        table.insert(suggestions, {
            priority = 'medium',
            issue = 'High Mileage',
            suggestion = 'Major service recommended',
            impact = 'Overall vehicle performance'
        })
    end
    
    return suggestions
end

-- Calculate damage/wear risk
function Analytics.CalculateWearRisk(vehicleData)
    local risk = {
        engine_risk = math.max(0, (100 - (vehicleData.engine_health or 100)) * 0.5),
        transmission_risk = math.max(0, (100 - (vehicleData.transmission_health or 100)) * 0.4),
        brake_risk = math.max(0, (100 - (vehicleData.brakes_health or 100)) * 0.6),
        tire_risk = math.max(0, (100 - (vehicleData.tires_health or 100)) * 0.3),
        suspension_risk = math.max(0, (100 - (vehicleData.suspension_health or 100)) * 0.35)
    }
    
    local totalRisk = (risk.engine_risk + risk.transmission_risk + risk.brake_risk + risk.tire_risk + risk.suspension_risk) / 5
    
    risk.total = math.floor(totalRisk)
    risk.level = totalRisk < 10 and 'Low' or (totalRisk < 30 and 'Medium' or (totalRisk < 60 and 'High' or 'Critical'))
    
    return risk
end

return Analytics
