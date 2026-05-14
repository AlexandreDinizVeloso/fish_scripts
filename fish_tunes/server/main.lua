-- fish_tunes: Server Main
local tunesDataCache = {}
local vehicleDegradationData = {} -- Track degradation events per vehicle
local config = {}

-- Load modules (Now loaded globally via fxmanifest)
-- Modules: Degradation, MileageTracker, TireSystem, TransmissionSystem, EngineSwap, PartCrafting

function LoadTunesData()
    local data = LoadResourceFile(GetCurrentResourceName(), 'server/tunes_data.json')
    if data then tunesDataCache = json.decode(data) or {} end
end

function SaveTunesDataToFile()
    SaveResourceFile(GetCurrentResourceName(), 'server/tunes_data.json', json.encode(tunesDataCache), -1)
end

-- Load config from exports
function LoadConfig()
    config = Config
    -- Initialize all modules with config
    Degradation.Init(config)
    MileageTracker.Init(config)
    TireSystem.Init(config)
    TransmissionSystem.Init(config)
    EngineSwap.Init(config)
    PartCrafting.Init(config)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        LoadConfig()
        LoadTunesData()
        print('[fish_tunes] Tunes data loaded.')
        print('[fish_tunes] Degradation system initialized.')
        print('[fish_tunes] Mileage tracking initialized.')
        print('[fish_tunes] Tire system initialized.')
        print('[fish_tunes] Transmission system initialized.')
    end
end)

-- Player disconnect cleanup
AddEventHandler('playerDropped', function(reason)
    local src = source
    MileageTracker.UnregisterAllPlayerVehicles(src)
end)

RegisterNetEvent('fish_tunes:requestData')
AddEventHandler('fish_tunes:requestData', function()
    local src = source
    TriggerClientEvent('fish_tunes:receiveData', src, tunesDataCache)
end)

RegisterNetEvent('fish_tunes:saveTunes')
AddEventHandler('fish_tunes:saveTunes', function(plate, data)
    local src = source
    if not plate or not data then return end
    tunesDataCache[plate] = data
    tunesDataCache[plate].owner = GetPlayerIdentifier(src, 0)
    tunesDataCache[plate].lastUpdated = os.time()
    SaveTunesDataToFile()
end)

RegisterNetEvent('fish_tunes:requestAdvancedData')
AddEventHandler('fish_tunes:requestAdvancedData', function(plate)
    local src = source
    local dynoData = tunesDataCache[plate] and tunesDataCache[plate].dyno or {
        afr = 13.5, timing = 0, boost = 0, drive = 3.55
    }
    local dtData = tunesDataCache[plate] and tunesDataCache[plate].drivetrain or "AWD"

    local engines = EngineSwap.GetAvailableEngines()
    local recipes = PartCrafting.GetAllRecipes()

    -- Get health data
    local healthData = GetVehicleHealthSummary(plate)

    -- Get class data from normalizer
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    local classData = {
        currentClass = vehicleData and vehicleData.rank or 'C',
        score = vehicleData and vehicleData.score or 0
    }

    TriggerClientEvent('fish_tunes:openAdvancedNUI', src, plate, dynoData, dtData, engines, recipes, healthData, classData)
end)

RegisterNetEvent('fish_tunes:swapEngineServer')
AddEventHandler('fish_tunes:swapEngineServer', function(plate, engineType, cost)
    local src = source
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if vehicleData then
        -- Charge money via Qbox
        local player = exports.qbx_core:GetPlayer(src)
        if player.Functions.RemoveMoney('bank', cost, 'engine-swap') then
            local success, msg = EngineSwap.SwapEngine(vehicleData, engineType, cost)
            if success then
                normalizer:SaveVehicleData(plate, vehicleData)
                TriggerClientEvent('fish_tunes:clientEngineSwapped', src, plate, vehicleData.engine)
                TriggerClientEvent('fish_tunes:clientNotify', src, '~g~Engine Swap Successful: ' .. engineType)
            else
                player.Functions.AddMoney('bank', cost, 'engine-swap-refund')
                TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Engine Swap Failed: ' .. msg)
            end
        else
            TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Not enough money in bank.')
        end
    end
end)

RegisterNetEvent('fish_tunes:setTransmissionModeServer')
AddEventHandler('fish_tunes:setTransmissionModeServer', function(plate, mode)
    local src = source
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if vehicleData then
        TransmissionSystem.SetTransmissionMode(vehicleData, mode)
        normalizer:SaveVehicleData(plate, vehicleData)
    end
end)

RegisterNetEvent('fish_tunes:setGearRatioServer')
AddEventHandler('fish_tunes:setGearRatioServer', function(plate, preset)
    local src = source
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if vehicleData then
        TransmissionSystem.SetGearRatioPreset(vehicleData, preset)
        normalizer:SaveVehicleData(plate, vehicleData)
    end
end)

RegisterNetEvent('fish_tunes:craftPartServer')
AddEventHandler('fish_tunes:craftPartServer', function(recipeId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local recipe = PartCrafting.GetRecipe(recipeId)
    
    if not recipe then return end
    
    -- Check Qbox inventory for materials
    local hasItems = true
    for item, amount in pairs(recipe.materials) do
        local invItem = player.Functions.GetItemByName(item)
        if not invItem or invItem.amount < amount then
            hasItems = false
            TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Missing materials: ' .. amount .. 'x ' .. item)
        end
    end
    
    if hasItems then
        for item, amount in pairs(recipe.materials) do
            player.Functions.RemoveItem(item, amount)
        end
        
        local success, craftedPart, quality = PartCrafting.CraftPart(recipeId, 75, 80)
        if success then
            -- Give part to player
            -- player.Functions.AddItem(recipeId, 1) -- assuming recipeId is the item name
            TriggerClientEvent('fish_tunes:clientNotify', src, '~g~Successfully crafted ' .. recipe.label .. ' (Quality: ' .. quality .. '%)')
        else
            TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Crafting failed. Materials lost.')
        end
    end
end)

-- ============================================================
-- Degradation System Functions
-- ============================================================

-- Update mileage for vehicle
function UpdateVehicleMileage(plate, distance)
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if vehicleData then
        vehicleData.mileage = (vehicleData.mileage or 0) + distance
        vehicleData.total_driven_distance = (vehicleData.total_driven_distance or 0) + distance
        normalizer:SaveVehicleData(plate, vehicleData)
        
        -- Check mileage thresholds for degradation
        CheckMileageDegradation(plate, vehicleData)
        
        return vehicleData.mileage
    end
    return nil
end

-- Check if mileage thresholds trigger degradation
function CheckMileageDegradation(plate, vehicleData)
    local mileage = vehicleData.mileage or 0
    
    for _, threshold in ipairs(config.MileageThresholds) do
        if mileage >= threshold.distance then
            -- Apply degradation to all parts
            ApplyDegradation(plate, vehicleData, 'mileage', threshold.degradation)
        end
    end
end

-- Apply degradation to parts based on event
function ApplyDegradation(plate, vehicleData, eventType, intensity)
    if not config.Degradation.enabled then return end
    
    local normalizer = exports['fish_normalizer']
    local afrStatus = vehicleData.tuning_efficiency or 100
    local isDegraded = false
    
    -- Calculate degradation multiplier based on AFR
    local afrMultiplier = 1.0
    if afrStatus < config.AFRTuning.optimal_range_min or afrStatus > config.AFRTuning.optimal_range_max then
        afrMultiplier = 1.5 -- 50% more wear if AFR is not optimal
    end
    
    -- Apply event-specific degradation
    if eventType == 'harsh_acceleration' then
        vehicleData.engine_health = math.max(0, vehicleData.engine_health - (config.DegradationRates.engine.harsh_acceleration_multiplier * intensity * afrMultiplier))
        vehicleData.transmission_health = math.max(0, vehicleData.transmission_health - (config.DegradationRates.transmission.harsh_acceleration_multiplier * intensity))
        vehicleData.harsh_acceleration_events = (vehicleData.harsh_acceleration_events or 0) + 1
        isDegraded = true
    elseif eventType == 'overspeed' then
        vehicleData.engine_health = math.max(0, vehicleData.engine_health - (config.DegradationRates.engine.overspeed_multiplier * intensity))
        vehicleData.transmission_health = math.max(0, vehicleData.transmission_health - (config.DegradationRates.transmission.overspeed_multiplier * intensity))
        vehicleData.tires_health = math.max(0, vehicleData.tires_health - (config.DegradationRates.tires.overspeed_multiplier * intensity))
        vehicleData.overspeed_events = (vehicleData.overspeed_events or 0) + 1
        isDegraded = true
    elseif eventType == 'harsh_braking' then
        vehicleData.brakes_health = math.max(0, vehicleData.brakes_health - (config.DegradationRates.brakes.harsh_braking_multiplier * intensity))
        vehicleData.tires_health = math.max(0, vehicleData.tires_health - (config.DegradationRates.tires.rough_handling_multiplier * intensity * 0.5))
        isDegraded = true
    elseif eventType == 'rough_handling' then
        vehicleData.suspension_health = math.max(0, vehicleData.suspension_health - (config.DegradationRates.suspension.rough_handling_multiplier * intensity))
        vehicleData.tires_health = math.max(0, vehicleData.tires_health - (config.DegradationRates.tires.rough_handling_multiplier * intensity))
        vehicleData.rough_handling_events = (vehicleData.rough_handling_events or 0) + 1
        isDegraded = true
    elseif eventType == 'mileage' then
        -- Gradual degradation from mileage
        for _, part in ipairs({'engine', 'transmission', 'suspension', 'brakes', 'tires'}) do
            local healthKey = part .. '_health'
            vehicleData[healthKey] = math.max(0, vehicleData[healthKey] - intensity)
        end
        isDegraded = true
    end
    
    if isDegraded then
        vehicleData.lastUpdated = os.time()
        normalizer:SaveVehicleData(plate, vehicleData)
    end
end

-- Get part health status
function GetHealthStatus(health)
    if health >= config.HealthStatus.excellent.min then
        return config.HealthStatus.excellent
    elseif health >= config.HealthStatus.good.min then
        return config.HealthStatus.good
    elseif health >= config.HealthStatus.fair.min then
        return config.HealthStatus.fair
    elseif health >= config.HealthStatus.poor.min then
        return config.HealthStatus.poor
    else
        return config.HealthStatus.critical
    end
end

-- Get vehicle health summary
function GetVehicleHealthSummary(plate)
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if not vehicleData then return nil end
    
    return {
        engine = {
            health = vehicleData.engine_health or 100,
            status = GetHealthStatus(vehicleData.engine_health or 100)
        },
        transmission = {
            health = vehicleData.transmission_health or 100,
            status = GetHealthStatus(vehicleData.transmission_health or 100)
        },
        suspension = {
            health = vehicleData.suspension_health or 100,
            status = GetHealthStatus(vehicleData.suspension_health or 100)
        },
        brakes = {
            health = vehicleData.brakes_health or 100,
            status = GetHealthStatus(vehicleData.brakes_health or 100)
        },
        tires = {
            health = vehicleData.tires_health or 100,
            status = GetHealthStatus(vehicleData.tires_health or 100)
        },
        turbo = {
            health = vehicleData.turbo_health or 100,
            status = GetHealthStatus(vehicleData.turbo_health or 100)
        },
        overall = {
            health = math.floor(((vehicleData.engine_health or 100) + (vehicleData.transmission_health or 100) + (vehicleData.suspension_health or 100) + (vehicleData.brakes_health or 100) + (vehicleData.tires_health or 100) + (vehicleData.turbo_health or 100)) / 6),
            mileage = vehicleData.mileage or 0,
            harsh_events = vehicleData.harsh_acceleration_events or 0,
            overspeed_events = vehicleData.overspeed_events or 0
        }
    }
end

-- Repair vehicle parts
function RepairVehicle(plate, partType, repairAmount)
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    
    if not vehicleData then return false end
    
    local healthKey = partType .. '_health'
    if vehicleData[healthKey] then
        vehicleData[healthKey] = math.min(100, vehicleData[healthKey] + repairAmount)
        vehicleData.lastMaintained = os.time()
        normalizer:SaveVehicleData(plate, vehicleData)
        return true
    end
    
    return false
end

function GetVehicleTunesServer(plate)
    return tunesDataCache[plate]
end

function SaveTunesData(plate, data)
    if not plate or not data then return false end
    tunesDataCache[plate] = data
    SaveTunesDataToFile()
    return true
end

-- ============================================================
-- /checkcar - Vehicle Health Inspection
-- ============================================================

RegisterNetEvent('fish_tunes:requestCheckCar')
AddEventHandler('fish_tunes:requestCheckCar', function(plate)
    local src = source
    local healthSummary = GetVehicleHealthSummary(plate)
    TriggerClientEvent('fish_tunes:receiveCheckCar', src, healthSummary)
end)

-- ============================================================
-- Exports
-- ============================================================

exports('GetVehicleHealthSummary', GetVehicleHealthSummary)
exports('UpdateVehicleMileage', UpdateVehicleMileage)
exports('ApplyDegradation', ApplyDegradation)
exports('RepairVehicle', RepairVehicle)
exports('GetHealthStatus', GetHealthStatus)

-- ============================================================
-- Class Swap System
-- ============================================================

RegisterNetEvent('fish_tunes:swapClassServer')
AddEventHandler('fish_tunes:swapClassServer', function(plate, targetClass)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    -- Validate target class
    local allowed = Config.ClassSwap and Config.ClassSwap.allowed_classes or { 'C', 'B', 'A' }
    local valid = false
    for _, c in ipairs(allowed) do
        if c == targetClass then valid = true; break end
    end
    if not valid then
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Invalid target class.')
        return
    end

    -- Get current class from normalizer
    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    if not vehicleData then
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Vehicle data not found.')
        return
    end

    local currentClass = vehicleData.rank or 'C'
    if currentClass == targetClass then
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Vehicle is already class ' .. targetClass)
        return
    end

    -- S class is not achievable via swap
    if targetClass == 'S' or targetClass == 'X' then
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Class S/X cannot be achieved via swap.')
        return
    end

    -- Calculate cost
    local costKey = currentClass .. '_' .. targetClass
    local costs = Config.ClassSwapCosts or {}
    local cost = costs[costKey] or 10000

    -- Check money
    if not player.Functions.RemoveMoney('bank', cost, 'class-swap') then
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Not enough money. Need $' .. cost)
        return
    end

    -- Apply class change - modify the vehicle's normalized stats
    -- We use the normalizer's archetype modifiers to shift the score
    local scoreRanges = { C = {0, 499}, B = {500, 749}, A = {750, 899} }
    local targetRange = scoreRanges[targetClass]
    if not targetRange then
        player.Functions.AddMoney('bank', cost, 'class-swap-refund')
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Invalid class range.')
        return
    end

    -- Set score to middle of target range
    local newScore = math.floor((targetRange[1] + targetRange[2]) / 2)
    vehicleData.score = newScore
    vehicleData.rank = targetClass
    vehicleData.classSwapped = true
    vehicleData.classSwapTime = os.time()

    normalizer:SaveVehicleData(plate, vehicleData)

    TriggerClientEvent('fish_tunes:clientNotify', src, '~g~Class swapped to ' .. targetClass .. '! Cost: $' .. cost)
    TriggerClientEvent('fish_tunes:classSwapped', src, plate, targetClass, newScore)
end)

-- ============================================================
-- Part Installation with Costs
-- ============================================================

RegisterNetEvent('fish_tunes:installPartServer')
AddEventHandler('fish_tunes:installPartServer', function(plate, category, level)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    -- Get cost
    local costs = Config.PartCosts or {}
    local cost = costs[level] or 0

    if cost > 0 then
        if not player.Functions.RemoveMoney('bank', cost, 'part-install') then
            TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Not enough money. Need $' .. cost)
            return
        end
    end

    -- Update tunes data
    if not tunesDataCache[plate] then tunesDataCache[plate] = {} end
    if not tunesDataCache[plate].parts then tunesDataCache[plate].parts = {} end
    tunesDataCache[plate].parts[category] = level
    tunesDataCache[plate].lastUpdated = os.time()

    SaveTunesDataToFile()

    -- Calculate totals
    local totalBonuses = { top_speed = 0, acceleration = 0, handling = 0, braking = 0 }
    local totalHeat = 0
    for cat, lv in pairs(tunesDataCache[plate].parts) do
        local bonuses = Config.PartBonuses[cat] and Config.PartBonuses[cat][lv]
        if bonuses then
            for stat, val in pairs(bonuses) do
                if stat ~= 'instability' and stat ~= 'durability_loss' and totalBonuses[stat] then
                    totalBonuses[stat] = totalBonuses[stat] + val
                end
            end
        end
        local levelInfo = Config.PartLevels[lv]
        if levelInfo and not levelInfo.legal then
            totalHeat = totalHeat + levelInfo.heat
        end
    end

    TriggerClientEvent('fish_tunes:partInstalled', src, plate, category, level, totalBonuses, totalHeat)
    TriggerClientEvent('fish_tunes:clientNotify', src, '~g~Part installed: ' .. (Config.PartLevels[level] and Config.PartLevels[level].label or level) .. ' ' .. category .. (cost > 0 and (' ($' .. cost .. ')') or ''))
end)

-- ============================================================
-- Drivetrain Conversion with Cost
-- ============================================================

RegisterNetEvent('fish_tunes:convertDrivetrainServer')
AddEventHandler('fish_tunes:convertDrivetrainServer', function(plate, drivetrain)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local cost = Config.DrivetrainCost or 5000
    if not player.Functions.RemoveMoney('bank', cost, 'drivetrain-convert') then
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Not enough money. Need $' .. cost)
        return
    end

    if not tunesDataCache[plate] then tunesDataCache[plate] = {} end
    tunesDataCache[plate].drivetrain = drivetrain
    tunesDataCache[plate].lastUpdated = os.time()
    SaveTunesDataToFile()

    -- Apply to vehicle
    exports.fish_tunes:ApplyDrivetrainModifiers(GetVehiclePedIsIn(GetPlayerPed(src), false), drivetrain)
    exports.fish_tunes:ClearDrivetrainCache(plate)

    TriggerClientEvent('fish_tunes:clientNotify', src, '~g~Drivetrain converted to ' .. drivetrain .. ' ($' .. cost .. ')')
end)

-- ============================================================
-- Repair Vehicle
-- ============================================================

RegisterNetEvent('fish_tunes:repairVehicleServer')
AddEventHandler('fish_tunes:repairVehicleServer', function(plate, partType)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local repairCost = 2500 -- base repair cost
    if not player.Functions.RemoveMoney('bank', repairCost, 'vehicle-repair') then
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Not enough money. Need $' .. repairCost)
        return
    end

    local normalizer = exports['fish_normalizer']
    local vehicleData = normalizer:GetVehicleDataServer(plate)
    if not vehicleData then
        player.Functions.AddMoney('bank', repairCost, 'vehicle-repair-refund')
        TriggerClientEvent('fish_tunes:clientNotify', src, '~r~Vehicle data not found.')
        return
    end

    if partType == 'all' then
        vehicleData.engine_health = 100
        vehicleData.transmission_health = 100
        vehicleData.suspension_health = 100
        vehicleData.brakes_health = 100
        vehicleData.tires_health = 100
        vehicleData.turbo_health = 100
    else
        local key = partType .. '_health'
        if vehicleData[key] then
            vehicleData[key] = 100
        end
    end
    vehicleData.lastMaintained = os.time()

    normalizer:SaveVehicleData(plate, vehicleData)

    local healthSummary = GetVehicleHealthSummary(plate)
    TriggerClientEvent('fish_tunes:healthData', src, healthSummary)
    TriggerClientEvent('fish_tunes:clientNotify', src, '~g~Vehicle repaired! ($' .. repairCost .. ')')
end)
