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
