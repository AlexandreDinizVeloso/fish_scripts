# Fish Scripts - Phase 1 Implementation Guide

## Overview

Phase 1 of the enhancement plan has been successfully implemented with the following new systems:

1. **Enhanced Vehicle Data Structure** - Extended fish_normalizer
2. **Degradation System** - Tracks part health and wear
3. **Mileage Tracking** - Monitors vehicle usage
4. **Tire System** - Individual wheel tracking and tire types
5. **Transmission System** - Manual/Automatic and gear ratios

---

## 1. Enhanced Vehicle Data Structure

### New Fields in fish_normalizer

Every vehicle now tracks:

```lua
-- Maintenance System
mileage                   -- Total kilometers driven
engine_health             -- 0-100 (% condition)
transmission_health       -- 0-100
suspension_health         -- 0-100
brakes_health             -- 0-100
tires_health              -- 0-100 (average of 4 wheels)
turbo_health              -- 0-100

-- Tuning Information
tuning_efficiency         -- AFR status (0-150, 100 optimal)
drivetrain_type           -- 'FWD', 'RWD', 'AWD'
transmission_mode         -- 'manual', 'auto', 'eco'
current_gear_ratio        -- Transmission ratio multiplier

-- Statistics Tracking
total_driven_distance     -- Lifetime kilometers
harsh_acceleration_events -- Counter
overspeed_events          -- Counter
rough_handling_events     -- Counter
lastMaintained            -- Unix timestamp
```

### Accessing Vehicle Data

```lua
local normalizer = exports['fish_normalizer']
local vehicleData = normalizer:GetVehicleDataServer(plate)

-- Check health
if vehicleData.engine_health < 50 then
    print("Engine needs maintenance!")
end

-- Get mileage
local mileage = vehicleData.mileage
print("Vehicle has " .. mileage .. " km")
```

---

## 2. Degradation System

### How Degradation Works

- **Event-Based**: Harsh driving triggers degradation
- **Mileage-Based**: Automatic degradation at distance milestones
- **AFR-Sensitive**: Poor tuning increases wear rates
- **Part-Specific**: Each part has unique wear rates

### Degradation Events

```lua
local fish_tunes = exports['fish_tunes']

-- Harsh acceleration (0-100 intensity)
fish_tunes:ApplyDegradation(plate, vehicleData, 'harsh_acceleration', 2.0)

-- High speed driving
fish_tunes:ApplyDegradation(plate, vehicleData, 'overspeed', 1.5)

-- Harsh braking
fish_tunes:ApplyDegradation(plate, vehicleData, 'harsh_braking', 1.8)

-- Rough handling (drifting, tight turns)
fish_tunes:ApplyDegradation(plate, vehicleData, 'rough_handling', 2.2)

-- Mileage-based (automatic)
-- Triggered at thresholds: 1000, 5000, 10000, 25000, 50000 km
```

### Health Status Thresholds

```
Excellent: 90-100 ✅ (Green)
Good:      75-89  👍 (Blue)
Fair:      50-74  ⚠️  (Yellow)
Poor:      25-49  🔧 (Orange)
Critical:  0-24   ❌ (Red)
```

### Getting Vehicle Health

```lua
local fish_tunes = exports['fish_tunes']
local health = fish_tunes:GetVehicleHealthSummary(plate)

print("Engine: " .. health.engine.health .. "% - " .. health.engine.status.label)
print("Brakes: " .. health.brakes.health .. "%")
print("Overall: " .. health.overall.health .. "%")
print("Mileage: " .. fish_tunes:MileageTracker.GetTotalMileage(plate) .. " km")
```

### Repairing Vehicles

```lua
-- Repair specific part (add health points)
fish_tunes:RepairVehicle(plate, 'engine', 25)  -- Add 25% health
fish_tunes:RepairVehicle(plate, 'brakes', 50)  -- Full repair

-- Parts available: engine, transmission, suspension, brakes, tires, turbo
```

---

## 3. Mileage Tracking

### Configuration

In config.lua:
```lua
Config.MaintenanceSystem = {
    enabled = true,
    mileageUpdateInterval = 5000, -- Update every 5km
}

Config.MileageThresholds = {
    {distance = 1000, degradation = 1},    -- Service at 1000km
    {distance = 5000, degradation = 3},
    {distance = 10000, degradation = 5},
    {distance = 25000, degradation = 10},
    {distance = 50000, degradation = 15},
}
```

### Tracking Active Vehicles

```lua
local MileageTracker = require('server.mileage')

-- Register vehicle when player enters
MileageTracker.RegisterVehicle(src, vehicleNetId, plate)

-- Update mileage while driving (call periodically)
local distance = MileageTracker.UpdateMileage(src, vehicleNetId, playerPos)

-- Unregister when player leaves vehicle
MileageTracker.UnregisterVehicle(src, vehicleNetId)

-- Get total lifetime mileage
local totalMileage = MileageTracker.GetTotalMileage(plate)
local formatted = MileageTracker.FormatMileage(totalMileage)  -- "1.5k km"
```

### Maintenance Milestones

```lua
local nextMaintenance = MileageTracker.GetNextMaintenanceMileage(currentMileage)
local progress = MileageTracker.GetMileageToNextMilestone(currentMileage)

print("Current: " .. progress.current .. " km")
print("Next: " .. progress.next .. " km")
print("Progress: " .. progress.progress .. "%")
print("Remaining: " .. progress.remaining .. " km")
```

---

## 4. Tire System

### Tire Types

```lua
street   -- 🛣️  Basic grip, high durability
sport    -- ⚡ High grip, medium wear
racing   -- 🏁 Maximum grip, fast wear
drift    -- 🌪️ Balanced, very fast wear
offroad  -- 🏔️ Good grip on rough terrain
all_season -- 🌍 Moderate grip, slow wear
```

### Tire Management

```lua
local TireSystem = require('server.tires')

-- Initialize tires for vehicle
TireSystem.InitializeVehicleTires(vehicleData, 'sport')

-- Change tire type
TireSystem.ChangeTireType(vehicleData, 'racing')

-- Apply wear to tire
TireSystem.ApplyTireWear(vehicleData, 'wheel_fl', 5)  -- 5% wear to front-left

-- Apply uniform wear (all wheels)
TireSystem.ApplyUniformWear(vehicleData, 10)  -- 10% wear to all

-- Check tire condition
local avgCondition = TireSystem.GetAverageTireCondition(vehicleData)
if TireSystem.NeedsTireReplacement(vehicleData) then
    print("Tires need replacement!")
end

-- Replace tires
TireSystem.ReplaceAllTires(vehicleData)  -- 100% condition all wheels
TireSystem.ReplaceWheelTire(vehicleData, 'wheel_fr')  -- One wheel

-- Get detailed info
local tireInfo = TireSystem.GetDetailedTireInfo(vehicleData)
print(tireInfo.type .. ": " .. tireInfo.average_health .. "%")

-- Performance multipliers
local grip = TireSystem.GetGripCoefficient(vehicleData)
local braking = TireSystem.GetBrakingMultiplier(vehicleData)
local traction = TireSystem.GetTractionMultiplier(vehicleData)
```

### Wheel Positions

```
wheel_fl = Front Left
wheel_fr = Front Right
wheel_rl = Rear Left
wheel_rr = Rear Right
```

### Tire Characteristics

Each tire type has:
- `grip` - Cornering coefficient (0.8-1.1)
- `durability` - Base wear rate (0.7-1.0)
- `wear_rate` - Multiplier for wear events
- `wet_grip` - Wet weather performance
- `heat_resistance` - How well it handles heat

---

## 5. Transmission System

### Transmission Modes

```lua
auto        -- Standard automatic shifting
auto_eco    -- Fuel-efficient automatic (13% better fuel economy)
auto_sport  -- Aggressive shifting
manual      -- Player controlled gears
```

### Gear Ratio Presets

```lua
stock       -- Default balanced ratios
short       -- Quick acceleration, lower top speed
long        -- Higher top speed, slower acceleration
drag        -- 4-gear optimized for straight-line speed
drift       -- Balanced for drift control
custom      -- User-defined ratios
```

### Transmission Control

```lua
local TransmissionSystem = require('server.transmission')

-- Initialize transmission
TransmissionSystem.InitializeTransmission(vehicleData, 'auto', 'stock')

-- Change mode
TransmissionSystem.SetTransmissionMode(vehicleData, 'manual')

-- Set gear ratio preset
TransmissionSystem.SetGearRatioPreset(vehicleData, 'short')

-- Custom gear ratios
local customRatios = {3.80, 2.30, 1.60, 1.15, 0.90, 0.70}
local finalDrive = 3.85
TransmissionSystem.SetCustomRatios(vehicleData, customRatios, finalDrive)

-- Manual gear shifting
TransmissionSystem.ShiftGear(vehicleData, 3)  -- Shift to 3rd gear

-- Get next gear recommendation (for automatic)
local nextGear = TransmissionSystem.GetNextGearAuto(currentRPM, maxRPM, currentGear, vehicleData)

-- Get performance info
local efficiency = TransmissionSystem.GetTransmissionEfficiency(vehicleData)  -- 0.88-1.0
local fuelMod = TransmissionSystem.GetFuelEfficiencyModifier(vehicleData)     -- 1.0-1.3

-- Calculate RPM/Speed
local rpm = TransmissionSystem.CalculateRPM(speed, gear, vehicleData)
local speed = TransmissionSystem.CalculateSpeed(rpm, gear, vehicleData)

-- Get detailed info
local transInfo = TransmissionSystem.GetDetailedTransmissionInfo(vehicleData)
```

### Default Gear Ratios

**Stock (6-speed)**
```
1st: 3.50
2nd: 2.10
3rd: 1.43
4th: 1.00
5th: 0.80
6th: 0.62
Final Drive: 3.55
```

**Short (6-speed - Acceleration)**
```
1st: 3.80
2nd: 2.30
3rd: 1.60
4th: 1.15
5th: 0.90
6th: 0.70
Final Drive: 3.85
```

---

## Configuration Reference

### Degradation Rates (Config)

```lua
Config.DegradationRates = {
    engine = {
        base_rate = 0.5,
        harsh_acceleration_multiplier = 2.0,
        overspeed_multiplier = 1.5,
        poor_tuning_multiplier = 3.0,
        turbo_wear_multiplier = 2.5
    },
    -- Similar structure for: transmission, suspension, brakes, tires, turbo
}
```

### AFR (Air-Fuel Ratio) Tuning

```lua
Config.AFRTuning = {
    optimal_range_min = 13.2,  -- Minimum optimal AFR
    optimal_range_max = 13.8,  -- Maximum optimal AFR
    optimal_peak = 13.5,       -- Perfect AFR value
    lean_threshold = 12.0,     -- Engine damage if too lean
    rich_threshold = 14.5,     -- Power loss if too rich
}
```

### Health Performance Impact

Poor part health reduces performance:
- Engine at 50% health: 94% power output
- Engine at 25% health: 88% power output
- Engine at 0% health: 75% power output (critical)

---

## Integration Examples

### Example 1: Monitor Harsh Driving

```lua
-- In your vehicle/player script
local lastAccel = 0
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        
        if IsPedInAnyVehicle(PlayerPedId()) then
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            local accel = GetVehicleAcceleration(veh)
            
            -- Detect harsh acceleration
            if accel > 0.8 then
                TriggerServerEvent('fish_tunes:harshAcceleration', GetVehicleNumberPlateText(veh))
            end
            
            -- Detect speeding
            local speed = GetEntitySpeed(veh)
            if speed > 50 then  -- m/s = ~180 km/h
                TriggerServerEvent('fish_tunes:overspeed', GetVehicleNumberPlateText(veh))
            end
        end
    end
end)
```

### Example 2: Display Health Dashboard

```lua
-- Server side
RegisterCommand('vehiclehealth', function(source, args, rawCommand)
    local plate = args[1]
    if not plate then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"ERROR", "Usage: /vehiclehealth PLATE"}
        })
        return
    end
    
    local health = exports['fish_tunes']:GetVehicleHealthSummary(plate)
    if not health then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"ERROR", "Vehicle not found"}
        })
        return
    end
    
    local msg = string.format(
        "^2Vehicle Health Report for %s^7\n" ..
        "Engine: %d%% %s\n" ..
        "Transmission: %d%% %s\n" ..
        "Brakes: %d%% %s\n" ..
        "Tires: %d%% %s\n" ..
        "Overall: %d%% | Mileage: %d km",
        plate,
        health.engine.health, health.engine.status.label,
        health.transmission.health, health.transmission.status.label,
        health.brakes.health, health.brakes.status.label,
        health.tires.health, health.tires.status.label,
        health.overall.health, health.overall.mileage
    )
    
    TriggerClientEvent('chat:addMessage', source, {
        args = {"HEALTH", msg}
    })
end)
```

### Example 3: Repair Service

```lua
RegisterCommand('repairvehicle', function(source, args, rawCommand)
    local parts = {'engine', 'transmission', 'brakes', 'tires', 'suspension', 'turbo'}
    local plate = args[1]
    
    if not plate then return end
    
    local fish_tunes = exports['fish_tunes']
    
    for _, part in ipairs(parts) do
        fish_tunes:RepairVehicle(plate, part, 100)  -- Full repair
    end
    
    TriggerClientEvent('chat:addMessage', source, {
        args = {"REPAIR", "Vehicle fully repaired!"}
    })
end)
```

---

## Next Steps (Phase 2)

The following systems are ready for Phase 2 implementation:

1. **Dyno Tuning System** - Advanced tuning with AFR mechanics
2. **Advanced Tire Features** - Wet/dry grip, temperature modeling
3. **Drivetrain Modification** - AWD/FWD/RWD conversions
4. **Engine Swap System** - Different engine options
5. **Crafting System** - Part crafting and customization

---

## Support & Troubleshooting

### Common Issues

**Q: Vehicle data not saving**
- Ensure fish_normalizer is running first
- Check JSON file permissions

**Q: Degradation not applying**
- Verify `Config.Degradation.enabled = true`
- Check AFR values are being updated

**Q: Mileage not tracking**
- Make sure to call `RegisterVehicle()` on entry
- Call `UnregisterVehicle()` on exit

**Q: Tires showing 0 health**
- Call `TireSystem.InitializeVehicleTires()` on first use
- Tire health should default to 100

---

## File Structure

```
fish_tunes/
├── config.lua                 -- Configuration (updated)
├── server/
│   ├── main.lua               -- Core (updated with modules)
│   ├── data.lua               -- Data management
│   ├── degradation.lua        -- NEW: Degradation system
│   ├── mileage.lua            -- NEW: Mileage tracking
│   ├── tires.lua              -- NEW: Tire system
│   └── transmission.lua       -- NEW: Transmission system
└── ...

fish_normalizer/
├── config.lua                 -- Configuration (updated with maintenance)
├── server/
│   ├── main.lua               -- Core
│   └── data.lua               -- Data management (updated)
└── ...
```

---

**Implementation Date**: May 13, 2026
**Status**: ✅ Phase 1 Complete
