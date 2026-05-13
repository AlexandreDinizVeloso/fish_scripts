-- fish_tunes: Tire System Module
-- Manages tire types, conditions, and individual wheel tracking

TireSystem = {}
local Config = {}

-- Tire types with different characteristics
TireSystem.TireTypes = {
    street = {
        label = 'Street Tires',
        icon = '🛣️',
        grip = 0.85,
        durability = 0.95,
        cost = 100,
        wear_rate = 1.0,
        wet_grip = 0.70,
        heat_resistance = 0.80
    },
    sport = {
        label = 'Sport Tires',
        icon = '⚡',
        grip = 0.95,
        durability = 0.85,
        cost = 200,
        wear_rate = 1.3,
        wet_grip = 0.80,
        heat_resistance = 0.85
    },
    racing = {
        label = 'Racing Slicks',
        icon = '🏁',
        grip = 1.10,
        durability = 0.70,
        cost = 500,
        wear_rate = 1.8,
        wet_grip = 0.40,
        heat_resistance = 0.90
    },
    drift = {
        label = 'Drift Tires',
        icon = '🌪️',
        grip = 0.88,
        durability = 0.92,
        cost = 250,
        wear_rate = 2.5,
        wet_grip = 0.75,
        heat_resistance = 0.75
    },
    offroad = {
        label = 'Off-Road Tires',
        icon = '🏔️',
        grip = 0.92,
        durability = 0.98,
        cost = 300,
        wear_rate = 1.1,
        wet_grip = 0.85,
        heat_resistance = 0.88
    },
    all_season = {
        label = 'All-Season',
        icon = '🌍',
        grip = 0.80,
        durability = 1.0,
        cost = 120,
        wear_rate = 0.9,
        wet_grip = 0.78,
        heat_resistance = 0.82
    }
}

-- Initialize tire system
function TireSystem.Init(config)
    Config = config
end

-- Initialize vehicle tires
function TireSystem.InitializeVehicleTires(vehicleData, tireType)
    tireType = tireType or 'street'
    
    vehicleData.tires = {
        type = tireType,
        wheel_fl = 100,  -- Front left
        wheel_fr = 100,  -- Front right
        wheel_rl = 100,  -- Rear left
        wheel_rr = 100   -- Rear right
    }
    
    return vehicleData.tires
end

-- Get tire info
function TireSystem.GetTireInfo(tireType)
    return TireSystem.TireTypes[tireType] or TireSystem.TireTypes.street
end

-- Apply wear to tire
function TireSystem.ApplyTireWear(vehicleData, wheel, wearAmount)
    if not vehicleData.tires then
        return 0
    end
    
    local wheelKey = wheel or 'wheel_fl'
    if vehicleData.tires[wheelKey] then
        vehicleData.tires[wheelKey] = math.max(0, vehicleData.tires[wheelKey] - wearAmount)
        return vehicleData.tires[wheelKey]
    end
    
    return 0
end

-- Apply wear to all tires (simulates uniform wear)
function TireSystem.ApplyUniformWear(vehicleData, wearAmount)
    if not vehicleData.tires then
        return {}
    end
    
    local tireInfo = TireSystem.GetTireInfo(vehicleData.tires.type)
    local adjustedWear = wearAmount * tireInfo.wear_rate
    
    vehicleData.tires.wheel_fl = math.max(0, vehicleData.tires.wheel_fl - adjustedWear)
    vehicleData.tires.wheel_fr = math.max(0, vehicleData.tires.wheel_fr - adjustedWear)
    vehicleData.tires.wheel_rl = math.max(0, vehicleData.tires.wheel_rl - adjustedWear)
    vehicleData.tires.wheel_rr = math.max(0, vehicleData.tires.wheel_rr - adjustedWear)
    
    return vehicleData.tires
end

-- Get average tire condition
function TireSystem.GetAverageTireCondition(vehicleData)
    if not vehicleData.tires then return 100 end
    
    local total = vehicleData.tires.wheel_fl + vehicleData.tires.wheel_fr + 
                  vehicleData.tires.wheel_rl + vehicleData.tires.wheel_rr
    
    return math.floor(total / 4)
end

-- Get tire status
function TireSystem.GetTireStatus(tireHealth)
    if tireHealth >= 80 then
        return { status = 'Excellent', icon = '✅', color = '#66BB6A' }
    elseif tireHealth >= 60 then
        return { status = 'Good', icon = '👍', color = '#4FC3F7' }
    elseif tireHealth >= 40 then
        return { status = 'Fair', icon = '⚠️', color = '#FFD54F' }
    elseif tireHealth >= 20 then
        return { status = 'Poor', icon = '🔧', color = '#FF8800' }
    else
        return { status = 'Critical', icon = '❌', color = '#FF1744' }
    end
end

-- Get detailed tire information per wheel
function TireSystem.GetDetailedTireInfo(vehicleData)
    if not vehicleData.tires then return nil end
    
    local tireInfo = TireSystem.GetTireInfo(vehicleData.tires.type)
    
    return {
        type = vehicleData.tires.type,
        tire_info = tireInfo,
        wheels = {
            fl = {
                name = 'Front Left',
                health = vehicleData.tires.wheel_fl,
                status = TireSystem.GetTireStatus(vehicleData.tires.wheel_fl)
            },
            fr = {
                name = 'Front Right',
                health = vehicleData.tires.wheel_fr,
                status = TireSystem.GetTireStatus(vehicleData.tires.wheel_fr)
            },
            rl = {
                name = 'Rear Left',
                health = vehicleData.tires.wheel_rl,
                status = TireSystem.GetTireStatus(vehicleData.tires.wheel_rl)
            },
            rr = {
                name = 'Rear Right',
                health = vehicleData.tires.wheel_rr,
                status = TireSystem.GetTireStatus(vehicleData.tires.wheel_rr)
            }
        },
        average_health = TireSystem.GetAverageTireCondition(vehicleData),
        needs_replacement = TireSystem.NeedsTireReplacement(vehicleData)
    }
end

-- Check if tires need replacement
function TireSystem.NeedsTireReplacement(vehicleData)
    if not vehicleData.tires then return false end
    
    if vehicleData.tires.wheel_fl < 20 or vehicleData.tires.wheel_fr < 20 or
       vehicleData.tires.wheel_rl < 20 or vehicleData.tires.wheel_rr < 20 then
        return true
    end
    
    return false
end

-- Replace all tires
function TireSystem.ReplaceAllTires(vehicleData)
    if not vehicleData.tires then return false end
    
    vehicleData.tires.wheel_fl = 100
    vehicleData.tires.wheel_fr = 100
    vehicleData.tires.wheel_rl = 100
    vehicleData.tires.wheel_rr = 100
    
    return true
end

-- Replace specific wheel tire
function TireSystem.ReplaceWheelTire(vehicleData, wheel)
    if not vehicleData.tires then return false end
    
    local wheelKey = wheel or 'wheel_fl'
    if vehicleData.tires[wheelKey] then
        vehicleData.tires[wheelKey] = 100
        return true
    end
    
    return false
end

-- Change tire type
function TireSystem.ChangeTireType(vehicleData, newTireType)
    if not TireSystem.TireTypes[newTireType] then
        return false
    end
    
    if not vehicleData.tires then
        TireSystem.InitializeVehicleTires(vehicleData, newTireType)
    else
        vehicleData.tires.type = newTireType
    end
    
    return true
end

-- Calculate grip coefficient based on tire health and type
function TireSystem.GetGripCoefficient(vehicleData)
    if not vehicleData.tires then return 1.0 end
    
    local tireInfo = TireSystem.GetTireInfo(vehicleData.tires.type)
    local avgHealth = TireSystem.GetAverageTireCondition(vehicleData)
    local healthMultiplier = avgHealth / 100
    
    return tireInfo.grip * healthMultiplier
end

-- Calculate braking performance based on tires
function TireSystem.GetBrakingMultiplier(vehicleData)
    if not vehicleData.tires then return 1.0 end
    
    local avgHealth = TireSystem.GetAverageTireCondition(vehicleData)
    return (avgHealth / 100) * 0.9 + 0.1  -- Min 0.1, Max 1.0
end

-- Calculate acceleration traction based on tires
function TireSystem.GetTractionMultiplier(vehicleData)
    if not vehicleData.tires then return 1.0 end
    
    local avgHealth = TireSystem.GetAverageTireCondition(vehicleData)
    return (avgHealth / 100) * 0.85 + 0.15  -- Min 0.15, Max 1.0
end

return TireSystem
