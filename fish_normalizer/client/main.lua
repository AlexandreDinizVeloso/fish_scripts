-- fish_normalizer: Client Main
local isNuiOpen = false
local currentVehicle = nil
local vehicleData = {}
local isAdmin = false

-- ============================================================
-- Entity State Bag: Apply handling when server pushes update
-- ============================================================
AddStateBagChangeHandler('fish:handling', nil, function(bagName, key, value, _, replicated)
    if not value then return end
    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    Citizen.CreateThread(function()
        -- Wait up to 2s for entity to exist
        local attempts = 0
        while not DoesEntityExist(veh) and attempts < 20 do
            Citizen.Wait(100)
            veh = NetworkGetEntityFromNetworkId(netId)
            attempts = attempts + 1
        end
        if DoesEntityExist(veh) then
            exports['fish_normalizer']:ApplyHandlingToVehicle(veh, value)
        end
    end)
end)

-- Update local cache when server pushes score
AddStateBagChangeHandler('fish:score', nil, function(bagName, key, value, _, replicated)
    if not value then return end
    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(veh) then
        local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
        if vehicleData[plate] then
            vehicleData[plate].score = value
        end
    end
end)

-- Get vehicle performance stats from handling.meta
function GetVehiclePerformanceStats(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model):lower()
    local className = GetVehicleClass(vehicle)

    -- Use FiveM native handling data
    local topSpeed = GetVehicleModelMaxSpeed(model) * 3.6 -- convert to km/h
    local accel = GetVehicleModelAcceleration(model)
    local braking = GetVehicleModelMaxBraking(model)
    local traction = GetVehicleModelMaxTraction(model)

    -- Normalize raw values to 0-100 scale
    local normalizedTopSpeed = math.min(100, (topSpeed / 350) * 100)
    local normalizedAccel = math.min(100, (accel / 3.0) * 100)
    local normalizedBraking = math.min(100, (braking / 1.5) * 100)
    local normalizedTraction = math.min(100, (traction / 3.0) * 100)

    return {
        model = model,
        name = displayName,
        class = className,
        raw = {
            top_speed = topSpeed,
            acceleration = accel,
            braking = braking,
            traction = traction
        },
        normalized = {
            top_speed = normalizedTopSpeed,
            acceleration = normalizedAccel,
            braking = normalizedBraking,
            handling = normalizedTraction
        }
    }
end

-- Calculate weighted score from normalized stats
function CalculateBaseScore(stats)
    if not stats then return 0 end

    local score = 0
    score = score + (stats.normalized.top_speed * Config.Weights.top_speed)
    score = score + (stats.normalized.acceleration * Config.Weights.acceleration)
    score = score + (stats.normalized.handling * Config.Weights.handling)
    score = score + (stats.normalized.braking * Config.Weights.braking)

    return math.floor(score * 10) -- scale to 0-1000
end

-- Apply archetype modifiers to score
function ApplyArchetypeModifiers(baseScore, stats, archetypeKey)
    local archetype = Config.Archetypes[archetypeKey]
    if not archetype then return baseScore, stats end

    local modifiedStats = {}
    for k, v in pairs(stats.normalized) do
        local modifier = archetype.statModifiers[k] or 1.0
        modifiedStats[k] = v * modifier
    end

    -- Recalculate score with modified stats
    local modifiedScore = 0
    modifiedScore = modifiedScore + (modifiedStats.top_speed * Config.Weights.top_speed)
    modifiedScore = modifiedScore + (modifiedStats.acceleration * Config.Weights.acceleration)
    modifiedScore = modifiedScore + (modifiedStats.handling * Config.Weights.handling)
    modifiedScore = modifiedScore + (modifiedStats.braking * Config.Weights.braking)
    modifiedScore = math.floor(modifiedScore * 10)

    -- Apply score bias
    local bias = archetype.scoreBias
    modifiedScore = modifiedScore + (bias.top_speed or 0)
    modifiedScore = modifiedScore + (bias.acceleration or 0)
    modifiedScore = modifiedScore + (bias.handling or 0)
    modifiedScore = modifiedScore + (bias.braking or 0)

    return math.max(0, math.min(1000, modifiedScore)), modifiedStats
end

-- Apply sub-archetype bonuses
function ApplySubArchetypeBonuses(score, subArchetypeKey)
    local sub = Config.SubArchetypes[subArchetypeKey]
    if not sub then return score end

    local bonus = 0
    for _, v in pairs(sub.statBonus) do
        bonus = bonus + v
    end

    return math.max(0, math.min(1000, score + bonus))
end

-- Get rank from score
function GetRankFromScore(score)
    for _, rank in ipairs(Config.Ranks) do
        if score >= rank.min and score <= rank.max then
            return rank
        end
    end
    return Config.Ranks[1] -- default C
end

-- Main export: Get vehicle rank
function GetVehicleRank(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local stats = GetVehiclePerformanceStats(vehicle)
    if not stats then return nil end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local storedData = vehicleData[plate]
    local archetype = 'esportivo'
    local subArchetype = nil

    if storedData then
        archetype = storedData.archetype or 'esportivo'
        subArchetype = storedData.subArchetype
    else
        archetype = Config.VehicleClassMap[stats.class] or 'esportivo'
    end

    -- Calculate base first to map the archetype
    local baseScore = CalculateBaseScore(stats)
    local _, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, archetype)
    
    -- INJECT REMAP MULTIPLIERS
    if GetResourceState('fish_remaps') == 'started' then
        local remapData = exports['fish_remaps']:GetVehicleRemapData(vehicle)
        if remapData and remapData.finalStats then
            local rStats = remapData.finalStats
            local rMult = {
                top_speed = 0.8 + (rStats.top_speed or 50) / 100 * 0.4,
                acceleration = 0.8 + (rStats.acceleration or 50) / 100 * 0.4,
                handling = 0.8 + (rStats.handling or 50) / 100 * 0.4,
                braking = 0.8 + (rStats.braking or 50) / 100 * 0.4
            }
            modifiedStats.top_speed = modifiedStats.top_speed * rMult.top_speed
            modifiedStats.acceleration = modifiedStats.acceleration * rMult.acceleration
            modifiedStats.handling = modifiedStats.handling * rMult.handling
            modifiedStats.braking = modifiedStats.braking * rMult.braking
        end
    end

    -- INJECT TUNE BONUSES
    if GetResourceState('fish_tunes') == 'started' then
        local tuneData = exports['fish_tunes']:GetVehicleTunes(vehicle)
        if tuneData and tuneData.bonuses then
            local tBonus = tuneData.bonuses
            modifiedStats.top_speed = modifiedStats.top_speed * (1.0 + ((tBonus.top_speed or 0) * 0.5) / 100.0)
            modifiedStats.acceleration = modifiedStats.acceleration * (1.0 + ((tBonus.acceleration or 0) * 0.5) / 100.0)
            modifiedStats.handling = modifiedStats.handling * (1.0 + ((tBonus.handling or 0) * 0.5) / 100.0)
            modifiedStats.braking = modifiedStats.braking * (1.0 + ((tBonus.braking or 0) * 0.5) / 100.0)
        end
    end

    -- RECALCULATE FINAL SCORE WITH NEW STATS
    local finalScore = 0
    finalScore = finalScore + (modifiedStats.top_speed * Config.Weights.top_speed)
    finalScore = finalScore + (modifiedStats.acceleration * Config.Weights.acceleration)
    finalScore = finalScore + (modifiedStats.handling * Config.Weights.handling)
    finalScore = finalScore + (modifiedStats.braking * Config.Weights.braking)
    finalScore = math.floor(finalScore * 10)

    if subArchetype then
        finalScore = ApplySubArchetypeBonuses(finalScore, subArchetype)
    end

    local rank = GetRankFromScore(finalScore)

    return {
        rank = rank,
        score = finalScore,
        archetype = archetype,
        subArchetype = subArchetype,
        stats = modifiedStats,
        rawStats = stats.raw
    }
end

-- Export: Get vehicle archetype
function GetVehicleArchetype(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local storedData = vehicleData[plate]
    if storedData then
        return storedData.archetype, storedData.subArchetype
    end
    local stats = GetVehiclePerformanceStats(vehicle)
    if stats then
        return Config.VehicleClassMap[stats.class] or 'esportivo', nil
    end
    return 'esportivo', nil
end

-- Export: Get vehicle score
function GetVehicleScore(vehicle)
    local result = GetVehicleRank(vehicle)
    if result then return result.score end
    return 0
end

-- Export: Get full vehicle data
function GetVehicleData(vehicle)
    return GetVehicleRank(vehicle)
end

-- Get current vehicle the player is in
function GetCurrentPlayerVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return nil
end

-- Open the normalization NUI
function OpenNormalizer()
    local vehicle = GetCurrentPlayerVehicle()
    if not vehicle then
        ShowNotification('~r~You must be in a vehicle to use the normalizer.')
        return
    end

    currentVehicle = vehicle
    local stats = GetVehiclePerformanceStats(vehicle)
    local baseScore = CalculateBaseScore(stats)
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local storedData = vehicleData[plate]

    local currentArchetype = 'esportivo'
    local currentSubArchetype = nil
    if storedData then
        currentArchetype = storedData.archetype or 'esportivo'
        currentSubArchetype = storedData.subArchetype
    else
        currentArchetype = Config.VehicleClassMap[stats.class] or 'esportivo'
    end

    -- Build archetype cards data
    local archetypeCards = {}
    for key, arch in pairs(Config.Archetypes) do
        table.insert(archetypeCards, {
            key = key,
            label = arch.label,
            icon = arch.icon,
            description = arch.description,
            pros = arch.pros,
            cons = arch.cons,
            selected = (key == currentArchetype)
        })
    end

    local subArchetypeCards = {}
    for key, sub in pairs(Config.SubArchetypes) do
        table.insert(subArchetypeCards, {
            key = key,
            label = sub.label,
            icon = sub.icon,
            description = sub.description,
            statBonus = sub.statBonus,
            selected = (key == currentSubArchetype)
        })
    end

    local _, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, currentArchetype)

    local sendData = {
        action = 'openNormalizer',
        vehicleName = GetDisplayNameFromVehicleModel(stats.model),
        plate = plate,
        baseScore = baseScore,
        currentArchetype = currentArchetype,
        currentSubArchetype = currentSubArchetype,
        stats = modifiedStats or stats.normalized,
        rawStats = stats.raw,
        archetypes = archetypeCards,
        subArchetypes = subArchetypeCards,
        ranks = Config.Ranks
    }

    SetNuiFocus(true, true)
    SendNUIMessage(sendData)
    isNuiOpen = true
end

-- Check admin status on spawn
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Citizen.CreateThread(function()
        Citizen.Wait(1000)
        -- QBX: check via ace permissions
        TriggerServerEvent('fish_normalizer:checkAdminStatus')
    end)
end)

RegisterNetEvent('fish_normalizer:setAdminStatus')
AddEventHandler('fish_normalizer:setAdminStatus', function(status)
    isAdmin = status
end)

-- Register command (admin only)
RegisterCommand('normalize', function()
    if isNuiOpen then return end
    if not isAdmin then
        ShowNotification('~r~You do not have permission to use the normalizer.')
        return
    end
    OpenNormalizer()
end, false)

-- NUI Callback: Close
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isNuiOpen = false
    currentVehicle = nil
    cb('ok')
end)

-- NUI Callback: Select archetype
RegisterNUICallback('selectArchetype', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local archetype = data.archetype
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')

    if not vehicleData[plate] then
        vehicleData[plate] = {}
    end
    vehicleData[plate].archetype = archetype

    -- Recalculate stats
    local stats = GetVehiclePerformanceStats(currentVehicle)
    local baseScore = CalculateBaseScore(stats)
    local finalScore, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, archetype)

    if vehicleData[plate].subArchetype then
        finalScore = ApplySubArchetypeBonuses(finalScore, vehicleData[plate].subArchetype)
    end

    local rank = GetRankFromScore(finalScore)

    -- Save to server with vehicle net ID for state bag push
    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
    TriggerServerEvent('fish_normalizer:saveData', plate, vehicleData[plate], netId)

    cb(json.encode({
        score = finalScore,
        rank = rank,
        stats = modifiedStats or stats.normalized,
        archetype = archetype
    }))
end)

-- NUI Callback: Select sub-archetype
RegisterNUICallback('selectSubArchetype', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local subArchetype = data.subArchetype
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')

    if not vehicleData[plate] then
        vehicleData[plate] = {}
    end
    vehicleData[plate].subArchetype = subArchetype

    local stats = GetVehiclePerformanceStats(currentVehicle)
    local baseScore = CalculateBaseScore(stats)
    local archetype = vehicleData[plate].archetype or 'esportivo'
    local finalScore, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, archetype)
    finalScore = ApplySubArchetypeBonuses(finalScore, subArchetype)

    local rank = GetRankFromScore(finalScore)

    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
    TriggerServerEvent('fish_normalizer:saveData', plate, vehicleData[plate], netId)

    cb(json.encode({
        score = finalScore,
        rank = rank,
        stats = modifiedStats or stats.normalized,
        subArchetype = subArchetype
    }))
end)

-- NUI Callback: Confirm normalization
RegisterNUICallback('confirmNormalization', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    if vehicleData[plate] then
        vehicleData[plate].normalized = true
        vehicleData[plate].normalizedAt = GetCloudTimeAsInt()
        TriggerServerEvent('fish_normalizer:saveData', plate, vehicleData[plate])
        ShowNotification('~g~Vehicle normalized successfully!')
    end

    cb('ok')
end)

-- Receive vehicle data from server
RegisterNetEvent('fish_normalizer:receiveData')
AddEventHandler('fish_normalizer:receiveData', function(data)
    if data then
        vehicleData = data
    end
end)

-- Request data on spawn
Citizen.CreateThread(function()
    TriggerServerEvent('fish_normalizer:requestData')
end)

-- Utility notification
function ShowNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

-- ============================================================
-- Hold K: Show nearby vehicle ratings
-- Performance: 200ms poll, reads state bag first (no calc needed)
-- ============================================================
Citizen.CreateThread(function()
    while true do
        if IsControlPressed(0, 311) then -- K key
            Citizen.Wait(0)  -- render every frame WHILE held
            local ped    = PlayerPedId()
            local pos    = GetEntityCoords(ped)
            local vehicles = GetGamePool('CVehicle')

            for _, veh in ipairs(vehicles) do
                if DoesEntityExist(veh) then
                    local vehPos = GetEntityCoords(veh)
                    local dist   = #(pos - vehPos)
                    if dist < 40.0 then
                        -- Prefer state bag (synced from server)
                        local netId  = NetworkGetNetworkIdFromEntity(veh)
                        local bagScore = Entity(veh).state['fish:score']
                        local bagRank  = Entity(veh).state['fish:rank']

                        local displayScore = bagScore
                        local displayRank  = bagRank

                        -- Fall back to local calculation if no state bag
                        if not displayScore then
                            local result = GetVehicleRank(veh)
                            if result then
                                displayScore = result.score
                                displayRank  = result.rank and result.rank.name
                            end
                        end

                        if displayScore and displayRank then
                            -- Get rank color
                            local rankColor = '#FFFFFF'
                            for _, r in ipairs(Config.Ranks) do
                                if r.name == displayRank then rankColor = r.color; break end
                            end

                            local onScreen, screenX, screenY = World3dToScreen2d(vehPos.x, vehPos.y, vehPos.z + 1.5)
                            if onScreen then
                                local r = tonumber(rankColor:sub(2,3), 16) or 255
                                local g = tonumber(rankColor:sub(4,5), 16) or 255
                                local b = tonumber(rankColor:sub(6,7), 16) or 255
                                SetTextScale(0.38, 0.38)
                                SetTextFont(4)
                                SetTextProportional(true)
                                SetTextColour(r, g, b, 255)
                                SetTextDropshadow(2, 0, 0, 0, 200)
                                SetTextEdge(1, 0, 0, 0, 140)
                                SetTextDropShadow()
                                SetTextOutline()
                                SetTextEntry('STRING')
                                AddTextComponentString(displayRank .. ': ' .. displayScore)
                                DrawText(screenX, screenY)
                            end
                        end
                    end
                end
            end
        else
            Citizen.Wait(200)  -- idle poll when K not held
        end
    end
end)

-- Export: GetArchetypeModifier
exports('GetArchetypeModifier', function(archetypeKey, statKey)
    local archetype = Config.Archetypes[archetypeKey]
    if archetype and archetype.statModifiers then
        return archetype.statModifiers[statKey] or 1.0
    end
    return 1.0
end)
