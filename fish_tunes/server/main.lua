-- fish_tunes: Server Main
local tunesDataCache = {}

function LoadTunesData()
    local data = LoadResourceFile(GetCurrentResourceName(), 'server/tunes_data.json')
    if data then tunesDataCache = json.decode(data) or {} end
end

function SaveTunesDataToFile()
    SaveResourceFile(GetCurrentResourceName(), 'server/tunes_data.json', json.encode(tunesDataCache), -1)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        LoadTunesData()
        print('[fish_tunes] Tunes data loaded.')
    end
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
    tunesDataCache[plate].lastUpdated = GetCloudTimeAsInt()
    SaveTunesDataToFile()
    print('[fish_tunes] Vehicle ' .. plate .. ' tuned by ' .. GetPlayerName(src))
end)

function GetVehicleTunesServer(plate)
    return tunesDataCache[plate]
end

function SaveTunesData(plate, data)
    if not plate or not data then return false end
    tunesDataCache[plate] = data
    SaveTunesDataToFile()
    return true
end
