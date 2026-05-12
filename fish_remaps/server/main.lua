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

function GetVehicleRemapDataServer(plate)
    return remapDataCache[plate]
end

function SaveRemapData(plate, data)
    if not plate or not data then return false end
    remapDataCache[plate] = data
    SaveRemapDataToFile()
    return true
end
