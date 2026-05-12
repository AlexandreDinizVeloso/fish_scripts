Config = {}

Config.DNAInheritance = 0.75 -- 75% new archetype, 25% original
Config.SubArchInheritance = 1.0 -- 100% for sub-archetype changes

Config.MaxStatAdjustment = 15 -- max +/- percentage per stat
Config.AdjustmentCost = 1000 -- base cost per adjustment point

Config.Stats = {
    'top_speed',
    'acceleration',
    'handling',
    'braking'
}

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
