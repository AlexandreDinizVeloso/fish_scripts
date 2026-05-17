Config = {}

Config.Ranks = {
    {name = 'C', min = 0,   max = 499,  color = '#8B8B8B', label = 'Class C', hidden = false},
    {name = 'B', min = 500, max = 749,  color = '#4FC3F7', label = 'Class B', hidden = false},
    {name = 'A', min = 750, max = 899,  color = '#66BB6A', label = 'Class A', hidden = false},
    {name = 'S', min = 900, max = 999,  color = '#FFD54F', label = 'Class S', hidden = false},
    {name = 'X', min = 1000, max = 1000, color = '#FF1744', label = 'Class X', hidden = true}
}

Config.Weights = {
    top_speed    = 0.30,
    acceleration = 0.30,
    handling     = 0.25,
    braking      = 0.15
}

Config.Archetypes = {
    esportivo = {
        label = 'Esportivo / Tuner',
        icon = '🏎️',
        description = 'High agility sports cars focused on cornering and handling.',
        pros = {
            'High handling & cornering',
            'Stable G-force in turns',
            'Moderate acceleration',
            'Lightweight chassis'
        },
        cons = {
            'Limited top speed',
            'Too light for impacts',
            'Poor at bumping/ramming'
        },
        statModifiers = {
            top_speed    = 0.85,
            acceleration = 0.90,
            handling     = 1.15,
            braking      = 1.10,
            traction     = 1.15
        },
        scoreBias = {
            top_speed    = -10,
            acceleration = 0,
            handling     = 15,
            braking      = 10
        }
    },
    possante = {
        label = 'Possante / Muscle',
        icon = '💪',
        description = 'Raw American muscle with brutal acceleration and torque.',
        pros = {
            'Extreme acceleration',
            'High low/high RPM power',
            'Instant torque delivery',
            'Can beat some S-class in straights',
            'Great at bumping/ramming'
        },
        cons = {
            'Poor handling',
            'Bad cornering ability',
            'Heavy chassis'
        },
        statModifiers = {
            top_speed    = 1.00,
            acceleration = 1.25,
            handling     = 0.70,
            braking      = 0.80,
            traction     = 0.75
        },
        scoreBias = {
            top_speed    = 0,
            acceleration = 25,
            handling     = -15,
            braking      = -5
        }
    },
    exotico = {
        label = 'Exótico / Luxuoso',
        icon = '✨',
        description = 'Exotic luxury machines built for top speed and presence.',
        pros = {
            'Highest top speed potential',
            'Great for long straights',
            'Stable acceleration curve',
            'Excellent handling feel'
        },
        cons = {
            'Can be unstable',
            'Performance varies wildly between models',
            'Expensive to maintain'
        },
        statModifiers = {
            top_speed    = 1.25,
            acceleration = 0.95,
            handling     = 1.00,
            braking      = 0.95,
            traction     = 0.95
        },
        scoreBias = {
            top_speed    = 25,
            acceleration = 0,
            handling     = 5,
            braking      = 0
        }
    },
    supercarro = {
        label = 'Supercarro / Hipercarro',
        icon = '⚡',
        description = 'Ultimate balanced performance machines with no weaknesses.',
        pros = {
            'Balanced in all aspects',
            'No major weaknesses',
            'Consistent performance',
            'Top-tier engineering'
        },
        cons = {
            'Extremely expensive',
            'Considered "car for weak people"',
            'No standout personality'
        },
        statModifiers = {
            top_speed    = 1.15,
            acceleration = 1.15,
            handling     = 1.15,
            braking      = 1.15,
            traction     = 1.15
        },
        scoreBias = {
            top_speed    = 15,
            acceleration = 15,
            handling     = 15,
            braking      = 15
        }
    },
    moto = {
        label = 'Motos',
        icon = '🏍️',
        description = 'Two-wheeled machines with incredible agility and acceleration.',
        pros = {
            'Extremely lightweight',
            'Fits in tight alleys',
            'High acceleration',
            'Maximum maneuverability'
        },
        cons = {
            'Can fall in collisions',
            'Fragile bodywork',
            'Limited cargo',
            'Exposed to elements'
        },
        statModifiers = {
            top_speed    = 0.90,
            acceleration = 1.25,
            handling     = 1.30,
            braking      = 1.05,
            traction     = 1.15
        },
        scoreBias = {
            top_speed    = -5,
            acceleration = 20,
            handling     = 25,
            braking      = 5
        }
    },
    utilitario = {
        label = 'Utilitários',
        icon = '🚛',
        description = 'Work vehicles with massive cargo capacity and torque.',
        pros = {
            'Can carry many items',
            'High torque for elevations',
            'Durable construction',
            'Versatile utility'
        },
        cons = {
            'Very slow acceleration',
            'Extremely heavy',
            'Poor handling',
            'Low top speed'
        },
        statModifiers = {
            top_speed    = 0.60,
            acceleration = 0.60,
            handling     = 0.65,
            braking      = 0.70,
            traction     = 0.75
        },
        scoreBias = {
            top_speed    = -20,
            acceleration = -20,
            handling     = -15,
            braking      = -10
        }
    },
    especial = {
        label = 'Especiais',
        icon = '🚁',
        description = 'Special vehicles including helicopters, planes, and unique machines.',
        pros = {
            'Unique capabilities',
            'Aerial/special movement',
            'Cannot be compared normally'
        },
        cons = {
            'Cannot use normal roads',
            'Specialized use only',
            'Requires special skills'
        },
        statModifiers = {
            top_speed    = 1.00,
            acceleration = 1.00,
            handling     = 1.00,
            braking      = 1.00,
            traction     = 1.00
        },
        scoreBias = {
            top_speed    = 0,
            acceleration = 0,
            handling     = 0,
            braking      = 0
        }
    }
}

Config.SubArchetypes = {
    drifter = {
        label = 'Drifter',
        icon = '🌪️',
        description = 'Optimized for controlled slides and drift circuits.',
        statBonus = {handling = 5, traction = -10, acceleration = 3}
    },
    dragster = {
        label = 'Dragster',
        icon = '🚀',
        description = 'Built for straight-line speed and launch control.',
        statBonus = {acceleration = 10, top_speed = 5, handling = -8}
    },
    late_surger = {
        label = 'Late Surger',
        icon = '🌊',
        description = 'Excels at overtaking in the final moments of a race.',
        statBonus = {top_speed = 8, acceleration = 3, braking = 5}
    },
    curve_king = {
        label = 'Curve King',
        icon = '👑',
        description = 'Dominates corners with superior grip and turn-in.',
        statBonus = {handling = 10, braking = 5, traction = 8}
    },
    grip_master = {
        label = 'Grip Master',
        icon = '🧲',
        description = 'Maximum tire grip for precise, planted driving.',
        statBonus = {traction = 12, handling = 5, acceleration = -3}
    },
    street_racer = {
        label = 'Street Racer',
        icon = '🏙️',
        description = 'Balanced for urban environments and street competition.',
        statBonus = {acceleration = 5, handling = 5, braking = 3}
    },
    rally_spec = {
        label = 'Rally Spec',
        icon = '🏔️',
        description = 'Modified for mixed surfaces and rally conditions.',
        statBonus = {handling = 5, traction = 5, acceleration = 3, braking = 3}
    },
    drift_king = {
        label = 'Drift King',
        icon = '🏁',
        description = 'The ultimate drift machine with extreme angle capability.',
        statBonus = {handling = 8, traction = -15, acceleration = 5}
    },
    time_attack = {
        label = 'Time Attack',
        icon = '⏱️',
        description = 'Optimized for fastest single lap times.',
        statBonus = {handling = 8, braking = 8, traction = 5, top_speed = -3}
    },
    sleeper = {
        label = 'Sleeper',
        icon = '😴',
        description = 'Looks stock but hides serious performance upgrades.',
        statBonus = {acceleration = 8, top_speed = 5, handling = -3}
    }
}

Config.VehicleClassMap = {
    [0]  = 'utilitario',  -- Compacts
    [1]  = 'utilitario',  -- Sedans
    [2]  = 'utilitario',  -- SUVs
    [3]  = 'esportivo',   -- Coupes
    [4]  = 'possante',    -- Muscle
    [5]  = 'esportivo',   -- Sports Classics
    [6]  = 'esportivo',   -- Sports
    [7]  = 'supercarro',  -- Super
    [8]  = 'moto',        -- Motorcycles
    [9]  = 'utilitario',  -- Off-road
    [10] = 'utilitario',  -- Industrial
    [11] = 'utilitario',  -- Utility
    [12] = 'utilitario',  -- Vans
    [13] = 'especial',    -- Cycles
    [14] = 'especial',    -- Boats
    [15] = 'especial',    -- Helicopters
    [16] = 'especial',    -- Planes
    [17] = 'utilitario',  -- Service
    [18] = 'especial',    -- Emergency
    [19] = 'especial',    -- Military
    [20] = 'utilitario',  -- Commercial
    [21] = 'especial'     -- Trains
}

Config.MaxScore = 1000
Config.ScoreRanges = {
    min = 0,
    max = 1000
}

-- ============================================================
-- Vehicle Maintenance & Degradation System
-- ============================================================

Config.MaintenanceSystem = {
    enabled = true,
    -- Mileage is tracked in kilometers
    mileageUpdateInterval = 5000, -- Update every 5km
}

-- Initial health values when vehicle is first tracked
Config.InitialHealth = {
    engine = 100,
    transmission = 100,
    suspension = 100,
    brakes = 100,
    tires = 100,
    turbo = 100
}

-- Parts that can degrade
Config.VehicleParts = {
    'engine',
    'transmission',
    'suspension',
    'brakes',
    'tires',
    'turbo'
}

-- Tire condition tracking (4 wheels)
Config.TireTracking = {
    wheel_fl = { label = 'Front Left', position = 0 },
    wheel_fr = { label = 'Front Right', position = 1 },
    wheel_rl = { label = 'Rear Left', position = 2 },
    wheel_rr = { label = 'Rear Right', position = 3 }
}

-- Default vehicle data structure
Config.DefaultVehicleData = {
    plate = '',
    owner = '',
    archetype = 'esportivo',
    rank = 'C',
    score = 0,
    -- Maintenance fields
    mileage = 0, -- kilometers
    engine_health = 100,
    transmission_health = 100,
    suspension_health = 100,
    brakes_health = 100,
    tires_health = 100, -- average of 4 wheels
    turbo_health = 100,
    -- Tuning fields
    tuning_efficiency = 100, -- AFR status (0-150, 100 is optimal)
    drivetrain_type = 'FWD', -- FWD, RWD, AWD
    transmission_mode = 'auto', -- manual, auto, eco
    current_gear_ratio = 1.0,
    -- Timestamps
    created = 0,
    lastUpdated = 0,
    lastMaintained = 0,
    -- Statistics
    total_driven_distance = 0,
    harsh_acceleration_events = 0,
    overspeed_events = 0,
    rough_handling_events = 0
}
