-- fish_tunes: Transmission System Module
-- Manages manual/automatic transmissions and gear ratios

TransmissionSystem = {}
local Config = {}

-- Transmission modes
TransmissionSystem.Modes = {
    auto = {
        label = 'Automatic',
        icon = 'A',
        description = 'Automatic gear shifting',
        shifts_per_second = 0.5,
        efficiency = 0.92
    },
    auto_eco = {
        label = 'Automatic - Eco',
        icon = 'E',
        description = 'Fuel-efficient automatic',
        shifts_per_second = 0.3,
        efficiency = 0.88,
        fuel_efficiency = 1.3
    },
    auto_sport = {
        label = 'Automatic - Sport',
        icon = 'S',
        description = 'Aggressive automatic shifting',
        shifts_per_second = 0.8,
        efficiency = 0.95
    },
    manual = {
        label = 'Manual',
        icon = 'M',
        description = 'Manual gear control',
        shifts_per_second = 1.2,
        efficiency = 1.0
    }
}

-- Default gear ratios for different transmission types
TransmissionSystem.GearRatios = {
    stock = {
        gearCount = 6,
        ratios = {3.50, 2.10, 1.43, 1.00, 0.80, 0.62},
        finalDrive = 3.55
    },
    short = {
        gearCount = 6,
        ratios = {3.80, 2.30, 1.60, 1.15, 0.90, 0.70},
        finalDrive = 3.85,
        description = 'Quick acceleration, lower top speed'
    },
    long = {
        gearCount = 6,
        ratios = {3.20, 1.90, 1.30, 0.92, 0.74, 0.56},
        finalDrive = 3.25,
        description = 'Higher top speed, slower acceleration'
    },
    drag = {
        gearCount = 4,
        ratios = {4.00, 2.60, 1.80, 1.20},
        finalDrive = 4.10,
        description = 'Optimized for straight-line acceleration'
    },
    drift = {
        gearCount = 6,
        ratios = {3.60, 2.15, 1.50, 1.05, 0.85, 0.65},
        finalDrive = 3.60,
        description = 'Balanced for drift control'
    }
}

-- Initialize transmission system
function TransmissionSystem.Init(config)
    Config = config
end

-- Initialize vehicle transmission
function TransmissionSystem.InitializeTransmission(vehicleData, mode, ratioPreset)
    mode = mode or 'auto'
    ratioPreset = ratioPreset or 'stock'
    
    vehicleData.transmission = {
        mode = mode,
        current_gear = 0,
        gear_shift_time = 0,
        ratio_preset = ratioPreset,
        custom_ratios = nil,
        final_drive = TransmissionSystem.GearRatios[ratioPreset].finalDrive
    }
    
    return vehicleData.transmission
end

-- Get transmission info
function TransmissionSystem.GetTransmissionInfo(mode)
    return TransmissionSystem.Modes[mode] or TransmissionSystem.Modes.auto
end

-- Get gear ratio preset
function TransmissionSystem.GetGearRatioPreset(presetName)
    return TransmissionSystem.GearRatios[presetName] or TransmissionSystem.GearRatios.stock
end

-- Calculate RPM for given speed and gear
function TransmissionSystem.CalculateRPM(speed, gear, vehicleData)
    if not vehicleData.transmission then return 0 end
    
    local ratios = TransmissionSystem.GearRatios[vehicleData.transmission.ratio_preset].ratios
    local finalDrive = vehicleData.transmission.final_drive
    
    if gear > #ratios or gear < 1 then return 0 end
    
    -- RPM = (Speed * Gear Ratio * Final Drive * 60) / Tire Circumference
    -- Simplified calculation
    local rpm = (speed * ratios[gear] * finalDrive * 100) / 7
    
    return math.floor(rpm)
end

-- Calculate speed for given RPM and gear
function TransmissionSystem.CalculateSpeed(rpm, gear, vehicleData)
    if not vehicleData.transmission then return 0 end
    
    local ratios = TransmissionSystem.GearRatios[vehicleData.transmission.ratio_preset].ratios
    local finalDrive = vehicleData.transmission.final_drive
    
    if gear > #ratios or gear < 1 then return 0 end
    
    -- Speed = (RPM * Tire Circumference) / (Gear Ratio * Final Drive * 60)
    -- Simplified calculation
    local speed = (rpm * 7) / (ratios[gear] * finalDrive * 100)
    
    return math.floor(speed)
end

-- Shift gear
function TransmissionSystem.ShiftGear(vehicleData, newGear)
    if not vehicleData.transmission then return false end
    
    local ratios = TransmissionSystem.GearRatios[vehicleData.transmission.ratio_preset].ratios
    
    if newGear < 0 or newGear > #ratios then
        return false
    end
    
    vehicleData.transmission.current_gear = newGear
    vehicleData.transmission.gear_shift_time = os.time()
    
    return true
end

-- Change transmission mode
function TransmissionSystem.SetTransmissionMode(vehicleData, mode)
    if not TransmissionSystem.Modes[mode] then
        return false
    end
    
    if not vehicleData.transmission then
        TransmissionSystem.InitializeTransmission(vehicleData, mode)
    else
        vehicleData.transmission.mode = mode
    end
    
    return true
end

-- Change gear ratio preset
function TransmissionSystem.SetGearRatioPreset(vehicleData, preset)
    if not TransmissionSystem.GearRatios[preset] then
        return false
    end
    
    if not vehicleData.transmission then
        TransmissionSystem.InitializeTransmission(vehicleData, 'auto', preset)
    else
        vehicleData.transmission.ratio_preset = preset
        vehicleData.transmission.final_drive = TransmissionSystem.GearRatios[preset].finalDrive
    end
    
    return true
end

-- Set custom gear ratios
function TransmissionSystem.SetCustomRatios(vehicleData, ratios, finalDrive)
    if not vehicleData.transmission then
        return false
    end
    
    -- Validate ratios
    if #ratios < 3 or #ratios > 8 then
        return false
    end
    
    vehicleData.transmission.custom_ratios = ratios
    vehicleData.transmission.final_drive = finalDrive or 3.55
    vehicleData.transmission.ratio_preset = 'custom'
    
    return true
end

-- Get current gear count
function TransmissionSystem.GetGearCount(vehicleData)
    if not vehicleData.transmission then return 6 end
    
    local preset = vehicleData.transmission.ratio_preset
    
    if preset == 'custom' then
        return vehicleData.transmission.custom_ratios and #vehicleData.transmission.custom_ratios or 6
    end
    
    return TransmissionSystem.GearRatios[preset].gearCount or 6
end

-- Get next gear recommendation for automatic transmission
function TransmissionSystem.GetNextGearAuto(currentRPM, maxRPM, currentGear, vehicleData)
    local gearCount = TransmissionSystem.GetGearCount(vehicleData)
    
    if not vehicleData.transmission then return currentGear end
    
    local mode = vehicleData.transmission.mode
    local transInfo = TransmissionSystem.GetTransmissionInfo(mode)
    
    -- Shift up when RPM reaches 80% of max
    if currentRPM >= maxRPM * 0.8 and currentGear < gearCount then
        return currentGear + 1
    end
    
    -- Shift down when RPM drops below 30% of max
    if currentRPM < maxRPM * 0.3 and currentGear > 1 then
        return currentGear - 1
    end
    
    return currentGear
end

-- Calculate efficiency loss from transmission
function TransmissionSystem.GetTransmissionEfficiency(vehicleData)
    if not vehicleData.transmission then return 1.0 end
    
    local mode = vehicleData.transmission.mode
    local transInfo = TransmissionSystem.GetTransmissionInfo(mode)
    
    return transInfo.efficiency or 0.92
end

-- Calculate fuel efficiency modifier
function TransmissionSystem.GetFuelEfficiencyModifier(vehicleData)
    if not vehicleData.transmission then return 1.0 end
    
    local mode = vehicleData.transmission.mode
    local transInfo = TransmissionSystem.GetTransmissionInfo(mode)
    
    if mode == 'auto_eco' then
        return transInfo.fuel_efficiency or 1.3
    end
    
    return 1.0
end

-- Get transmission detailed info
function TransmissionSystem.GetDetailedTransmissionInfo(vehicleData)
    if not vehicleData.transmission then return nil end
    
    local trans = vehicleData.transmission
    local preset = TransmissionSystem.GearRatios[trans.ratio_preset] or TransmissionSystem.GearRatios.stock
    local modeInfo = TransmissionSystem.GetTransmissionInfo(trans.mode)
    
    return {
        mode = trans.mode,
        mode_info = modeInfo,
        current_gear = trans.current_gear,
        gear_count = #(preset.ratios or {}),
        ratios = preset.ratios,
        final_drive = trans.final_drive,
        preset = trans.ratio_preset,
        efficiency = TransmissionSystem.GetTransmissionEfficiency(vehicleData),
        fuel_efficiency = TransmissionSystem.GetFuelEfficiencyModifier(vehicleData)
    }
end

-- Validate transmission data integrity
function TransmissionSystem.ValidateTransmission(vehicleData)
    if not vehicleData.transmission then
        return false
    end
    
    local mode = vehicleData.transmission.mode
    local preset = vehicleData.transmission.ratio_preset
    
    if not TransmissionSystem.Modes[mode] then
        return false
    end
    
    if preset ~= 'custom' and not TransmissionSystem.GearRatios[preset] then
        return false
    end
    
    return true
end

return TransmissionSystem
