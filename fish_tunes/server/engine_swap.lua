-- fish_tunes: Engine Swap Module
-- Allows vehicles to have different engine options with varying performance

EngineSwap = {}
local Config = {}

-- Engine database with performance profiles
EngineSwap.EngineDatabase = {
    stock = {
        label = 'Stock Engine',
        description = 'Original equipment - balanced performance',
        basePower = 100,
        baseTorque = 100,
        cost = 0,
        reliability = 100,
        turbo_support = false,
        nitro_support = false,
        max_rpm = 7000,
        redline_rpm = 6800
    },
    sport = {
        label = 'Sport Engine',
        description = 'Enhanced power and reliability',
        basePower = 125,
        baseTorque = 120,
        cost = 5000,
        reliability = 95,
        turbo_support = true,
        nitro_support = false,
        max_rpm = 7500,
        redline_rpm = 7200
    },
    racing_v8 = {
        label = 'Racing V8 Engine',
        description = 'High-performance 8-cylinder engine',
        basePower = 180,
        baseTorque = 160,
        cost = 25000,
        reliability = 80,
        turbo_support = true,
        nitro_support = true,
        max_rpm = 8500,
        redline_rpm = 8200
    },
    supercharged = {
        label = 'Supercharged Engine',
        description = 'Pre-tuned supercharged setup',
        basePower = 200,
        baseTorque = 180,
        cost = 35000,
        reliability = 75,
        turbo_support = true,
        nitro_support = true,
        max_rpm = 8000,
        redline_rpm = 7700
    },
    twin_turbo = {
        label = 'Twin-Turbo Engine',
        description = 'Advanced twin-turbocharged engine',
        basePower = 220,
        baseTorque = 200,
        cost = 50000,
        reliability = 70,
        turbo_support = true,
        nitro_support = true,
        max_rpm = 9000,
        redline_rpm = 8700
    },
    hybrid = {
        label = 'Hybrid Engine',
        description = 'Electric motor + combustion engine',
        basePower = 160,
        baseTorque = 170,
        cost = 40000,
        reliability = 90,
        turbo_support = false,
        nitro_support = false,
        max_rpm = 6500,
        redline_rpm = 6200,
        fuel_efficiency = 1.4
    },
    drift_spec = {
        label = 'Drift Spec Engine',
        description = 'Optimized for drift control and response',
        basePower = 150,
        baseTorque = 140,
        cost = 15000,
        reliability = 85,
        turbo_support = true,
        nitro_support = false,
        max_rpm = 8200,
        redline_rpm = 8000,
        acceleration_priority = true
    }
}

-- Initialize engine swap module
function EngineSwap.Init(config)
    Config = config
end

-- Initialize vehicle engine data
function EngineSwap.InitializeEngine(vehicleData, engineType)
    engineType = engineType or 'stock'
    
    local engine = EngineSwap.EngineDatabase[engineType]
    if not engine then
        engine = EngineSwap.EngineDatabase.stock
    end
    
    vehicleData.engine = {
        type = engineType,
        label = engine.label,
        base_power = engine.basePower,
        base_torque = engine.baseTorque,
        reliability = engine.reliability,
        max_rpm = engine.max_rpm,
        redline_rpm = engine.redline_rpm,
        installed_at = os.time(),
        miles_on_engine = 0,
        turbo_compatible = engine.turbo_support,
        nitro_compatible = engine.nitro_support,
        fuel_efficiency = engine.fuel_efficiency or 1.0
    }
    
    return vehicleData.engine
end

-- Get engine info
function EngineSwap.GetEngineInfo(engineType)
    return EngineSwap.EngineDatabase[engineType] or EngineSwap.EngineDatabase.stock
end

-- Get available engines with cost
function EngineSwap.GetAvailableEngines()
    local engines = {}
    for engineType, data in pairs(EngineSwap.EngineDatabase) do
        table.insert(engines, {
            type = engineType,
            label = data.label,
            description = data.description,
            power = data.basePower,
            torque = data.baseTorque,
            cost = data.cost,
            reliability = data.reliability
        })
    end
    
    table.sort(engines, function(a, b) return a.cost < b.cost end)
    return engines
end

-- Perform engine swap
function EngineSwap.SwapEngine(vehicleData, newEngineType, cost)
    local newEngine = EngineSwap.EngineDatabase[newEngineType]
    if not newEngine then
        return false, 'Engine type not found'
    end
    
    -- Store old engine info
    if vehicleData.engine then
        if not vehicleData.engine_history then
            vehicleData.engine_history = {}
        end
        table.insert(vehicleData.engine_history, {
            type = vehicleData.engine.type,
            installed_at = vehicleData.engine.installed_at,
            miles_on_engine = vehicleData.engine.miles_on_engine
        })
    end
    
    -- Install new engine
    EngineSwap.InitializeEngine(vehicleData, newEngineType)
    
    -- Reset engine health and degradation
    vehicleData.engine_health = 100
    vehicleData.transmission_health = 100  -- Recommend trans check
    vehicleData.mileage = 0  -- Reset for new engine
    
    -- Reset tuning for new engine
    if vehicleData.dyno then
        vehicleData.dyno.power_output = newEngine.basePower
        vehicleData.dyno.torque_output = newEngine.baseTorque
    end
    
    return true, 'Engine swap successful'
end

-- Get engine health impact on performance
function EngineSwap.GetEnginePerformanceMultiplier(engineHealth, reliability)
    local healthMult = engineHealth / 100
    local reliabilityBonus = (reliability / 100) * 0.1  -- Up to 10% bonus
    
    return math.max(0.5, (healthMult * 0.9) + reliabilityBonus)
end

-- Get current engine info
function EngineSwap.GetCurrentEngineInfo(vehicleData)
    if not vehicleData.engine then
        return nil
    end
    
    local engine = vehicleData.engine
    local healthMult = EngineSwap.GetEnginePerformanceMultiplier(
        vehicleData.engine_health or 100,
        engine.reliability
    )
    
    return {
        type = engine.type,
        label = engine.label,
        base_power = engine.base_power,
        base_torque = engine.base_torque,
        current_power = math.floor(engine.base_power * healthMult),
        current_torque = math.floor(engine.base_torque * healthMult),
        reliability = engine.reliability,
        engine_health = vehicleData.engine_health or 100,
        max_rpm = engine.max_rpm,
        redline_rpm = engine.redline_rpm,
        installed_at = engine.installed_at,
        miles_on_engine = engine.miles_on_engine or 0,
        turbo_compatible = engine.turbo_compatible,
        nitro_compatible = engine.nitro_compatible,
        fuel_efficiency = engine.fuel_efficiency
    }
end

-- Check if engine can support turbo
function EngineSwap.CanUseTurbo(vehicleData)
    if not vehicleData.engine then return false end
    return vehicleData.engine.turbo_compatible
end

-- Check if engine can support nitro
function EngineSwap.CanUseNitro(vehicleData)
    if not vehicleData.engine then return false end
    return vehicleData.engine.nitro_compatible
end

-- Estimate engine swap cost
function EngineSwap.GetSwapCost(fromEngine, toEngine)
    local fromData = EngineSwap.GetEngineInfo(fromEngine)
    local toData = EngineSwap.GetEngineInfo(toEngine)
    
    local engineCost = toData.cost - fromData.cost
    local laborCost = math.floor(math.abs(toData.basePower - fromData.basePower) * 100)
    
    return engineCost + laborCost
end

-- Update engine miles
function EngineSwap.AddEngineMiles(vehicleData, distance)
    if not vehicleData.engine then return 0 end
    
    vehicleData.engine.miles_on_engine = (vehicleData.engine.miles_on_engine or 0) + distance
    return vehicleData.engine.miles_on_engine
end

-- Get engine age/condition
function EngineSwap.GetEngineCondition(vehicleData)
    if not vehicleData.engine then return nil end
    
    local milesOnEngine = vehicleData.engine.miles_on_engine or 0
    local health = vehicleData.engine_health or 100
    
    local condition = 'Perfect'
    if health >= 90 then
        condition = 'Excellent'
    elseif health >= 75 then
        condition = 'Good'
    elseif health >= 50 then
        condition = 'Fair'
    elseif health >= 25 then
        condition = 'Poor'
    else
        condition = 'Critical'
    end
    
    return {
        condition = condition,
        health = health,
        miles = milesOnEngine,
        age_days = math.floor((os.time() - vehicleData.engine.installed_at) / 86400),
        maintenance_due = health < 50 or milesOnEngine > 50000
    }
end

-- Get engine history
function EngineSwap.GetEngineHistory(vehicleData)
    if not vehicleData.engine_history then
        return {}
    end
    
    local history = {}
    for i, record in ipairs(vehicleData.engine_history) do
        table.insert(history, {
            sequence = i,
            engine_type = record.type,
            installed_at = record.installed_at,
            miles_on_engine = record.miles_on_engine
        })
    end
    
    return history
end

-- Recommend engine upgrade
function EngineSwap.RecommendUpgrade(vehicleData, targetArchetype)
    if not vehicleData.engine then return nil end
    
    local currentPower = vehicleData.engine.base_power
    
    -- Determine optimal power for archetype
    local targetPower = 100
    if targetArchetype == 'dragster' then
        targetPower = 200
    elseif targetArchetype == 'drift_king' then
        targetPower = 150
    elseif targetArchetype == 'curve_king' then
        targetPower = 140
    elseif targetArchetype == 'late_surger' then
        targetPower = 160
    end
    
    if currentPower < targetPower then
        for engineType, engineData in pairs(EngineSwap.EngineDatabase) do
            if engineData.basePower >= targetPower then
                return {
                    recommended_engine = engineType,
                    label = engineData.label,
                    power_gain = engineData.basePower - currentPower,
                    cost = EngineSwap.GetSwapCost(vehicleData.engine.type, engineType)
                }
            end
        end
    end
    
    return nil
end

return EngineSwap
