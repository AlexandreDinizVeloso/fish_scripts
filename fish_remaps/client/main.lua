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
        adjustments = existing.adjustments or {}
        currentArchetype = existing.currentArchetype or currentArchetype
        currentSubArchetype = existing.currentSubArchetype or currentSubArchetype
    end

    local sendData = {
        action = 'openRemap',
        vehicleName = displayName,
        plate = plate,
        originalArchetype = existing and existing.originalArchetype or currentArchetype,
        currentArchetype = currentArchetype,
        currentSubArchetype = currentSubArchetype,
        baseStats = baseStats,
        adjustments = adjustments,
        maxAdjustment = Config.MaxStatAdjustment,
        dnaInheritance = Config.DNAInheritance,
        stats = Config.Stats,
        statLabels = Config.StatLabels,
        statColors = Config.StatColors,
        existingRemap = existing ~= nil
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

    cb({
        blended = blended,
        final = final,
        original = originalStats
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

RegisterNUICallback('confirmRemap', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local normalizerData = exports['fish_normalizer']:GetVehicleData(currentVehicle)

    local originalArchetype = 'esportivo'
    if normalizerData then
        originalArchetype = normalizerData.archetype or 'esportivo'
    end

    -- Check if remap already exists - preserve original archetype
    local existing = remapData[plate]
    local preservedOriginalArchetype = originalArchetype
    if existing and existing.originalArchetype then
        preservedOriginalArchetype = existing.originalArchetype
    end

    local remapInfo = {
        originalArchetype = preservedOriginalArchetype, -- Always preserve the original
        currentArchetype = data.archetype or originalArchetype,
        currentSubArchetype = data.subArchetype,
        adjustments = data.adjustments or {},
        blendedStats = data.blendedStats or {},
        finalStats = data.finalStats or {},
        remapTime = GetCloudTimeAsInt(),
        owner = GetPlayerServerId(PlayerId())
    }

    remapData[plate] = remapInfo
    TriggerServerEvent('fish_remaps:saveRemap', plate, remapInfo)
    
    -- Trigger normalizer to apply remap performance changes
    TriggerEvent('fish_remaps:performanceUpdated', plate, remapInfo)

    ShowNotification('~g~Vehicle remap applied successfully!')
    cb('ok')
end)

-- Receive data from server
RegisterNetEvent('fish_remaps:receiveData')
AddEventHandler('fish_remaps:receiveData', function(data)
    if data then
        remapData = data
    end
end)

-- Request data on spawn
Citizen.CreateThread(function()
    TriggerServerEvent('fish_remaps:requestData')
end)

-- Item usage: remap chip
RegisterNetEvent('fish_remaps:useRemapChip')
AddEventHandler('fish_remaps:useRemapChip', function()
    OpenRemap()
end)

function ShowNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
