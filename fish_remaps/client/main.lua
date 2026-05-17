-- fish_remaps: Client Main
local isNuiOpen = false
local currentVehicle = nil
local remapData = {}

-- Get current vehicle
function GetCurrentVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return nil
end

-- Calculate DNA inheritance blend
function CalculateDNABlend(originalArchetype, newArchetype, originalStats, newBaseStats)
    local inheritance = Config.DNAInheritance
    local blend = {}

    for _, stat in ipairs(Config.Stats) do
        local originalVal = originalStats[stat] or 50
        local newVal = newBaseStats[stat] or 50
        blend[stat] = (newVal * inheritance) + (originalVal * (1 - inheritance))
    end

    return blend
end

-- Apply stat adjustments on top of blended stats
function ApplyStatAdjustments(blendedStats, adjustments)
    local result = {}
    for _, stat in ipairs(Config.Stats) do
        local base = blendedStats[stat] or 50
        local adj = adjustments[stat] or 0
        result[stat] = math.max(0, math.min(100, base + adj))
    end
    return result
end

-- Export: Get vehicle remap data
function GetVehicleRemapData(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    return remapData[plate]
end

-- Export: Has remap
function HasRemap(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    return remapData[plate] ~= nil
end

-- Export: Get DNA inheritance info
function GetDNAInheritance(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local data = remapData[plate]
    if data then
        return {
            original = data.originalArchetype,
            current = data.currentArchetype,
            blend = data.blendedStats,
            inheritance = Config.DNAInheritance
        }
    end
    return nil
end

-- Open remap NUI
function OpenRemap()
    local vehicle = GetCurrentVehicle()
    if not vehicle then
        ShowNotification('~r~You must be in a vehicle to use the remap system.')
        return
    end

    currentVehicle = vehicle
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)

    -- Get normalizer data
    local normalizerData = exports['fish_normalizer']:GetVehicleData(vehicle)
    local currentArchetype = 'esportivo'
    local currentSubArchetype = nil
    local baseStats = {}

    if normalizerData then
        currentArchetype = normalizerData.archetype or 'esportivo'
        currentSubArchetype = normalizerData.subArchetype
        baseStats = normalizerData.stats or {}
    end

    -- Check for existing remap
    local existing = remapData[plate]
    local adjustments = {}
    if existing then
        adjustments = existing.stat_adjustments or existing.adjustments or {}
        currentArchetype = existing.current_archetype or existing.currentArchetype or currentArchetype
        currentSubArchetype = existing.sub_archetype or existing.currentSubArchetype or currentSubArchetype
    end

    -- Get player balance
    local balance = 0
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    if success and playerData and playerData.money then
        balance = (playerData.money.bank or 0) + (playerData.money.cash or 0)
    end

    local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    local sendData = {
        action = 'openRemap',
        vehicleName = displayName,
        plate = plate,
        vehicleNetId = vehicleNetId,
        originalArchetype = currentArchetype,
        currentArchetype = currentArchetype,
        subArchetype = currentSubArchetype,
        currentSubArchetype = currentSubArchetype,
        baseStats = baseStats,
        adjustments = adjustments,
        maxAdjustment = Config.MaxStatAdjustment,
        dnaInheritance = Config.DNAInheritance,
        stats = Config.Stats,
        statLabels = Config.StatLabels,
        statColors = Config.StatColors,
        existingRemap = existing ~= nil,
        balance = balance,
        costs = Config.Costs or {},
        stage = existing and existing.stage or 0,
        dynoSettings = existing and existing.dyno or nil,
        transSettings = existing and { mode = existing.trans_mode or existing.transMode, gearPreset = existing.gear_preset or existing.gearPreset } or nil
    }

    SetNuiFocus(true, true)
    SendNUIMessage(sendData)
    isNuiOpen = true
end

-- Register command
RegisterCommand('remap', function()
    if isNuiOpen then return end
    OpenRemap()
end, false)

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isNuiOpen = false
    currentVehicle = nil
    cb('ok')
end)

RegisterNUICallback('confirmRemap', function(data, cb)
    if not data.plate then cb('error'); return end
    TriggerServerEvent('fish_remaps:confirmRemap', data.plate, data.data, data.vehicleNetId)
    isNuiOpen = false
    SetNuiFocus(false, false)
    currentVehicle = nil
    cb('ok')
end)

RegisterNUICallback('previewAdjustment', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local normalizerData = exports['fish_normalizer']:GetVehicleData(currentVehicle)

    local originalArchetype = 'esportivo'
    local originalStats = {}

    if normalizerData then
        originalArchetype = normalizerData.archetype or 'esportivo'
        originalStats = normalizerData.stats or {}
    end

    local newArchetype = data.archetype or originalArchetype
    local adjustments = data.adjustments or {}

    -- Get new archetype base stats
    local newBaseStats = {}
    for _, stat in ipairs(Config.Stats) do
        local mod = exports['fish_normalizer']:GetArchetypeModifier(newArchetype, stat)
        newBaseStats[stat] = (originalStats[stat] or 50) * (mod or 1.0)
    end

    -- Calculate DNA blend
    local blended = CalculateDNABlend(originalArchetype, newArchetype, originalStats, newBaseStats)

    -- Apply adjustments
    local final = ApplyStatAdjustments(blended, adjustments)

    -- Calculate score preview
    local rMult = {
        top_speed = 0.8 + (final.top_speed or 50) / 100 * 0.4,
        acceleration = 0.8 + (final.acceleration or 50) / 100 * 0.4,
        handling = 0.8 + (final.handling or 50) / 100 * 0.4,
        braking = 0.8 + (final.braking or 50) / 100 * 0.4
    }

    local tempStats = {
        top_speed = (newBaseStats.top_speed or 50) * rMult.top_speed,
        acceleration = (newBaseStats.acceleration or 50) * rMult.acceleration,
        handling = (newBaseStats.handling or 50) * rMult.handling,
        braking = (newBaseStats.braking or 50) * rMult.braking
    }

    local score = 0
    score = score + (tempStats.top_speed * 0.30)
    score = score + (tempStats.acceleration * 0.30)
    score = score + (tempStats.handling * 0.25)
    score = score + (tempStats.braking * 0.15)
    score = math.floor(score * 10)

    if data.subArchetype then
        local success, result = pcall(function() return exports['fish_normalizer']:ApplySubArchetypeBonuses(score, data.subArchetype) end)
        if success and result then score = result end
    end

    local rankData = nil
    local success, result = pcall(function() return exports['fish_normalizer']:GetRankFromScore(score) end)
    if success and result then rankData = result end

    cb({
        blended = blended,
        final = final,
        original = originalStats,
        score = score,
        rank = rankData
    })
end)

RegisterNUICallback('changeArchetype', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local normalizerData = exports['fish_normalizer']:GetVehicleData(currentVehicle)

    local originalArchetype = 'esportivo'
    local originalStats = {}

    if normalizerData then
        originalArchetype = normalizerData.archetype or 'esportivo'
        originalStats = normalizerData.stats or {}
    end

    local newArchetype = data.archetype

    -- Get new archetype base stats (using modifiers from normalizer config)
    local newBaseStats = {}
    for _, stat in ipairs(Config.Stats) do
        local mod = 1.0
        -- Try to get modifier from normalizer
        local success, result = pcall(function()
            return exports['fish_normalizer']:GetArchetypeModifier(newArchetype, stat)
        end)
        if success and result then mod = result end
        newBaseStats[stat] = (originalStats[stat] or 50) * mod
    end

    local blended = CalculateDNABlend(originalArchetype, newArchetype, originalStats, newBaseStats)

    cb({
        blended = blended,
        original = originalStats,
        originalArchetype = originalArchetype,
        newArchetype = newArchetype
    })
end)


RegisterNUICallback('saveDyno', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
    TriggerServerEvent('fish_remaps:saveDyno', plate, data, netId)
    cb('ok')
end)

RegisterNUICallback('saveTransmission', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
    TriggerServerEvent('fish_remaps:saveTransmission', plate, data, netId)
    cb('ok')
end)

-- JS calls these names (aliases)
RegisterNUICallback('applyDyno', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
    TriggerServerEvent('fish_remaps:saveDyno', plate, data, netId)
    cb('ok')
end)

RegisterNUICallback('applyTransMode', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
    TriggerServerEvent('fish_remaps:saveTransmission', plate, { mode = data.mode }, netId)
    cb('ok')
end)

RegisterNUICallback('applyGearRatio', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
    TriggerServerEvent('fish_remaps:saveTransmission', plate, { gearPreset = data.preset }, netId)
    cb('ok')
end)

RegisterNUICallback('nuiReady', function(data, cb)
    cb('ok')
end)

-- Receive data from server
RegisterNetEvent('fish_remaps:receiveData')
AddEventHandler('fish_remaps:receiveData', function(data)
    if data then
        remapData = data
    end
end)

-- Request all remap data on spawn (one event for all plates)
Citizen.CreateThread(function()
    TriggerServerEvent('fish_remaps:requestAllData')
end)

-- Item usage: remap chip
RegisterNetEvent('fish_remaps:useRemapChip')
AddEventHandler('fish_remaps:useRemapChip', function()
    OpenRemap()
end)

-- Notification from server (server sends table {type, message})
RegisterNetEvent('fish_remaps:notify')
AddEventHandler('fish_remaps:notify', function(data)
    local msg = ''
    local msgType = 'info'
    if type(data) == 'table' then
        msg = data.message or ''
        msgType = data.type or 'info'
    else
        msg = tostring(data)
    end
    if isNuiOpen then
        SendNUIMessage({ action = 'notification', message = msg, type = msgType })
    end
    ShowNotification(msg)
end)

-- Remap applied confirmation (convert snake_case server data to camelCase for client cache)
RegisterNetEvent('fish_remaps:remapApplied')
AddEventHandler('fish_remaps:remapApplied', function(plate, data)
    remapData[plate] = {
        originalArchetype   = data.original_archetype,
        currentArchetype    = data.current_archetype,
        currentSubArchetype = data.sub_archetype,
        adjustments         = data.stat_adjustments or {},
        blendedStats        = data.blended_stats or {},
        finalStats          = data.final_stats or {},
        stage               = data.stage or 0,
    }
end)

function ShowNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
