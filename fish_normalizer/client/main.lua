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
        local attempts = 0
        while not DoesEntityExist(veh) and attempts < 20 do
            Citizen.Wait(100)
            veh = NetworkGetEntityFromNetworkId(netId)
            attempts = attempts + 1
        end
        if DoesEntityExist(veh) then
            -- Use the shared ApplyHandlingToVehicle export
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

-- ============================================================
-- Get vehicle performance stats from FiveM natives (for NUI preview)
-- ============================================================
function GetVehiclePerformanceStats(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model):lower()
    local className = GetVehicleClass(vehicle)

    local topSpeed = GetVehicleModelMaxSpeed(model) * 3.6
    local accel = GetVehicleModelAcceleration(model)
    local braking = GetVehicleModelMaxBraking(model)
    local traction = GetVehicleModelMaxTraction(model)

    local normalizedTopSpeed = math.min(100, (topSpeed / 250.0) * 100)
    local normalizedAccel = math.min(100, (accel / 0.55) * 100)
    local normalizedBraking = math.min(100, (braking / 0.85) * 100)
    local normalizedTraction = math.min(100, (traction / 2.80) * 100)

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

-- ============================================================
-- Calculate base score from normalized stats (NUI preview)
-- ============================================================
function CalculateBaseScore(stats)
    if not stats then return 0 end

    local score = 0
    score = score + (stats.normalized.top_speed * Config.Weights.top_speed)
    score = score + (stats.normalized.acceleration * Config.Weights.acceleration)
    score = score + (stats.normalized.handling * Config.Weights.handling)
    score = score + (stats.normalized.braking * Config.Weights.braking)

    return math.floor(score * 10)
end

-- Apply archetype modifiers to score (NUI preview)
function ApplyArchetypeModifiers(baseScore, stats, archetypeKey)
    local archetype = Config.Archetypes[archetypeKey]
    if not archetype then return baseScore, stats end

    local modifiedStats = {}
    for k, v in pairs(stats.normalized) do
        local modifier = archetype.statModifiers[k] or 1.0
        modifiedStats[k] = v * modifier
    end

    local modifiedScore = 0
    modifiedScore = modifiedScore + (modifiedStats.top_speed * Config.Weights.top_speed)
    modifiedScore = modifiedScore + (modifiedStats.acceleration * Config.Weights.acceleration)
    modifiedScore = modifiedScore + (modifiedStats.handling * Config.Weights.handling)
    modifiedScore = modifiedScore + (modifiedStats.braking * Config.Weights.braking)
    modifiedScore = math.floor(modifiedScore * 10)

    local bias = archetype.scoreBias
    modifiedScore = modifiedScore + (bias.top_speed or 0)
    modifiedScore = modifiedScore + (bias.acceleration or 0)
    modifiedScore = modifiedScore + (bias.handling or 0)
    modifiedScore = modifiedScore + (bias.braking or 0)

    return math.max(0, math.min(1000, modifiedScore)), modifiedStats
end

-- Apply sub-archetype bonuses (NUI preview)
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
    return Config.Ranks[1]
end

-- ============================================================
-- Get vehicle rank (reads from state bag first, falls back to local calc)
-- ============================================================
function GetVehicleRank(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')

    -- Try state bag first (server-authoritative)
    local bagScore = Entity(vehicle).state['fish:score']
    local bagRank = Entity(vehicle).state['fish:rank']
    local bagArchetype = Entity(vehicle).state['fish:archetype']

    if bagScore and bagScore > 0 then
        local rankObj = nil
        for _, r in ipairs(Config.Ranks) do
            if r.name == bagRank then rankObj = r; break end
        end
        return {
            rank = rankObj or Config.Ranks[1],
            score = bagScore,
            archetype = bagArchetype or 'esportivo',
            subArchetype = nil,
            stats = {},
            rawStats = {}
        }
    end

    -- Fallback: calculate locally (should be rare - only for non-normalized vehicles)
    local stats = GetVehiclePerformanceStats(vehicle)
    if not stats then return nil end

    local storedData = vehicleData[plate]
    local archetype = 'esportivo'
    local subArchetype = nil

    if storedData then
        archetype = storedData.archetype or 'esportivo'
        subArchetype = storedData.subArchetype
    else
        archetype = Config.VehicleClassMap[stats.class] or 'esportivo'
    end

    local baseScore = CalculateBaseScore(stats)
    local naturalScore, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, archetype)
    
    if subArchetype then
        naturalScore = ApplySubArchetypeBonuses(naturalScore, subArchetype)
    end

    local rank = GetRankFromScore(naturalScore)

    return {
        rank = rank,
        score = naturalScore,
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
    local bagScore = Entity(vehicle).state['fish:score']
    if bagScore and bagScore > 0 then return bagScore end
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

-- ============================================================
-- Open the normalization NUI
-- ============================================================
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
        TriggerServerEvent('fish_normalizer:checkAdminStatus')
    end)
end)

RegisterNetEvent('fish_normalizer:setAdminStatus')
AddEventHandler('fish_normalizer:setAdminStatus', function(status)
    isAdmin = status
end)

-- Register command (open to all players)
RegisterCommand('normalize', function()
    if isNuiOpen then return end
    OpenNormalizer()
end, false)

-- ============================================================
-- NUI Callbacks
-- ============================================================

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isNuiOpen = false
    currentVehicle = nil
    cb('ok')
end)

RegisterNUICallback('previewStats', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local archetype = data.archetype or 'esportivo'
    local subArchetype = data.subArchetype
    local overrideScore = data.overrideScore

    local stats = GetVehiclePerformanceStats(currentVehicle)
    local baseScore = CalculateBaseScore(stats)
    local finalScore, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, archetype)

    if subArchetype then
        finalScore = ApplySubArchetypeBonuses(finalScore, subArchetype)
    end

    -- If an override score is provided, scale stats to match
    if overrideScore and overrideScore ~= finalScore then
        local ratio = overrideScore / math.max(1, finalScore)
        modifiedStats.top_speed = math.min(100, modifiedStats.top_speed * ratio)
        modifiedStats.acceleration = math.min(100, modifiedStats.acceleration * ratio)
        modifiedStats.handling = math.min(100, modifiedStats.handling * ratio)
        modifiedStats.braking = math.min(100, modifiedStats.braking * ratio)
        finalScore = overrideScore
    end

    local rank = GetRankFromScore(finalScore)

    cb({
        score = finalScore,
        rank = rank,
        stats = modifiedStats,
    })
end)

RegisterNUICallback('saveData', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    if not vehicleData[plate] then
        vehicleData[plate] = {}
    end

    vehicleData[plate].archetype = data.archetype
    vehicleData[plate].subArchetype = data.subArchetype
    vehicleData[plate].rank = data.rank
    vehicleData[plate].score = data.score
    vehicleData[plate].normalized = true
    vehicleData[plate].normalizedAt = GetCloudTimeAsInt()

    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
    -- Send to server for authoritative processing and state bag push
    TriggerServerEvent('fish_normalizer:saveData', plate, vehicleData[plate], netId)
    ShowNotification('~g~Vehicle normalized successfully!')

    isNuiOpen = false
    SetNuiFocus(false, false)
    currentVehicle = nil

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
-- Hold K: Show nearby vehicle ratings (reads state bag)
-- ============================================================
Citizen.CreateThread(function()
    while true do
        if IsControlPressed(0, 311) then -- K key
            Citizen.Wait(0)
            local ped    = PlayerPedId()
            local pos    = GetEntityCoords(ped)
            local vehicles = GetGamePool('CVehicle')

            for _, veh in ipairs(vehicles) do
                if DoesEntityExist(veh) then
                    local vehPos = GetEntityCoords(veh)
                    local dist   = #(pos - vehPos)
                    if dist < 40.0 then
                        local displayScore = nil
                        local displayRank  = nil
                        local rankColor    = '#8B8B8B'

                        -- Read state bag (server-authoritative)
                        local bagScore = Entity(veh).state['fish:score']
                        local bagRank  = Entity(veh).state['fish:rank']

                        if bagScore and bagScore > 0 and bagRank then
                            displayScore = bagScore
                            displayRank  = bagRank
                            for _, r in ipairs(Config.Ranks) do
                                if r.name == displayRank then rankColor = r.color; break end
                            end
                        else
                            -- Calculate locally for non-normalized vehicles
                            local result = GetVehicleRank(veh)
                            if result and result.score then
                                displayScore = result.score
                                displayRank  = result.rank and result.rank.name or '?'
                                rankColor    = (result.rank and result.rank.color) or '#8B8B8B'
                            end
                        end

                        if displayScore and displayRank then
                            local onScreen, screenX, screenY = World3dToScreen2d(vehPos.x, vehPos.y, vehPos.z + 1.5)
                            if onScreen then
                                local cr = tonumber(rankColor:sub(2,3), 16) or 139
                                local cg = tonumber(rankColor:sub(4,5), 16) or 139
                                local cb = tonumber(rankColor:sub(6,7), 16) or 139
                                SetTextScale(0.38, 0.38)
                                SetTextFont(4)
                                SetTextProportional(true)
                                SetTextColour(cr, cg, cb, 255)
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
            Citizen.Wait(200)
        end
    end
end)

-- Export archetype modifier lookup
function GetArchetypeModifier(archetypeKey, statKey)
    local archetype = Config.Archetypes[archetypeKey]
    if archetype and archetype.statModifiers then
        return archetype.statModifiers[statKey] or 1.0
    end
    return 1.0
end