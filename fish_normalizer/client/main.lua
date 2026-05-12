-- fish_normalizer: Client Main
local isNuiOpen = false
local currentVehicle = nil
local vehicleData = {}

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

    local baseScore = CalculateBaseScore(stats)

    -- Check for stored archetype
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

    local finalScore, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, archetype)
    if subArchetype then
        finalScore = ApplySubArchetypeBonuses(finalScore, subArchetype)
    end

    local rank = GetRankFromScore(finalScore)

    return {
        rank = rank,
        score = finalScore,
        archetype = archetype,
        subArchetype = subArchetype,
        stats = modifiedStats or stats.normalized,
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

-- Register command
RegisterCommand('normalize', function()
    if isNuiOpen then return end
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

    -- Save to server
    TriggerServerEvent('fish_normalizer:saveData', plate, vehicleData[plate])

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

    TriggerServerEvent('fish_normalizer:saveData', plate, vehicleData[plate])

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

-- Hold K to show nearby ratings
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlPressed(0, 311) then -- K key
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local vehicles = GetGamePool('CVehicle')

            for _, veh in ipairs(vehicles) do
                local vehPos = GetEntityCoords(veh)
                local dist = #(pos - vehPos)
                if dist < 30.0 and DoesEntityExist(veh) then
                    local result = GetVehicleRank(veh)
                    if result then
                        local screenX, screenY = World3dToScreen2d(vehPos.x, vehPos.y, vehPos.z + 1.5)
                        if screenX and screenY then
                            SetTextScale(0.35, 0.35)
                            SetTextFont(4)
                            SetTextProportional(true)
                            SetTextColour(
                                tonumber(result.rank.color:sub(2,3), 16),
                                tonumber(result.rank.color:sub(4,5), 16),
                                tonumber(result.rank.color:sub(6,7), 16),
                                255
                            )
                            SetTextDropshadow(2, 0, 0, 0, 255)
                            SetTextEdge(2, 0, 0, 0, 150)
                            SetTextDropShadow()
                            SetTextOutline()
                            SetTextEntry('STRING')
                            AddTextComponentString(result.rank.name .. ': ' .. result.score)
                            DrawText(screenX, screenY)
                        end
                    end
                end
            end
        end
    end
end)
