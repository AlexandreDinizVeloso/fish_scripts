Config = {}

Config.PartCategories = {
    { key = 'engine', label = 'Engine', icon = '⚙️', description = 'Core power output' },
    { key = 'transmission', label = 'Transmission', icon = '🔄', description = 'Gear ratios & shift speed' },
    { key = 'turbo', label = 'Turbo', icon = '💨', description = 'Forced induction boost' },
    { key = 'suspension', label = 'Suspension', icon = '🔧', description = 'Ride height & dampening' },
    { key = 'brakes', label = 'Brakes', icon = '🛑', description = 'Stopping power & fade' },
    { key = 'tires', label = 'Tires', icon = '🔘', description = 'Grip compound & width' },
    { key = 'weight', label = 'Weight Reduction', icon = '🪶', description = 'Chassis lightening' },
    { key = 'ecu', label = 'ECU', icon = '💻', description = 'Engine management tuning' }
}

Config.PartLevels = {
    stock = { label = 'Stock', level = 0, legal = true, heat = 0, icon = '📦', color = '#8B8B8B' },
    l1 = { label = 'L1', level = 1, legal = true, heat = 0, icon = '🟢', color = '#66BB6A' },
    l2 = { label = 'L2', level = 2, legal = true, heat = 0, icon = '🔵', color = '#4FC3F7' },
    l3 = { label = 'L3', level = 3, legal = true, heat = 0, icon = '🟡', color = '#FFD54F' },
    l4 = { label = 'L4', level = 4, legal = false, heat = 15, icon = '🟠', color = '#FF8800' },
    l5 = { label = 'L5', level = 5, legal = false, heat = 25, icon = '🔴', color = '#FF1744' }
}

-- Stat bonuses per level per category (cumulative)
Config.PartBonuses = {
    engine = {
        stock = { acceleration = 0, top_speed = 0 },
        l1 = { acceleration = 3, top_speed = 2 },
        l2 = { acceleration = 6, top_speed = 4 },
        l3 = { acceleration = 10, top_speed = 7 },
        l4 = { acceleration = 16, top_speed = 11, instability = 5 },
        l5 = { acceleration = 24, top_speed = 16, instability = 12, durability_loss = 10 }
    },
    transmission = {
        stock = { acceleration = 0, handling = 0 },
        l1 = { acceleration = 2, handling = 1 },
        l2 = { acceleration = 4, handling = 3 },
        l3 = { acceleration = 7, handling = 5 },
        l4 = { acceleration = 11, handling = 7, instability = 3 },
        l5 = { acceleration = 16, handling = 10, instability = 8 }
    },
    turbo = {
        stock = { acceleration = 0, top_speed = 0 },
        l1 = { acceleration = 4, top_speed = 1 },
        l2 = { acceleration = 8, top_speed = 3 },
        l3 = { acceleration = 13, top_speed = 5 },
        l4 = { acceleration = 20, top_speed = 8, instability = 8 },
        l5 = { acceleration = 30, top_speed = 12, instability = 18, durability_loss = 15 }
    },
    suspension = {
        stock = { handling = 0, braking = 0 },
        l1 = { handling = 2, braking = 1 },
        l2 = { handling = 5, braking = 3 },
        l3 = { handling = 8, braking = 5 },
        l4 = { handling = 12, braking = 7, instability = 3 },
        l5 = { handling = 18, braking = 10, instability = 6 }
    },
    brakes = {
        stock = { braking = 0, handling = 0 },
        l1 = { braking = 3, handling = 1 },
        l2 = { braking = 6, handling = 2 },
        l3 = { braking = 10, handling = 4 },
        l4 = { braking = 15, handling = 5, instability = 2 },
        l5 = { braking = 22, handling = 7, instability = 5 }
    },
    tires = {
        stock = { handling = 0, braking = 0 },
        l1 = { handling = 2, braking = 2 },
        l2 = { handling = 5, braking = 4 },
        l3 = { handling = 8, braking = 7 },
        l4 = { handling = 13, braking = 10, instability = 4 },
        l5 = { handling = 18, braking = 14, instability = 8, durability_loss = 12 }
    },
    weight = {
        stock = { acceleration = 0, handling = 0 },
        l1 = { acceleration = 1, handling = 2 },
        l2 = { acceleration = 3, handling = 4 },
        l3 = { acceleration = 5, handling = 7 },
        l4 = { acceleration = 8, handling = 11, instability = 4 },
        l5 = { acceleration = 12, handling = 16, instability = 10 }
    },
    ecu = {
        stock = { acceleration = 0, top_speed = 0, handling = 0 },
        l1 = { acceleration = 2, top_speed = 1, handling = 1 },
        l2 = { acceleration = 4, top_speed = 2, handling = 2 },
        l3 = { acceleration = 7, top_speed = 4, handling = 3 },
        l4 = { acceleration = 12, top_speed = 7, handling = 5, instability = 6 },
        l5 = { acceleration = 18, top_speed = 10, handling = 7, instability = 14, durability_loss = 8 }
    }
}

Config.MaxHeat = 100
Config.HeatDecayRate = 0.5 -- per minute when not in vehicle
Config.PoliceHeatThreshold = 40 -- heat level where police attention starts
Config.PoliceHeatMultiplier = 0.01 -- chance per heat point per check

-- ============================================================
-- Engine Degradation System
-- ============================================================

Config.Degradation = {
    enabled = true,
    updateInterval = 30000, -- Check degradation every 30 seconds in-game
}

-- Degradation rates per part (health points lost per event)
-- Rates can be modified based on part level and tuning efficiency
Config.DegradationRates = {
    engine = {
        base_rate = 0.5, -- per 1000km normal driving
        harsh_acceleration_multiplier = 2.0,
        overspeed_multiplier = 1.5,
        poor_tuning_multiplier = 3.0, -- if AFR is bad (outside 13.2-13.8)
        turbo_wear_multiplier = 2.5 -- extra wear if turbo installed
    },
    transmission = {
        base_rate = 0.3,
        harsh_acceleration_multiplier = 1.8,
        overspeed_multiplier = 1.2,
        poor_tuning_multiplier = 2.0,
        manual_mode_multiplier = 0.8 -- manual tuning is gentler
    },
    suspension = {
        base_rate = 0.4,
        rough_handling_multiplier = 2.0,
        overspeed_multiplier = 1.3,
        poor_tuning_multiplier = 1.5
    },
    brakes = {
        base_rate = 0.35,
        harsh_braking_multiplier = 2.5,
        overspeed_multiplier = 2.0,
        poor_tuning_multiplier = 1.5
    },
    tires = {
        base_rate = 0.6, -- tires wear faster
        rough_handling_multiplier = 2.2,
        overspeed_multiplier = 1.8,
        poor_tuning_multiplier = 1.3,
        drifting_multiplier = 3.0
    },
    turbo = {
        base_rate = 0.4,
        harsh_acceleration_multiplier = 3.0,
        overspeed_multiplier = 2.5,
        poor_tuning_multiplier = 4.0, -- turbo sensitive to tuning
        boost_pressure_multiplier = 1.2 -- high boost = more wear
    }
}

-- Mileage thresholds for automatic degradation events
Config.MileageThresholds = {
    {distance = 1000, degradation = 1},    -- -1 health at 1000km
    {distance = 5000, degradation = 3},    -- -3 health at 5000km
    {distance = 10000, degradation = 5},   -- -5 health at 10000km
    {distance = 25000, degradation = 10},  -- -10 health at 25000km
    {distance = 50000, degradation = 15},  -- -15 health at 50000km
}

-- Health status thresholds
Config.HealthStatus = {
    excellent = { min = 90, label = 'Excellent ✅', color = '#66BB6A' },
    good = { min = 75, label = 'Good 👍', color = '#4FC3F7' },
    fair = { min = 50, label = 'Fair ⚠️', color = '#FFD54F' },
    poor = { min = 25, label = 'Poor 🔧', color = '#FF8800' },
    critical = { min = 0, label = 'Critical ❌', color = '#FF1744' }
}

-- Performance impact per health level (percentage multiplier)
Config.HealthPerformanceImpact = {
    engine = function(health)
        if health >= 90 then return 1.0
        elseif health >= 75 then return 0.98
        elseif health >= 50 then return 0.94
        elseif health >= 25 then return 0.88
        else return 0.75 end
    end,
    transmission = function(health)
        if health >= 90 then return 1.0
        elseif health >= 75 then return 0.97
        elseif health >= 50 then return 0.92
        elseif health >= 25 then return 0.85
        else return 0.70 end
    end,
    tires = function(health)
        if health >= 90 then return 1.0
        elseif health >= 75 then return 0.95
        elseif health >= 50 then return 0.88
        elseif health >= 25 then return 0.75
        else return 0.55 end
    end,
    brakes = function(health)
        if health >= 90 then return 1.0
        elseif health >= 75 then return 0.98
        elseif health >= 50 then return 0.93
        elseif health >= 25 then return 0.82
        else return 0.65 end
    end,
    suspension = function(health)
        if health >= 90 then return 1.0
        elseif health >= 75 then return 0.96
        elseif health >= 50 then return 0.89
        elseif health >= 25 then return 0.80
        else return 0.60 end
    end
}

-- AFR (Air-Fuel Ratio) tuning parameters
Config.AFRTuning = {
    optimal_range_min = 13.2,
    optimal_range_max = 13.8,
    optimal_peak = 13.5,
    lean_threshold = 12.0,  -- too lean, engine damage risk
    rich_threshold = 14.5,  -- too rich, power loss
    lean_damage_multiplier = 3.0,  -- high degradation if too lean
    rich_power_loss = 0.85  -- 15% power loss if too rich
}

-- Dyno tuning parameters
Config.DynoTuning = {
    enabled = true,
    engine_max_temp = 110, -- celsius, can explode if exceeded
    damage_rate_per_degree_above_max = 2.0,
    ignition_timing_range = {min = -10, max = 10},
    fuel_table_range = {min = 50, max = 150},
    final_drive_range = {min = 1.5, max = 4.5},
    boost_pressure_range = {min = 0, max = 30} -- PSI
}
