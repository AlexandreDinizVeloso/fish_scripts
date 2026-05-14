Config = {}

-- DNA Inheritance
Config.DNAInheritance = 0.75 -- 75% new archetype, 25% original
Config.SubArchInheritance = 1.0 -- 100% for sub-archetype changes

-- Stat settings
Config.MaxStatAdjustment = 15 -- max +/- points per stat
Config.Stats = { 'top_speed', 'acceleration', 'handling', 'braking' }

Config.StatLabels = {
    top_speed = 'Top Speed',
    acceleration = 'Acceleration',
    handling = 'Handling',
    braking = 'Braking'
}

Config.StatColors = {
    top_speed = '#00d4ff',
    acceleration = '#ff8800',
    handling = '#00ff88',
    braking = '#aa44ff'
}

-- ==================== COSTS ====================
Config.Costs = {
    dyno_flash = 2000,          -- ECU flash (dyno tuning)
    trans_mode = 3000,          -- Transmission mode change
    gear_ratio = 5000,          -- Gear ratio preset change
    archetype_change = 15000,   -- Archetype remap
    subarchetype_change = 5000, -- Sub-archetype change
    adjustment_per_point = 1000 -- Per stat adjustment point (absolute value)
}

-- ==================== DYNO DEFAULTS ====================
Config.DynoDefaults = {
    afr = 13.5,        -- Air-Fuel Ratio (optimal: 13.2-13.8)
    timing = 0,        -- Ignition timing offset (-10 to +10 degrees)
    boost = 0,         -- Boost pressure in PSI (0 if no turbo)
    finalDrive = 3.55  -- Final drive ratio
}

-- ==================== TRANSMISSION DEFAULTS ====================
Config.TransDefaults = {
    mode = 'auto',     -- auto, eco, sport, manual
    gearPreset = 'stock' -- stock, short, long, drag, drift
}

-- ==================== GEAR RATIO IMPACT ====================
Config.GearRatioImpact = {
    stock  = { accel = 0,   speed = 0 },
    short  = { accel = 15,  speed = -10 },
    long   = { accel = -10, speed = 15 },
    drag   = { accel = 25,  speed = -20 },
    drift  = { accel = 10,  speed = -5 }
}

-- ==================== AFR SETTINGS ====================
Config.AFROptimal = { min = 13.2, max = 13.8 }  -- Best power band
Config.AFROptimalPeak = 13.5                       -- Peak efficiency
Config.AFRLimits = { min = 11.0, max = 15.0 }    -- Physical limits

-- ==================== ARCHETYPE DEFINITIONS ====================
-- These mirror the normalizer's archetype modifiers
-- Used for NUI display and calculations
Config.Archetypes = {
    esportivo = {
        label = 'Esportivo / Tuner',
        icon = '🏎️',
        description = 'High agility sports cars focused on cornering and handling.',
        statModifiers = {
            top_speed    = 0.85,
            acceleration = 0.90,
            handling     = 1.15,
            braking      = 1.10
        }
    },
    possante = {
        label = 'Possante / Muscle',
        icon = '💪',
        description = 'Raw American muscle with brutal acceleration and torque.',
        statModifiers = {
            top_speed    = 0.95,
            acceleration = 1.20,
            handling     = 0.75,
            braking      = 0.85
        }
    },
    exotico = {
        label = 'Exótico / Luxuoso',
        icon = '✨',
        description = 'Exotic luxury machines built for top speed and presence.',
        statModifiers = {
            top_speed    = 1.20,
            acceleration = 1.00,
            handling     = 1.05,
            braking      = 1.00
        }
    },
    supercarro = {
        label = 'Supercarro / Hipercarro',
        icon = '⚡',
        description = 'Ultimate balanced performance machines with no weaknesses.',
        statModifiers = {
            top_speed    = 1.10,
            acceleration = 1.10,
            handling     = 1.10,
            braking      = 1.10
        }
    },
    moto = {
        label = 'Motos',
        icon = '🏍️',
        description = 'Two-wheeled machines with incredible agility and acceleration.',
        statModifiers = {
            top_speed    = 0.90,
            acceleration = 1.15,
            handling     = 1.25,
            braking      = 1.05
        }
    },
    utilitario = {
        label = 'Utilitários',
        icon = '🚛',
        description = 'Work vehicles with massive cargo capacity and torque.',
        statModifiers = {
            top_speed    = 0.60,
            acceleration = 0.60,
            handling     = 0.65,
            braking      = 0.70
        }
    }
}

-- ==================== SUB-ARCHETYPE DEFINITIONS ====================
-- Stat bonuses applied on top of archetype modifiers
Config.SubArchetypes = {
    drifter = {
        label = 'Drifter',
        icon = '🌪️',
        description = 'Optimized for controlled slides and drift circuits.',
        statBonus = { handling = 5, acceleration = 3 }
    },
    dragster = {
        label = 'Dragster',
        icon = '🚀',
        description = 'Built for straight-line speed and launch control.',
        statBonus = { acceleration = 10, top_speed = 5, handling = -8 }
    },
    late_surger = {
        label = 'Late Surger',
        icon = '🌊',
        description = 'Excels at overtaking in the final moments of a race.',
        statBonus = { top_speed = 8, acceleration = 3, braking = 5 }
    },
    curve_king = {
        label = 'Curve King',
        icon = '👑',
        description = 'Dominates corners with superior grip and turn-in.',
        statBonus = { handling = 10, braking = 5 }
    },
    grip_master = {
        label = 'Grip Master',
        icon = '🧲',
        description = 'Maximum tire grip for precise, planted driving.',
        statBonus = { handling = 5, acceleration = -3 }
    },
    street_racer = {
        label = 'Street Racer',
        icon = '🏙️',
        description = 'Balanced for urban environments and street competition.',
        statBonus = { acceleration = 5, handling = 5, braking = 3 }
    },
    rally_spec = {
        label = 'Rally Spec',
        icon = '🏔️',
        description = 'Modified for mixed surfaces and rally conditions.',
        statBonus = { handling = 5, acceleration = 3, braking = 3 }
    },
    drift_king = {
        label = 'Drift King',
        icon = '🏁',
        description = 'The ultimate drift machine with extreme angle capability.',
        statBonus = { handling = 8, acceleration = 5 }
    },
    time_attack = {
        label = 'Time Attack',
        icon = '⏱️',
        description = 'Optimized for fastest single lap times.',
        statBonus = { handling = 8, braking = 8, top_speed = -3 }
    },
    sleeper = {
        label = 'Sleeper',
        icon = '😴',
        description = 'Looks stock but hides serious performance upgrades.',
        statBonus = { acceleration = 8, top_speed = 5, handling = -3 }
    }
}
