-- fish_tunes: Dyno Tuning Module
-- Advanced engine tuning with AFR, ignition timing, fuel table, and boost control

DynoTuning = {}
local Config = {}

-- Initialize dyno module
function DynoTuning.Init(config)
    Config = config
end

-- Dyno tuning profile structure
DynoTuning.TuningProfile = {
    afr = 13.5,                    -- Air-Fuel Ratio (optimal 13.2-13.8)
    ignition_timing = 0,           -- Ignition advance (-10 to +10 degrees)
    fuel_table = 100,              -- Fuel injection percentage (50-150)
    final_drive = 3.55,            -- Final drive ratio (1.5-4.5)
    boost_pressure = 0,            -- Turbo boost in PSI (0-30)
    engine_temp = 90,              -- Current engine temperature
    timestamp = 0                  -- Last tuning time
}

-- Initialize vehicle dyno profile
function DynoTuning.InitializeDynoProfile(vehicleData)
    vehicleData.dyno = {
        afr = 13.5,
        ignition_timing = 0,
        fuel_table = 100,
        final_drive = 3.55,
        boost_pressure = 0,
        engine_temp = 90,
        power_output = 100,
        torque_output = 100,
        last_tuned = os.time(),
        tuning_quality = 100
    }
    return vehicleData.dyno
end

-- Validate AFR within safe range
function DynoTuning.IsAFROptimal(afr)
    return afr >= Config.AFRTuning.optimal_range_min and afr <= Config.AFRTuning.optimal_range_max
end

-- Get AFR status and power loss
function DynoTuning.GetAFRStatus(afr)
    local status = {
        afr = afr,
        optimal = DynoTuning.IsAFROptimal(afr),
        lean = afr < Config.AFRTuning.optimal_range_min,
        rich = afr > Config.AFRTuning.optimal_range_max,
        critical_lean = afr < Config.AFRTuning.lean_threshold,
        critical_rich = afr > Config.AFRTuning.rich_threshold
    }
    
    -- Calculate power loss/gain
    if status.lean then
        -- Lean condition damages engine but doesn't directly reduce power until critical
        status.power_multiplier = 0.95
        status.danger = 'Lean mixture - Engine damage risk!'
    elseif status.rich then
        -- Rich condition causes power loss
        status.power_multiplier = Config.AFRTuning.rich_power_loss
        status.danger = 'Rich mixture - Power loss'
    else
        -- Optimal AFR
        status.power_multiplier = 1.0
        status.danger = nil
    end
    
    return status
end

-- Adjust AFR
function DynoTuning.SetAFR(vehicleData, afr)
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    -- Clamp to safe range
    afr = math.max(11.0, math.min(15.0, afr))
    vehicleData.dyno.afr = afr
    vehicleData.dyno.last_tuned = os.time()
    
    return DynoTuning.GetAFRStatus(afr)
end

-- Set ignition timing
function DynoTuning.SetIgnitionTiming(vehicleData, timing)
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    -- Clamp to range
    timing = math.max(Config.DynoTuning.ignition_timing_range.min, 
                      math.min(Config.DynoTuning.ignition_timing_range.max, timing))
    
    vehicleData.dyno.ignition_timing = timing
    vehicleData.dyno.last_tuned = os.time()
    
    return timing
end

-- Set fuel table (injection percentage)
function DynoTuning.SetFuelTable(vehicleData, fuelTable)
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    -- Clamp to range
    fuelTable = math.max(Config.DynoTuning.fuel_table_range.min,
                         math.min(Config.DynoTuning.fuel_table_range.max, fuelTable))
    
    vehicleData.dyno.fuel_table = fuelTable
    vehicleData.dyno.last_tuned = os.time()
    
    return fuelTable
end

-- Set final drive ratio
function DynoTuning.SetFinalDrive(vehicleData, ratio)
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    -- Clamp to range
    ratio = math.max(Config.DynoTuning.final_drive_range.min,
                     math.min(Config.DynoTuning.final_drive_range.max, ratio))
    
    vehicleData.dyno.final_drive = ratio
    vehicleData.dyno.last_tuned = os.time()
    
    return ratio
end

-- Set boost pressure (for turbocharged vehicles)
function DynoTuning.SetBoostPressure(vehicleData, psi)
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    -- Clamp to range
    psi = math.max(Config.DynoTuning.boost_pressure_range.min,
                   math.min(Config.DynoTuning.boost_pressure_range.max, psi))
    
    vehicleData.dyno.boost_pressure = psi
    vehicleData.dyno.last_tuned = os.time()
    
    return psi
end

-- Calculate engine temperature based on tuning
function DynoTuning.CalculateEngineTemperature(vehicleData, rpm, load)
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    local dyno = vehicleData.dyno
    local baseTemp = 85
    
    -- RPM affects temperature
    baseTemp = baseTemp + (rpm / 8000) * 10
    
    -- Load affects temperature
    baseTemp = baseTemp + load * 15
    
    -- Lean condition increases temperature significantly
    if dyno.afr < Config.AFRTuning.optimal_range_min then
        local leanAmount = Config.AFRTuning.optimal_range_min - dyno.afr
        baseTemp = baseTemp + leanAmount * 5
    end
    
    -- High ignition timing increases temperature
    if dyno.ignition_timing > 0 then
        baseTemp = baseTemp + dyno.ignition_timing * 1.5
    end
    
    -- Boost pressure increases temperature
    if dyno.boost_pressure > 10 then
        baseTemp = baseTemp + (dyno.boost_pressure - 10) * 0.8
    end
    
    -- Clamp temperature
    baseTemp = math.max(70, math.min(150, baseTemp))
    
    vehicleData.dyno.engine_temp = math.floor(baseTemp)
    
    return vehicleData.dyno.engine_temp
end

-- Check for engine damage from overheating
function DynoTuning.CheckEngineOverheat(vehicleData)
    if not vehicleData.dyno then return false, 0 end
    
    local temp = vehicleData.dyno.engine_temp
    
    if temp > Config.DynoTuning.engine_max_temp then
        local excessTemp = temp - Config.DynoTuning.engine_max_temp
        local damage = excessTemp * Config.DynoTuning.damage_rate_per_degree_above_max
        return true, damage
    end
    
    return false, 0
end

-- Calculate power output based on tuning
function DynoTuning.CalculatePowerOutput(vehicleData, basePower)
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    local dyno = vehicleData.dyno
    local multiplier = 1.0
    
    -- AFR affects power
    local afrStatus = DynoTuning.GetAFRStatus(dyno.afr)
    multiplier = multiplier * afrStatus.power_multiplier
    
    -- Fuel table affects power (higher = richer = more power, up to a point)
    if dyno.fuel_table > 100 then
        multiplier = multiplier + (dyno.fuel_table - 100) * 0.003
    else
        multiplier = multiplier - (100 - dyno.fuel_table) * 0.002
    end
    
    -- Ignition timing affects power (positive = more power)
    if dyno.ignition_timing > 0 then
        multiplier = multiplier + (dyno.ignition_timing / 10) * 0.05
    else
        multiplier = multiplier + (dyno.ignition_timing / 10) * 0.03  -- Slight loss with negative timing
    end
    
    -- Boost pressure adds power
    if dyno.boost_pressure > 0 then
        multiplier = multiplier + (dyno.boost_pressure / 30) * 0.4  -- Up to 40% boost
    end
    
    -- Clamp multiplier
    multiplier = math.max(0.5, math.min(1.8, multiplier))
    
    local powerOutput = basePower * multiplier
    vehicleData.dyno.power_output = math.floor(powerOutput)
    
    return vehicleData.dyno.power_output
end

-- Calculate torque output
function DynoTuning.CalculateTorqueOutput(vehicleData, baseTorque)
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    local dyno = vehicleData.dyno
    local multiplier = 1.0
    
    -- Rich AFR adds torque
    if dyno.afr > Config.AFRTuning.optimal_range_max then
        multiplier = multiplier - (dyno.afr - Config.AFRTuning.optimal_range_max) * 0.02
    else
        multiplier = multiplier + 0.05  -- Slight boost for optimal AFR
    end
    
    -- Final drive affects effective torque delivery
    if dyno.final_drive > 3.55 then
        multiplier = multiplier + (dyno.final_drive - 3.55) * 0.03
    end
    
    -- Boost pressure increases torque significantly
    if dyno.boost_pressure > 0 then
        multiplier = multiplier + (dyno.boost_pressure / 30) * 0.5
    end
    
    multiplier = math.max(0.6, math.min(1.9, multiplier))
    
    local torqueOutput = baseTorque * multiplier
    vehicleData.dyno.torque_output = math.floor(torqueOutput)
    
    return vehicleData.dyno.torque_output
end

-- Calculate top speed based on final drive
function DynoTuning.CalculateTopSpeed(baseSpeed, finalDrive)
    -- Higher final drive = higher top speed but lower acceleration
    local speedModifier = (finalDrive / 3.55)
    return math.floor(baseSpeed * speedModifier)
end

-- Calculate acceleration based on power and final drive
function DynoTuning.CalculateAcceleration(basAccel, power, finalDrive)
    local powerMod = power / 100  -- Assume base power is 100
    local driveMod = (3.55 / finalDrive)  -- Inverse relationship
    return math.floor(baseAccel * powerMod * driveMod)
end

-- Get complete dyno readout
function DynoTuning.GetDynoReadout(vehicleData, baseStats)
    if not vehicleData.dyno then
        return nil
    end
    
    local dyno = vehicleData.dyno
    local baseStats = baseStats or {power = 100, torque = 100, topSpeed = 200, acceleration = 50}
    
    local power = DynoTuning.CalculatePowerOutput(vehicleData, baseStats.power)
    local torque = DynoTuning.CalculateTorqueOutput(vehicleData, baseStats.torque)
    local topSpeed = DynoTuning.CalculateTopSpeed(baseStats.topSpeed, dyno.final_drive)
    local acceleration = DynoTuning.CalculateAcceleration(baseStats.acceleration, power, dyno.final_drive)
    
    return {
        tuning = {
            afr = dyno.afr,
            ignition_timing = dyno.ignition_timing,
            fuel_table = dyno.fuel_table,
            final_drive = dyno.final_drive,
            boost_pressure = dyno.boost_pressure
        },
        performance = {
            power = power,
            torque = torque,
            top_speed = topSpeed,
            acceleration = acceleration,
            engine_temp = dyno.engine_temp
        },
        status = {
            afr_status = DynoTuning.GetAFRStatus(dyno.afr),
            overheat_danger = dyno.engine_temp > Config.DynoTuning.engine_max_temp - 10,
            engine_temp_critical = dyno.engine_temp > Config.DynoTuning.engine_max_temp
        },
        quality = {
            tuning_quality = DynoTuning.GetTuningQuality(vehicleData),
            efficiency = DynoTuning.GetTuningEfficiency(vehicleData)
        }
    }
end

-- Calculate tuning quality score (0-100)
function DynoTuning.GetTuningQuality(vehicleData)
    if not vehicleData.dyno then return 0 end
    
    local dyno = vehicleData.dyno
    local quality = 100
    
    -- AFR affects quality
    if DynoTuning.IsAFROptimal(dyno.afr) then
        quality = quality + 10
    elseif dyno.afr < Config.AFRTuning.lean_threshold or dyno.afr > Config.AFRTuning.rich_threshold then
        quality = quality - 30
    else
        quality = quality - 10
    end
    
    -- Temperature affects quality
    if dyno.engine_temp > Config.DynoTuning.engine_max_temp then
        quality = quality - 50
    elseif dyno.engine_temp > Config.DynoTuning.engine_max_temp - 10 then
        quality = quality - 20
    end
    
    -- Extreme ignition timing reduces quality
    if math.abs(dyno.ignition_timing) > 5 then
        quality = quality - 5
    end
    
    return math.max(0, math.min(100, quality))
end

-- Get tuning efficiency (0-1, multiplier for wear rates)
function DynoTuning.GetTuningEfficiency(vehicleData)
    local quality = DynoTuning.GetTuningQuality(vehicleData)
    
    if quality >= 90 then
        return 0.8  -- 20% less wear
    elseif quality >= 75 then
        return 1.0  -- Normal wear
    elseif quality >= 50 then
        return 1.5  -- 50% more wear
    else
        return 2.0  -- 100% more wear (poor tuning)
    end
end

-- Save tuning profile
function DynoTuning.SaveTuningProfile(vehicleData, profileName)
    if not vehicleData.dyno then return false end
    
    if not vehicleData.tuning_profiles then
        vehicleData.tuning_profiles = {}
    end
    
    vehicleData.tuning_profiles[profileName] = {
        afr = vehicleData.dyno.afr,
        ignition_timing = vehicleData.dyno.ignition_timing,
        fuel_table = vehicleData.dyno.fuel_table,
        final_drive = vehicleData.dyno.final_drive,
        boost_pressure = vehicleData.dyno.boost_pressure,
        saved_at = os.time()
    }
    
    return true
end

-- Load tuning profile
function DynoTuning.LoadTuningProfile(vehicleData, profileName)
    if not vehicleData.tuning_profiles or not vehicleData.tuning_profiles[profileName] then
        return false
    end
    
    local profile = vehicleData.tuning_profiles[profileName]
    if not vehicleData.dyno then
        DynoTuning.InitializeDynoProfile(vehicleData)
    end
    
    vehicleData.dyno.afr = profile.afr
    vehicleData.dyno.ignition_timing = profile.ignition_timing
    vehicleData.dyno.fuel_table = profile.fuel_table
    vehicleData.dyno.final_drive = profile.final_drive
    vehicleData.dyno.boost_pressure = profile.boost_pressure
    vehicleData.dyno.last_tuned = os.time()
    
    return true
end

-- Get saved profiles list
function DynoTuning.GetSavedProfiles(vehicleData)
    if not vehicleData.tuning_profiles then
        return {}
    end
    
    local profiles = {}
    for name, data in pairs(vehicleData.tuning_profiles) do
        table.insert(profiles, {
            name = name,
            saved_at = data.saved_at
        })
    end
    
    return profiles
end

return DynoTuning
