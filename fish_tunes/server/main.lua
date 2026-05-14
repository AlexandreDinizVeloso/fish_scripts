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
    
    TriggerClientEvent('fish_tunes:openAdvancedNUI', src, plate, dynoData, dtData, engines, recipes)
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
            health = math.floor((vehicleData.engine_health + vehicleData.transmission_health + vehicleData.suspension_health + vehicleData.brakes_health + vehicleData.tires_health + vehicleData.turbo_health) / 6),
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
