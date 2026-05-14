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
-- Cost Configuration
-- ============================================================

-- Part install costs per level
Config.PartCosts = {
    stock = 0,
    l1 = 1000,
    l2 = 2500,
    l3 = 5000,
    l4 = 12000,
    l5 = 25000
}

-- Drivetrain conversion cost
Config.DrivetrainCost = 5000

-- Class swap costs: from_to = cost
-- Going up costs more, going down costs less
Config.ClassSwapCosts = {
    C_B = 10000,   -- C → B: upgrade
    C_A = 30000,   -- C → A: big upgrade
    B_C = 5000,    -- B → C: downgrade
    B_A = 20000,   -- B → A: upgrade
    A_C = 5000,    -- A → C: downgrade
    A_B = 5000     -- A → B: downgrade
}

-- Class swap config
Config.ClassSwap = {
    allowed_classes = { 'C', 'B', 'A' }, -- S is NOT achievable via swap
    default_class = 'C'
}

-- Crafting recipe definitions (updated for part level naming)
Config.CraftingRecipes = {
    l1_engine = {
        id = 'l1_engine',
        label = 'L1 Engine',
        description = 'Basic performance engine upgrade — improved combustion efficiency',
        icon = '⚙️',
        category = 'engine',
        level = 'l1',
        difficulty = 40,
        success_rate = 85,
        crafting_time = 120,
        cost = 800,
        materials = { steel = 5, aluminum = 3 },
        output = { part_category = 'engine', part_level = 'l1' }
    },
    l2_engine = {
        id = 'l2_engine',
        label = 'L2 Engine',
        description = 'Mid-tier engine with forged internals and ported heads',
        icon = '⚙️',
        category = 'engine',
        level = 'l2',
        difficulty = 60,
        success_rate = 75,
        crafting_time = 240,
        cost = 2000,
        materials = { steel = 10, aluminum = 6, titanium = 2 },
        output = { part_category = 'engine', part_level = 'l2' }
    },
    l1_turbo = {
        id = 'l1_turbo',
        label = 'L1 Turbo',
        description = 'Basic turbocharger kit — mild boost increase',
        icon = '💨',
        category = 'turbo',
        level = 'l1',
        difficulty = 45,
        success_rate = 80,
        crafting_time = 150,
        cost = 1000,
        materials = { aluminum = 5, steel = 4 },
        output = { part_category = 'turbo', part_level = 'l1' }
    },
    l2_turbo = {
        id = 'l2_turbo',
        label = 'L2 Turbo',
        description = 'Performance turbo with larger compressor wheel',
        icon = '💨',
        category = 'turbo',
        level = 'l2',
        difficulty = 60,
        success_rate = 72,
        crafting_time = 300,
        cost = 2500,
        materials = { aluminum = 8, steel = 8, precision_bearing = 2 },
        output = { part_category = 'turbo', part_level = 'l2' }
    },
    l3_turbo = {
        id = 'l3_turbo',
        label = 'L3 Turbo',
        description = 'High-performance twin-scroll turbo system',
        icon = '💨',
        category = 'turbo',
        level = 'l3',
        difficulty = 75,
        success_rate = 65,
        crafting_time = 420,
        cost = 5000,
        materials = { aluminum = 12, steel = 10, precision_bearing = 4, titanium = 3 },
        output = { part_category = 'turbo', part_level = 'l3' }
    },
    l4_turbo = {
        id = 'l4_turbo',
        label = 'L4 Turbo',
        description = 'Race-spec turbo — significant boost, requires supporting mods',
        icon = '💨',
        category = 'turbo',
        level = 'l4',
        difficulty = 88,
        success_rate = 55,
        crafting_time = 600,
        cost = 12000,
        materials = { aluminum = 20, steel = 15, precision_bearing = 6, titanium = 8, rare_alloy = 2 },
        output = { part_category = 'turbo', part_level = 'l4' }
    },
    l1_suspension = {
        id = 'l1_suspension',
        label = 'L1 Suspension',
        description = 'Sport springs and dampers — improved ride control',
        icon = '🔧',
        category = 'suspension',
        level = 'l1',
        difficulty = 35,
        success_rate = 88,
        crafting_time = 100,
        cost = 600,
        materials = { steel = 6, oil = 3 },
        output = { part_category = 'suspension', part_level = 'l1' }
    },
    l2_suspension = {
        id = 'l2_suspension',
        label = 'L2 Suspension',
        description = 'Adjustable coilover system with stiffer rates',
        icon = '🔧',
        category = 'suspension',
        level = 'l2',
        difficulty = 55,
        success_rate = 78,
        crafting_time = 200,
        cost = 1800,
        materials = { steel = 12, aluminum = 6, oil = 5, springs = 2 },
        output = { part_category = 'suspension', part_level = 'l2' }
    },
    l5_suspension = {
        id = 'l5_suspension',
        label = 'L5 Suspension',
        description = 'Full race suspension — maximum grip and control',
        icon = '🔧',
        category = 'suspension',
        level = 'l5',
        difficulty = 95,
        success_rate = 45,
        crafting_time = 720,
        cost = 25000,
        materials = { steel = 30, aluminum = 20, oil = 10, springs = 8, titanium = 10, rare_alloy = 5 },
        output = { part_category = 'suspension', part_level = 'l5' }
    },
    l1_brakes = {
        id = 'l1_brakes',
        label = 'L1 Brakes',
        description = 'Upgraded brake pads and slotted rotors',
        icon = '🛑',
        category = 'brakes',
        level = 'l1',
        difficulty = 30,
        success_rate = 90,
        crafting_time = 80,
        cost = 500,
        materials = { steel = 4, ceramic = 2 },
        output = { part_category = 'brakes', part_level = 'l1' }
    },
    l3_brakes = {
        id = 'l3_brakes',
        label = 'L3 Brakes',
        description = 'Big brake kit — 6-piston calipers, drilled rotors',
        icon = '🛑',
        category = 'brakes',
        level = 'l3',
        difficulty = 70,
        success_rate = 68,
        crafting_time = 300,
        cost = 4500,
        materials = { steel = 15, ceramic = 10, brake_fluid = 5, aluminum = 5 },
        output = { part_category = 'brakes', part_level = 'l3' }
    }
}

-- ============================================================
-- Engine Degradation System
-- ============================================================

Config.Degradation = {
    enabled = true,
    updateInterval = 30000, -- Check degradation every 30 seconds in-game
}

Config.DegradationRates = {
    engine = {
        base_rate = 0.5,
        harsh_acceleration_multiplier = 2.0,
        overspeed_multiplier = 1.5,
        poor_tuning_multiplier = 3.0,
        turbo_wear_multiplier = 2.5
    },
    transmission = {
        base_rate = 0.3,
        harsh_acceleration_multiplier = 1.8,
        overspeed_multiplier = 1.2,
        poor_tuning_multiplier = 2.0,
        manual_mode_multiplier = 0.8
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
        base_rate = 0.6,
        rough_handling_multiplier = 2.2,
        overspeed_multiplier = 1.8,
        poor_tuning_multiplier = 1.3,
        drifting_multiplier = 3.0
    },
    turbo = {
        base_rate = 0.4,
        harsh_acceleration_multiplier = 3.0,
        overspeed_multiplier = 2.5,
        poor_tuning_multiplier = 4.0,
        boost_pressure_multiplier = 1.2
    }
}

Config.MileageThresholds = {
    {distance = 1000, degradation = 1},
    {distance = 5000, degradation = 3},
    {distance = 10000, degradation = 5},
    {distance = 25000, degradation = 10},
    {distance = 50000, degradation = 15},
}

Config.HealthStatus = {
    excellent = { min = 90, label = 'Excellent ✅', color = '#66BB6A' },
    good = { min = 75, label = 'Good 👍', color = '#4FC3F7' },
    fair = { min = 50, label = 'Fair ⚠️', color = '#FFD54F' },
    poor = { min = 25, label = 'Poor 🔧', color = '#FF8800' },
    critical = { min = 0, label = 'Critical ❌', color = '#FF1744' }
}

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

Config.AFRTuning = {
    optimal_range_min = 13.2,
    optimal_range_max = 13.8,
    optimal_peak = 13.5,
    lean_threshold = 12.0,
    rich_threshold = 14.5,
    lean_damage_multiplier = 3.0,
    rich_power_loss = 0.85
}

Config.DynoTuning = {
    enabled = true,
    engine_max_temp = 110,
    damage_rate_per_degree_above_max = 2.0,
    ignition_timing_range = {min = -10, max = 10},
    fuel_table_range = {min = 50, max = 150},
    final_drive_range = {min = 1.5, max = 4.5},
    boost_pressure_range = {min = 0, max = 30}
}
