-- ============================================================
-- fish_tunes: Server Main (oxmysql + HEAT State Bags)
-- Handles part installation, HEAT tracking, drivetrain,
-- degradation, and police trigger integration.
-- ============================================================

local heatCache = {}  -- { [plate] = { heat=0, lastDecay=0 } }

-- ============================================================
-- DB wrappers (use fish_normalizer exports for cross-resource access)
-- ============================================================

local function DBGetTunes(plate)
    return exports['fish_normalizer']:DBGetTunes(plate)
end

local function DBSaveTunes(plate, data, owner)
    return exports['fish_normalizer']:DBSaveTunes(plate, data, owner)
end

local function DBGetRemap(plate)
    return exports['fish_normalizer']:DBGetRemap(plate)
end

-- ============================================================
-- HEAT Constants
-- ============================================================

local HEAT_DECAY_RATE      = 2   -- points per minute when not in vehicle
local HEAT_DECAY_INTERVAL  = 60  -- seconds between decay ticks
local HEAT_POLICE_THRESHOLD = Config and Config.PoliceHeatThreshold or 40
local HEAT_MAX             = Config and Config.MaxHeat or 100

-- ============================================================
-- Startup
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print('[fish_tunes] Started. HEAT system active.')

    -- Load all tune heat values into cache
    local allVehicles = MySQL.query.await('SELECT plate, heat, heat_last_decay FROM fish_vehicle_tunes', {})
    if allVehicles then
        for _, row in ipairs(allVehicles) do
            heatCache[row.plate] = { heat = row.heat or 0, lastDecay = row.heat_last_decay or os.time() }
        end
    end

    print('[fish_tunes] Started. HEAT system active.')

    -- Start HEAT decay timer
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(HEAT_DECAY_INTERVAL * 1000)
            DecayAllHeat()
        end
    end)
end)

-- ============================================================
-- HEAT Functions
-- ============================================================

local function GetHeat(plate)
    return (heatCache[plate] and heatCache[plate].heat) or 0
end

local function AddHeat(plate, amount)
    if not heatCache[plate] then
        heatCache[plate] = { heat = 0, lastDecay = os.time() }
    end
    heatCache[plate].heat = math.min(HEAT_MAX, heatCache[plate].heat + amount)
    -- Persist async
    MySQL.query('UPDATE fish_vehicle_tunes SET heat = ?, heat_last_decay = ? WHERE plate = ?', {
        heatCache[plate].heat, os.time(), plate
    })
    return heatCache[plate].heat
end

function DecayAllHeat()
    local now = os.time()
    for plate, data in pairs(heatCache) do
        if data.heat > 0 then
            local elapsed = now - (data.lastDecay or now)
            local decayAmount = math.floor((elapsed / 60) * HEAT_DECAY_RATE)
            if decayAmount > 0 then
                data.heat = math.max(0, data.heat - decayAmount)
                data.lastDecay = now
                MySQL.query('UPDATE fish_vehicle_tunes SET heat = ?, heat_last_decay = ? WHERE plate = ?', {
                    data.heat, now, plate
                })
            end
        end
    end
end

-- ============================================================
-- Helper: Recalculate total bonuses + instability from parts
-- ============================================================

local function CalculatePartTotals(parts)
    local bonuses = { top_speed = 0, acceleration = 0, handling = 0, braking = 0 }
    local instability = 0
    local totalHeat   = 0

    for cat, lv in pairs(parts) do
        local partBonuses = Config.PartBonuses[cat] and Config.PartBonuses[cat][lv]
        if partBonuses then
            for stat, val in pairs(partBonuses) do
                if stat == 'instability' then
                    instability = instability + val
                elseif stat ~= 'durability_loss' and bonuses[stat] then
                    bonuses[stat] = bonuses[stat] + val
                end
            end
        end
        local levelInfo = Config.PartLevels[lv]
        if levelInfo and not levelInfo.legal then
            totalHeat = totalHeat + (levelInfo.heat or 0)
        end
    end

    return bonuses, instability, totalHeat
end

-- ============================================================
-- Helper: Refresh state bags after tuning change
-- ============================================================

local function RefreshVehicleState(plate, vehicleNetId, tuneData)
    local normData  = exports['fish_normalizer']:GetVehicleDataServer(plate)
    if not normData then return end
    local remapData = DBGetRemap(plate)
    exports['fish_normalizer']:PushVehicleState(vehicleNetId, normData, remapData, tuneData)
end

-- ============================================================
-- Helper: Trigger police alert based on HEAT level
-- ============================================================

local function TriggerPoliceHeatAlert(src, plate, heatLevel)
    if heatLevel < HEAT_POLICE_THRESHOLD then return end

    -- Placeholder: when fish_police resource exists, trigger it here.
    -- For now, broadcast a server event that the police resource can listen to.
    TriggerEvent('fish_tunes:heatAlert', {
        source    = src,
        plate     = plate,
        heatLevel = heatLevel,
        timestamp = os.time()
    })

    -- Also notify the player (debug)
    if heatLevel >= 70 then
        TriggerClientEvent('fish_tunes:clientNotify', src, {
            type    = 'warning',
            message = ('⚠ HIGH HEAT: %d%% — Police may investigate this vehicle!'):format(heatLevel)
        })
    end
end

-- ============================================================
-- Net Event: Install Part
-- ============================================================

RegisterNetEvent('fish_tunes:installPart')
AddEventHandler('fish_tunes:installPart', function(plate, category, level, vehicleNetId)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    -- Validate
    if not Config.PartBonuses[category] or not Config.PartBonuses[category][level] then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message='Invalid part.'})
        return
    end

    -- Cost
    local cost = (Config.PartCosts and Config.PartCosts[level]) or 0
    if cost > 0 and not player.Functions.RemoveMoney('bank', cost, 'part-install') then
        TriggerClientEvent('fish_tunes:clientNotify', src, {
            type    = 'error',
            message = ('Not enough money. Need $%d'):format(cost)
        })
        return
    end

    -- Load or create tune record
    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)
    local existing   = DBGetTunes(plate) or { parts = {}, drivetrain = 'FWD', heat = 0 }
    local parts      = existing.parts or {}
    if type(parts) == 'string' then parts = json.decode(parts) or {} end

    -- Validate: can't downgrade for free (must pay removal first)
    local currentLevel = parts[category]
    if currentLevel then
        local currentNum = Config.PartLevels[currentLevel] and Config.PartLevels[currentLevel].level or 0
        local newNum     = Config.PartLevels[level] and Config.PartLevels[level].level or 0
        if newNum < currentNum then
            TriggerClientEvent('fish_tunes:clientNotify', src, {
                type    = 'error',
                message = 'Cannot downgrade a part. Remove it first.'
            })
            if cost > 0 then player.Functions.AddMoney('bank', cost, 'part-refund') end
            return
        end
    end

    parts[category] = level
    local bonuses, instability, totalHeat = CalculatePartTotals(parts)

    -- Update heat
    existing.parts    = parts
    existing.heat     = totalHeat
    heatCache[plate]  = heatCache[plate] or { heat = 0, lastDecay = os.time() }
    heatCache[plate].heat = totalHeat

    DBSaveTunes(plate, existing, identifier)

    print(('[fish_tunes] %s installed %s %s on %s (Heat: %d, Cost: $%d)'):format(
        GetPlayerName(src), level, category, plate, totalHeat, cost
    ))

    -- Push state bag update
    if vehicleNetId and vehicleNetId > 0 then
        -- Update netId entity state bag for HEAT
        Entity(NetworkGetEntityFromNetworkId(vehicleNetId)).state:set('fish:heat', totalHeat, true)
        RefreshVehicleState(plate, vehicleNetId, existing)
    end

    -- Police trigger
    TriggerPoliceHeatAlert(src, plate, totalHeat)

    TriggerClientEvent('fish_tunes:partInstalled', src, {
        plate       = plate,
        category    = category,
        level       = level,
        bonuses     = bonuses,
        instability = instability,
        heat        = totalHeat,
        cost        = cost
    })
    TriggerClientEvent('fish_tunes:clientNotify', src, {
        type    = 'success',
        message = ('Installed %s %s — Heat: %d%% (-$%d)'):format(level:upper(), category, totalHeat, cost)
    })
end)

-- ============================================================
-- Net Event: Convert Drivetrain
-- ============================================================

RegisterNetEvent('fish_tunes:convertDrivetrain')
AddEventHandler('fish_tunes:convertDrivetrain', function(plate, drivetrain, vehicleNetId)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local cost = Config.DrivetrainCost or 5000
    if not player.Functions.RemoveMoney('bank', cost, 'drivetrain-convert') then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message=('Need $%d'):format(cost)})
        return
    end

    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)
    local existing   = DBGetTunes(plate) or {}
    existing.drivetrain = drivetrain
    DBSaveTunes(plate, existing, identifier)

    if vehicleNetId and vehicleNetId > 0 then
        TriggerClientEvent('fish_tunes:applyDrivetrain', src, plate, drivetrain)
        RefreshVehicleState(plate, vehicleNetId, existing)
    end

    TriggerClientEvent('fish_tunes:clientNotify', src, {
        type    = 'success',
        message = ('Drivetrain → %s (-$%d)'):format(drivetrain, cost)
    })
end)

-- ============================================================
-- Net Event: Repair Vehicle
-- ============================================================

RegisterNetEvent('fish_tunes:repairVehicle')
AddEventHandler('fish_tunes:repairVehicle', function(plate, partType, vehicleNetId)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local repairCost = 2500
    if not player.Functions.RemoveMoney('bank', repairCost, 'vehicle-repair') then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message=('Need $%d'):format(repairCost)})
        return
    end

    local normData = exports['fish_normalizer']:GetVehicleDataServer(plate)
    if not normData then
        player.Functions.AddMoney('bank', repairCost, 'repair-refund')
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message='Vehicle data not found.'})
        return
    end

    if partType == 'all' then
        normData.engine_health       = 100
        normData.transmission_health = 100
        normData.suspension_health   = 100
        normData.brakes_health       = 100
        normData.tires_health        = 100
        normData.turbo_health        = 100
    else
        local key = partType .. '_health'
        if normData[key] then normData[key] = 100 end
    end

    exports['fish_normalizer']:SaveVehicleData(plate, normData)

    if vehicleNetId and vehicleNetId > 0 then
        RefreshVehicleState(plate, vehicleNetId, DBGetTunes(plate))
    end

    TriggerClientEvent('fish_tunes:clientNotify', src, {
        type    = 'success',
        message = ('Vehicle repaired! (-$%d)'):format(repairCost)
    })
end)

-- ============================================================
-- Net Event: Request tunes data for a plate
-- ============================================================

RegisterNetEvent('fish_tunes:requestData')
AddEventHandler('fish_tunes:requestData', function(plate)
    local src  = source
    local data = DBGetTunes(plate) or {}
    TriggerClientEvent('fish_tunes:receiveData', src, plate, data)
end)

-- ============================================================
-- Net Event: Request check car (health inspection)
-- ============================================================

RegisterNetEvent('fish_tunes:requestCheckCar')
AddEventHandler('fish_tunes:requestCheckCar', function(plate)
    local src      = source
    local normData = exports['fish_normalizer']:GetVehicleDataServer(plate)
    if not normData then
        TriggerClientEvent('fish_tunes:receiveCheckCar', src, nil)
        return
    end

    local function HealthStatus(h)
        if h >= 90 then return {label='Excellent ✅', color='#66BB6A'}
        elseif h >= 75 then return {label='Good 👍', color='#4FC3F7'}
        elseif h >= 50 then return {label='Fair ⚠️', color='#FFD54F'}
        elseif h >= 25 then return {label='Poor 🔧', color='#FF8800'}
        else return {label='Critical ❌', color='#FF1744'} end
    end

    local summary = {
        engine       = { health = normData.engine_health       or 100, status = HealthStatus(normData.engine_health       or 100) },
        transmission = { health = normData.transmission_health or 100, status = HealthStatus(normData.transmission_health or 100) },
        suspension   = { health = normData.suspension_health   or 100, status = HealthStatus(normData.suspension_health   or 100) },
        brakes       = { health = normData.brakes_health       or 100, status = HealthStatus(normData.brakes_health       or 100) },
        tires        = { health = normData.tires_health        or 100, status = HealthStatus(normData.tires_health        or 100) },
        turbo        = { health = normData.turbo_health        or 100, status = HealthStatus(normData.turbo_health        or 100) },
        overall      = {
            health         = math.floor(((normData.engine_health or 100) + (normData.transmission_health or 100) + (normData.suspension_health or 100) + (normData.brakes_health or 100) + (normData.tires_health or 100) + (normData.turbo_health or 100)) / 6),
            mileage        = normData.mileage or 0,
            harsh_events   = normData.harsh_acceleration_events or 0,
            overspeed_events = normData.overspeed_events or 0,
        }
    }

    TriggerClientEvent('fish_tunes:receiveCheckCar', src, summary)
end)

-- ============================================================
-- Net Event: Mileage + degradation update from client
-- ============================================================

RegisterNetEvent('fish_tunes:updateMileage')
AddEventHandler('fish_tunes:updateMileage', function(plate, distance, events)
    if not plate or not distance then return end

    local normData = exports['fish_normalizer']:GetVehicleDataServer(plate)
    if not normData then return end

    normData.mileage                = (normData.mileage or 0) + distance
    normData.total_driven_distance  = (normData.total_driven_distance or 0) + distance

    -- Apply event-based degradation
    if events then
        if events.harsh_accel then
            normData.engine_health       = math.max(0, (normData.engine_health or 100) - (events.harsh_accel * 0.15))
            normData.transmission_health = math.max(0, (normData.transmission_health or 100) - (events.harsh_accel * 0.08))
            normData.harsh_acceleration_events = (normData.harsh_acceleration_events or 0) + events.harsh_accel
        end
        if events.overspeed then
            normData.tires_health        = math.max(0, (normData.tires_health or 100) - (events.overspeed * 0.12))
            normData.engine_health       = math.max(0, (normData.engine_health or 100) - (events.overspeed * 0.06))
            normData.overspeed_events    = (normData.overspeed_events or 0) + events.overspeed
        end
        if events.rough_handling then
            normData.suspension_health   = math.max(0, (normData.suspension_health or 100) - (events.rough_handling * 0.10))
            normData.tires_health        = math.max(0, (normData.tires_health or 100) - (events.rough_handling * 0.08))
            normData.rough_handling_events = (normData.rough_handling_events or 0) + events.rough_handling
        end
    end

    exports['fish_normalizer']:SaveVehicleData(plate, normData)
end)

-- ============================================================
-- Net Event: Get HEAT leaderboard (for fish_hub)
-- ============================================================

RegisterNetEvent('fish_tunes:requestHeatLeaderboard')
AddEventHandler('fish_tunes:requestHeatLeaderboard', function()
    local src = source
    local result = MySQL.query.await([[
        SELECT t.plate, t.heat, d.owner_identifier, d.archetype, d.rank
        FROM fish_vehicle_tunes t
        LEFT JOIN fish_vehicle_data d ON t.plate = d.plate
        WHERE t.heat > 0
        ORDER BY t.heat DESC
        LIMIT 20
    ]], {})
    TriggerClientEvent('fish_tunes:receiveHeatLeaderboard', src, result or {})
end)

-- ============================================================
-- Net Event: Client requests advanced tunes data (open NUI)
-- This is the bridge between /tunes command and NUI open.
-- ============================================================

RegisterNetEvent('fish_tunes:requestAdvancedData')
AddEventHandler('fish_tunes:requestAdvancedData', function(plate)
    local src = source
    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)

    -- Get tunes data
    local tunesRow = DBGetTunes(plate) or {}

    -- Get vehicle health data (from normalizer DB)
    local normData = exports['fish_normalizer']:GetVehicleDataServer(plate) or {}
    local healthData = nil
    if normData then
        local function HealthStatus(h)
            if h >= 90 then return {label='Excellent ✅', color='#66BB6A'}
            elseif h >= 75 then return {label='Good 👍', color='#4FC3F7'}
            elseif h >= 50 then return {label='Fair ⚠️', color='#FFD54F'}
            elseif h >= 25 then return {label='Poor 🔧', color='#FF8800'}
            else return {label='Critical ❌', color='#FF1744'} end
        end
        healthData = {
            engine       = { health = normData.engine_health       or 100, status = HealthStatus(normData.engine_health       or 100) },
            transmission = { health = normData.transmission_health or 100, status = HealthStatus(normData.transmission_health or 100) },
            suspension   = { health = normData.suspension_health   or 100, status = HealthStatus(normData.suspension_health   or 100) },
            brakes       = { health = normData.brakes_health       or 100, status = HealthStatus(normData.brakes_health       or 100) },
            tires        = { health = normData.tires_health        or 100, status = HealthStatus(normData.tires_health        or 100) },
            turbo        = { health = normData.turbo_health        or 100, status = HealthStatus(normData.turbo_health        or 100) },
        }
    end

    -- Get class data from normalizer
    local score = normData.score or 0
    local rank  = normData.rank or 'C'

    -- Build class data
    local classData = {
        currentClass = rank,
        score = score,
    }

    -- Get drivetrain data
    local dtData = {
        mode = tunesRow.drivetrain or 'FWD',
    }

    -- Get dyno data (from remaps if available)
    local remapData = DBGetRemap(plate) or {}
    local dynoData = (type(remapData.dyno) == 'string') and json.decode(remapData.dyno) or (remapData.dyno or nil)

    -- Engine swaps & recipes
    local engines = {}   -- future: load from DB
    local recipes = Config.CraftingRecipes or {}

    -- Update tunes cache for this player
    if tunesRow.plate then
        TriggerClientEvent('fish_tunes:receiveData', src, plate, tunesRow)
    end

    -- Open the NUI
    TriggerClientEvent('fish_tunes:openAdvancedNUI', src, plate, dynoData, dtData, engines, recipes, healthData, classData)
end)

-- ============================================================
-- Net Event: Save tunes (general save from NUI callbacks)
-- ============================================================

RegisterNetEvent('fish_tunes:saveTunes')
AddEventHandler('fish_tunes:saveTunes', function(plate, data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    if not plate or not data then return end

    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)

    -- Calculate heat from parts
    local parts = data.parts or {}
    local _, _, totalHeat = CalculatePartTotals(parts)
    data.heat = totalHeat

    DBSaveTunes(plate, data, identifier)

    -- Update heat cache
    heatCache[plate] = { heat = totalHeat, lastDecay = os.time() }

    -- Get current vehicle netId for state bag update
    local ped = GetPlayerPed(src)
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local vehPlate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
        if vehPlate == plate then
            local netId = NetworkGetNetworkIdFromEntity(veh)
            Entity(veh).state:set('fish:heat', totalHeat, true)
            RefreshVehicleState(plate, netId, data)
        end
    end

    TriggerClientEvent('fish_tunes:clientNotify', src, {type='success', message='Tunes saved.'})
end)

-- ============================================================
-- Net Event: Set transmission mode
-- ============================================================

RegisterNetEvent('fish_tunes:setTransmissionMode')
AddEventHandler('fish_tunes:setTransmissionMode', function(plate, mode)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)
    local existing = DBGetTunes(plate) or {}
    existing.drivetrain = mode or existing.drivetrain
    DBSaveTunes(plate, existing, identifier)

    TriggerClientEvent('fish_tunes:clientNotify', src, {type='success', message = ('Transmission mode → %s'):format(mode or '?')})
end)

-- ============================================================
-- Net Event: Set gear ratio
-- ============================================================

RegisterNetEvent('fish_tunes:setGearRatio')
AddEventHandler('fish_tunes:setGearRatio', function(plate, preset)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local cost = Config.GearRatioCost or 5000
    if not player.Functions.RemoveMoney('bank', cost, 'gear-ratio') then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message = ('Need $%d'):format(cost)})
        return
    end

    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)
    local existing = DBGetTunes(plate) or {}
    existing.gear_preset = preset
    DBSaveTunes(plate, existing, identifier)

    TriggerClientEvent('fish_tunes:clientNotify', src, {type='success', message = ('Gear ratio → %s (-$%d)'):format(preset or '?', cost)})
end)

-- ============================================================
-- Net Event: Swap class
-- ============================================================

RegisterNetEvent('fish_tunes:swapClass')
AddEventHandler('fish_tunes:swapClass', function(plate, targetClass)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local normData = exports['fish_normalizer']:GetVehicleDataServer(plate)
    if not normData then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message='Vehicle not found.'})
        return
    end

    local currentClass = normData.rank or 'C'
    local costKey = currentClass .. '_' .. targetClass
    local costs = Config.ClassSwapCosts or {}
    local cost = costs[costKey]
    if not cost then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message=('Cannot swap from %s to %s'):format(currentClass, targetClass)})
        return
    end

    if not player.Functions.RemoveMoney('bank', cost, 'class-swap') then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message = ('Need $%d'):format(cost)})
        return
    end

    -- Apply class swap: adjust score to the middle of the target class range
    local classRanges = { C={0,499}, B={500,749}, A={750,899}, S={900,999} }
    local range = classRanges[targetClass]
    if range then
        normData.score = math.floor((range[1] + range[2]) / 2)
        normData.rank = targetClass
        normData.class_swapped = 1
        exports['fish_normalizer']:SaveVehicleData(plate, normData)

        -- Push state bag
        local ped = GetPlayerPed(src)
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            local vehPlate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
            if vehPlate == plate then
                local netId = NetworkGetNetworkIdFromEntity(veh)
                RefreshVehicleState(plate, netId, DBGetTunes(plate))
            end
        end
    end

    TriggerClientEvent('fish_tunes:classSwapped', src, plate, targetClass, normData.score)
    TriggerClientEvent('fish_tunes:clientNotify', src, {
        type = 'success',
        message = ('Class swapped to %s (-$%d)'):format(targetClass, cost)
    })
end)

-- ============================================================
-- Net Event: Apply Tire Compound
-- ============================================================

RegisterNetEvent('fish_tunes:applyTireCompound')
AddEventHandler('fish_tunes:applyTireCompound', function(plate, compound, vehicleNetId)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local tireData = Config.TireCompounds and Config.TireCompounds[compound]
    if not tireData then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message='Invalid tire compound.'})
        return
    end

    local cost = tireData.cost or 0
    if cost > 0 and not player.Functions.RemoveMoney('bank', cost, 'tire-compound') then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message=('Need $%d'):format(cost)})
        return
    end

    -- Store tire compound in tunes data
    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)
    local existing = DBGetTunes(plate) or { parts = {}, drivetrain = 'FWD', heat = 0 }
    existing.tire_compound = compound
    DBSaveTunes(plate, existing, identifier)

    -- Push tire compound via state bag
    if vehicleNetId and vehicleNetId > 0 then
        local entity = NetworkGetEntityFromNetworkId(vehicleNetId)
        if DoesEntityExist(entity) then
            Entity(entity).state:set('fish:tire_compound', compound, true)
            -- Apply tire handling multipliers
            Entity(entity).state:set('fish:tire_handling', tireData.handling, true)
        end
        RefreshVehicleState(plate, vehicleNetId, existing)
    end

    TriggerClientEvent('fish_tunes:clientNotify', src, {
        type = 'success',
        message = ('Tires → %s (-$%d)'):format(tireData.label, cost)
    })
end)

-- ============================================================
-- Net Event: Toggle Vehicle Flag
-- ============================================================

RegisterNetEvent('fish_tunes:toggleVehicleFlag')
AddEventHandler('fish_tunes:toggleVehicleFlag', function(plate, flagKey, vehicleNetId)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local flagData = Config.VehicleFlags and Config.VehicleFlags[flagKey]
    if not flagData then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message='Invalid vehicle flag.'})
        return
    end

    local cost = flagData.cost or 0
    if cost > 0 and not player.Functions.RemoveMoney('bank', cost, 'vehicle-flag') then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message=('Need $%d'):format(cost)})
        return
    end

    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)
    local existing = DBGetTunes(plate) or { parts = {}, drivetrain = 'FWD', heat = 0 }

    -- Toggle: if already installed, remove it; otherwise add it
    if not existing.vehicle_flags then existing.vehicle_flags = {} end
    if existing.vehicle_flags[flagKey] then
        existing.vehicle_flags[flagKey] = nil
    else
        existing.vehicle_flags[flagKey] = flagData.value
    end
    DBSaveTunes(plate, existing, identifier)

    if vehicleNetId and vehicleNetId > 0 then
        local entity = NetworkGetEntityFromNetworkId(vehicleNetId)
        if DoesEntityExist(entity) then
            Entity(entity).state:set('fish:vehicle_flags', existing.vehicle_flags, true)
        end
        RefreshVehicleState(plate, vehicleNetId, existing)
    end

    local action = existing.vehicle_flags[flagKey] and 'Installed' or 'Removed'
    TriggerClientEvent('fish_tunes:clientNotify', src, {
        type = 'success',
        message = ('%s %s'):format(action, flagData.label)
    })
end)

-- ============================================================
-- Net Event: Save ECU Tune (multi-slider values)
-- ============================================================

RegisterNetEvent('fish_tunes:saveECUTune')
AddEventHandler('fish_tunes:saveECUTune', function(plate, ecuData, vehicleNetId)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if not ecuData then return end

    local identifier = GetPlayerIdentifier(src, 0) or ('player:' .. src)
    local existing = DBGetTunes(plate) or { parts = {}, drivetrain = 'FWD', heat = 0 }

    -- Validate ECU values against config ranges
    local ecuConfig = Config.ECUTuning
    if ecuConfig then
        for param, value in pairs(ecuData) do
            local cfg = ecuConfig[param]
            if cfg then
                ecuData[param] = math.max(cfg.min, math.min(cfg.max, tonumber(value) or cfg.default))
            end
        end
    end

    existing.ecu_tune = ecuData
    DBSaveTunes(plate, existing, identifier)

    if vehicleNetId and vehicleNetId > 0 then
        local entity = NetworkGetEntityFromNetworkId(vehicleNetId)
        if DoesEntityExist(entity) then
            Entity(entity).state:set('fish:ecu_tune', ecuData, true)
        end
        RefreshVehicleState(plate, vehicleNetId, existing)
    end

    TriggerClientEvent('fish_tunes:clientNotify', src, {
        type = 'success',
        message = 'ECU tune saved.'
    })
end)

-- ============================================================
-- Net Event: Craft part
-- ============================================================

RegisterNetEvent('fish_tunes:craftPart')
AddEventHandler('fish_tunes:craftPart', function(recipeId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local recipe = Config.CraftingRecipes and Config.CraftingRecipes[recipeId]
    if not recipe then
        TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message='Unknown recipe.'})
        return
    end

    -- Check cost
    if recipe.cost > 0 then
        if not player.Functions.RemoveMoney('bank', recipe.cost, 'craft-part') then
            TriggerClientEvent('fish_tunes:clientNotify', src, {type='error', message = ('Need $%d'):format(recipe.cost)})
            return
        end
    end

    -- TODO: Check materials from QBX inventory when crafting is fully implemented
    -- For now, just succeed and notify
    TriggerClientEvent('fish_tunes:clientNotify', src, {
        type = 'success',
        message = ('Crafted %s! (materials check coming soon)'):format(recipe.label)
    })
end)

-- ============================================================
-- Server Exports
-- ============================================================

    exports('GetVehicleTunesServer', function(plate)
    return DBGetTunes(plate)
end)

exports('GetHeatLevel', function(plate)
    return GetHeat(plate)
end)

exports('GetHeatLeaderboard', function()
    local result = MySQL.query.await([[
        SELECT t.plate, t.heat, d.owner_identifier, d.archetype, d.rank, d.score
        FROM fish_vehicle_tunes t
        LEFT JOIN fish_vehicle_data d ON t.plate = d.plate
        WHERE t.heat > 0
        ORDER BY t.heat DESC
        LIMIT 20
    ]], {})
    return result or {}
end)

exports('AddHeat', AddHeat)
