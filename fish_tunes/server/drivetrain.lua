-- fish_tunes: Drivetrain Modification Module
-- Allows changing vehicle drivetrain type and handling characteristics

DrivetrainMod = {}
local Config = {}

-- Drivetrain types and their characteristics
DrivetrainMod.Drivetrains = {
    FWD = {
        label = 'Front-Wheel Drive',
        description = 'Engine power to front wheels - better traction, understeer tendency',
        acceleration_multiplier = 1.1,
        handling_multiplier = 0.95,
        traction_multiplier = 1.2,
        top_speed_multiplier = 0.95,
        cost = 5000,
        difficulty = 60,
        advantages = {
            'Better traction in wet',
            'More interior space',
            'Understeer is predictable'
        },
        disadvantages = {
            'Limited performance potential',
            'Torque steer on hard acceleration',
            'Less sporty feel'
        }
    },
    
    RWD = {
        label = 'Rear-Wheel Drive',
        description = 'Engine power to rear wheels - balanced, oversteer tendency',
        acceleration_multiplier = 1.0,
        handling_multiplier = 1.0,
        traction_multiplier = 1.0,
        top_speed_multiplier = 1.0,
        cost = 8000,
        difficulty = 75,
        advantages = {
            'Balanced performance',
            '50/50 weight distribution',
            'Better for drifting'
        },
        disadvantages = {
            'Less traction in wet',
            'Requires skill in wet weather',
            'Oversteer risk'
        }
    },
    
    AWD = {
        label = 'All-Wheel Drive',
        description = 'Power to all wheels - maximum traction, complex system',
        acceleration_multiplier = 1.25,
        handling_multiplier = 1.1,
        traction_multiplier = 1.4,
        top_speed_multiplier = 0.9,
        cost = 15000,
        difficulty = 90,
        advantages = {
            'Maximum traction',
            'Excellent in all weather',
            'Quick acceleration'
        },
        disadvantages = {
            'Complex maintenance',
            'Reduced top speed',
            'Reduced fuel economy',
            'Less fun for drifting'
        }
    }
}

-- Initialize drivetrain module
function DrivetrainMod.Init(config)
    Config = config
end

-- Get drivetrain info
function DrivetrainMod.GetDrivetrainInfo(drivetrainType)
    return DrivetrainMod.Drivetrains[drivetrainType] or DrivetrainMod.Drivetrains.RWD
end

-- Get all available drivetrains
function DrivetrainMod.GetAvailableDrivetrains()
    local drivetrains = {}
    for type, data in pairs(DrivetrainMod.Drivetrains) do
        table.insert(drivetrains, {
            type = type,
            label = data.label,
            description = data.description,
            cost = data.cost,
            difficulty = data.difficulty,
            acceleration_bonus = math.floor((data.acceleration_multiplier - 1) * 100),
            handling_bonus = math.floor((data.handling_multiplier - 1) * 100),
            traction_bonus = math.floor((data.traction_multiplier - 1) * 100)
        })
    end
    return drivetrains
end

-- Change drivetrain
function DrivetrainMod.ChangeDrivetrain(vehicleData, newDrivetrainType)
    local newDrivetrain = DrivetrainMod.GetDrivetrainInfo(newDrivetrainType)
    if not newDrivetrain then
        return false, 'Invalid drivetrain type'
    end
    
    local oldDrivetrain = vehicleData.drivetrain_type or 'RWD'
    
    -- Store change history
    if not vehicleData.drivetrain_history then
        vehicleData.drivetrain_history = {}
    end
    
    table.insert(vehicleData.drivetrain_history, {
        from = oldDrivetrain,
        to = newDrivetrainType,
        changed_at = os.time(),
        mileage_at_change = vehicleData.mileage or 0
    })
    
    -- Update drivetrain
    vehicleData.drivetrain_type = newDrivetrainType
    vehicleData.drivetrain_changed = os.time()
    
    -- Recalculate archetype if needed (for fish_normalizer)
    -- This triggers a re-score in the normalizer
    
    return true, 'Drivetrain changed successfully'
end

-- Calculate handling changes
function DrivetrainMod.CalculateHandlingImpact(vehicleData, baseHandling)
    local drivetrain = DrivetrainMod.GetDrivetrainInfo(vehicleData.drivetrain_type or 'RWD')
    
    return math.floor(baseHandling * drivetrain.handling_multiplier)
end

-- Calculate acceleration impact
function DrivetrainMod.CalculateAccelerationImpact(vehicleData, baseAccel)
    local drivetrain = DrivetrainMod.GetDrivetrainInfo(vehicleData.drivetrain_type or 'RWD')
    
    return math.floor(baseAccel * drivetrain.acceleration_multiplier)
end

-- Calculate traction coefficient
function DrivetrainMod.CalculateTraction(vehicleData, baseTraction)
    local drivetrain = DrivetrainMod.GetDrivetrainInfo(vehicleData.drivetrain_type or 'RWD')
    
    return math.floor(baseTraction * drivetrain.traction_multiplier)
end

-- Calculate top speed impact
function DrivetrainMod.CalculateTopSpeedImpact(vehicleData, baseTopSpeed)
    local drivetrain = DrivetrainMod.GetDrivetrainInfo(vehicleData.drivetrain_type or 'RWD')
    
    return math.floor(baseTopSpeed * drivetrain.top_speed_multiplier)
end

-- Get drift capability
function DrivetrainMod.GetDriftCapability(vehicleData)
    local drivetrain = DrivetrainMod.GetDrivetrainInfo(vehicleData.drivetrain_type or 'RWD')
    
    -- RWD is best for drifting (100)
    local capability = 50  -- Base capability
    
    if vehicleData.drivetrain_type == 'RWD' then
        capability = 100
    elseif vehicleData.drivetrain_type == 'FWD' then
        capability = 20
    elseif vehicleData.drivetrain_type == 'AWD' then
        capability = 30
    end
    
    return capability
end

-- Get wet weather traction
function DrivetrainMod.GetWetWeatherTraction(vehicleData)
    local drivetrain = DrivetrainMod.GetDrivetrainInfo(vehicleData.drivetrain_type or 'RWD')
    
    local baseTraction = 0.8
    
    if vehicleData.drivetrain_type == 'FWD' then
        baseTraction = 0.9
    elseif vehicleData.drivetrain_type == 'RWD' then
        baseTraction = 0.7
    elseif vehicleData.drivetrain_type == 'AWD' then
        baseTraction = 0.95
    end
    
    return baseTraction
end

-- Get cost and difficulty
function DrivetrainMod.GetConversionCost(fromType, toType)
    local fromDrivetrain = DrivetrainMod.GetDrivetrainInfo(fromType)
    local toDrivetrain = DrivetrainMod.GetDrivetrainInfo(toType)
    
    -- Base cost difference
    local baseCostDiff = toDrivetrain.cost - fromDrivetrain.cost
    
    -- Additional cost based on current vehicle state
    local complexityMultiplier = 1.0
    if fromType == toType then
        complexityMultiplier = 0.0
    elseif (fromType == 'FWD' and toType == 'AWD') or (fromType == 'AWD' and toType == 'FWD') then
        complexityMultiplier = 1.5  -- Complex conversion
    else
        complexityMultiplier = 1.2  -- Moderate conversion
    end
    
    return math.floor(baseCostDiff * complexityMultiplier), toDrivetrain.difficulty
end

-- Get drivetrain characteristics for display
function DrivetrainMod.GetDetailedCharacteristics(drivetrainType)
    local drivetrain = DrivetrainMod.GetDrivetrainInfo(drivetrainType)
    
    return {
        type = drivetrainType,
        label = drivetrain.label,
        description = drivetrain.description,
        characteristics = {
            acceleration = math.floor((drivetrain.acceleration_multiplier - 1) * 100),
            handling = math.floor((drivetrain.handling_multiplier - 1) * 100),
            traction = math.floor((drivetrain.traction_multiplier - 1) * 100),
            top_speed = math.floor((drivetrain.top_speed_multiplier - 1) * 100)
        },
        advantages = drivetrain.advantages,
        disadvantages = drivetrain.disadvantages,
        cost = drivetrain.cost,
        difficulty = drivetrain.difficulty
    }
end

-- Compare drivetrains
function DrivetrainMod.CompareDrivetrains(type1, type2)
    local dt1 = DrivetrainMod.GetDetailedCharacteristics(type1)
    local dt2 = DrivetrainMod.GetDetailedCharacteristics(type2)
    
    return {
        drivetrain1 = dt1,
        drivetrain2 = dt2,
        acceleration_advantage = dt1.characteristics.acceleration > dt2.characteristics.acceleration and type1 or type2,
        handling_advantage = dt1.characteristics.handling > dt2.characteristics.handling and type1 or type2,
        traction_advantage = dt1.characteristics.traction > dt2.characteristics.traction and type1 or type2,
        top_speed_advantage = dt1.characteristics.top_speed > dt2.characteristics.top_speed and type1 or type2
    }
end

-- Get recommended drivetrain for archetype
function DrivetrainMod.RecommendForArchetype(archetype)
    if archetype == 'dragster' then
        return {
            recommended = 'AWD',
            reason = 'Maximum traction for straight-line acceleration'
        }
    elseif archetype == 'drift_king' then
        return {
            recommended = 'RWD',
            reason = 'Best control for drifting'
        }
    elseif archetype == 'curve_king' then
        return {
            recommended = 'RWD',
            reason = 'Balanced for corner precision'
        }
    elseif archetype == 'street_racer' then
        return {
            recommended = 'FWD',
            reason = 'Reliable urban performance'
        }
    else
        return {
            recommended = 'RWD',
            reason = 'Balanced all-purpose'
        }
    end
end

-- Get drivetrain history
function DrivetrainMod.GetDrivetrainHistory(vehicleData)
    if not vehicleData.drivetrain_history then
        return {}
    end
    
    local history = {}
    for i, record in ipairs(vehicleData.drivetrain_history) do
        table.insert(history, {
            sequence = i,
            from = record.from,
            to = record.to,
            changed_at = record.changed_at,
            mileage_at_change = record.mileage_at_change
        })
    end
    
    return history
end

return DrivetrainMod
