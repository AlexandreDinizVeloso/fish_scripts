-- fish_remaps: Server Main
local remapDataCache = {}

function LoadRemapData()
    local data = LoadResourceFile(GetCurrentResourceName(), 'server/remap_data.json')
    if data then
        remapDataCache = json.decode(data) or {}
    end
end

function SaveRemapDataToFile()
    SaveResourceFile(GetCurrentResourceName(), 'server/remap_data.json', json.encode(remapDataCache), -1)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        LoadRemapData()
        print('[fish_remaps] Remap data loaded.')
    end
end)

RegisterNetEvent('fish_remaps:requestData')
AddEventHandler('fish_remaps:requestData', function()
    local src = source
    TriggerClientEvent('fish_remaps:receiveData', src, remapDataCache)
end)

RegisterNetEvent('fish_remaps:saveRemap')
AddEventHandler('fish_remaps:saveRemap', function(plate, data)
    local src = source
    if not plate or not data then return end

    remapDataCache[plate] = data
    remapDataCache[plate].owner = GetPlayerIdentifier(src, 0)
    remapDataCache[plate].lastUpdated = os.time()

    SaveRemapDataToFile()
    print('[fish_remaps] Vehicle ' .. plate .. ' remapped by ' .. GetPlayerName(src))
end)

-- ============================================================
-- Cost-based confirm remap
-- ============================================================

RegisterNetEvent('fish_remaps:confirmRemapServer')
AddEventHandler('fish_remaps:confirmRemapServer', function(plate, data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local costs = Config.Costs or {}
    local totalCost = 0

    -- Calculate cost based on what changed
    local existing = remapDataCache[plate]

    if data.archetype and (not existing or existing.currentArchetype ~= data.archetype) then
        totalCost = totalCost + (costs.archetype_change or 15000)
    end

    if data.subArchetype and (not existing or existing.currentSubArchetype ~= data.subArchetype) then
        totalCost = totalCost + (costs.subarchetype_change or 5000)
    end

    -- Stat adjustments cost
    if data.adjustments then
        local totalPoints = 0
        for _, val in pairs(data.adjustments) do
            totalPoints = totalPoints + math.abs(val or 0)
        end
        totalCost = totalCost + (totalPoints * (costs.adjustment_per_point or 1000))
    end

    if totalCost > 0 then
        if not player.Functions.RemoveMoney('bank', totalCost, 'vehicle-remap') then
            TriggerClientEvent('fish_remaps:notification', src, 'Not enough money. Need $' .. totalCost, 'error')
            return
        end
    end

    -- Save remap data
    remapDataCache[plate] = data
    remapDataCache[plate].owner = GetPlayerIdentifier(src, 0)
    remapDataCache[plate].lastUpdated = os.time()
    remapDataCache[plate].totalCost = totalCost

    SaveRemapDataToFile()

    TriggerClientEvent('fish_remaps:notification', src, 'Remap applied! Cost: $' .. totalCost, 'success')
    TriggerClientEvent('fish_remaps:remapApplied', src, plate, data)
end)

-- ============================================================
-- Dyno save with cost
-- ============================================================

RegisterNetEvent('fish_remaps:saveDynoServer')
AddEventHandler('fish_remaps:saveDynoServer', function(plate, dynoData)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local cost = Config.Costs and Config.Costs.dyno_flash or 2000
    if not player.Functions.RemoveMoney('bank', cost, 'dyno-flash') then
        TriggerClientEvent('fish_remaps:notification', src, 'Not enough money. Need $' .. cost, 'error')
        return
    end

    if not remapDataCache[plate] then remapDataCache[plate] = {} end
    remapDataCache[plate].dyno = dynoData
    remapDataCache[plate].lastUpdated = os.time()

    SaveRemapDataToFile()
    TriggerClientEvent('fish_remaps:notification', src, 'ECU Flash applied! Cost: $' .. cost, 'success')
end)

-- ============================================================
-- Transmission save with cost
-- ============================================================

RegisterNetEvent('fish_remaps:saveTransmissionServer')
AddEventHandler('fish_remaps:saveTransmissionServer', function(plate, transData)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local costs = Config.Costs or {}
    local cost = 0
    if transData.mode then cost = cost + (costs.trans_mode or 3000) end
    if transData.gearPreset then cost = cost + (costs.gear_ratio or 5000) end

    if cost > 0 then
        if not player.Functions.RemoveMoney('bank', cost, 'transmission-tune') then
            TriggerClientEvent('fish_remaps:notification', src, 'Not enough money. Need $' .. cost, 'error')
            return
        end
    end

    if not remapDataCache[plate] then remapDataCache[plate] = {} end
    if transData.mode then remapDataCache[plate].transMode = transData.mode end
    if transData.gearPreset then remapDataCache[plate].gearPreset = transData.gearPreset end
    remapDataCache[plate].lastUpdated = os.time()

    SaveRemapDataToFile()
    TriggerClientEvent('fish_remaps:notification', src, 'Transmission updated! Cost: $' .. cost, 'success')
end)

function GetVehicleRemapDataServer(plate)
    return remapDataCache[plate]
end

function SaveRemapData(plate, data)
    if not plate or not data then return false end
    remapDataCache[plate] = data
    SaveRemapDataToFile()
    return true
end
