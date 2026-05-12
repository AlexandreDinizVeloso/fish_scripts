-- fish_normalizer: Server Main
local vehicleDataCache = {}

-- Load vehicle data from file
function LoadVehicleData()
    local data = LoadResourceFile(GetCurrentResourceName(), 'server/vehicle_data.json')
    if data then
        vehicleDataCache = json.decode(data) or {}
    end
end

-- Save vehicle data to file
function SaveVehicleDataToFile()
    SaveResourceFile(GetCurrentResourceName(), 'server/vehicle_data.json', json.encode(vehicleDataCache), -1)
end

-- On resource start, load data
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        LoadVehicleData()
        print('[fish_normalizer] Vehicle data loaded. ' .. CountTable(vehicleDataCache) .. ' vehicles normalized.')
    end
end)

-- Count table entries
function CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Player requests their vehicle data
RegisterNetEvent('fish_normalizer:requestData')
AddEventHandler('fish_normalizer:requestData', function()
    local src = source
    TriggerClientEvent('fish_normalizer:receiveData', src, vehicleDataCache)
end)

-- Save vehicle normalization data
RegisterNetEvent('fish_normalizer:saveData')
AddEventHandler('fish_normalizer:saveData', function(plate, data)
    local src = source
    if not plate or not data then return end

    vehicleDataCache[plate] = data
    vehicleDataCache[plate].owner = GetPlayerIdentifier(src, 0)
    vehicleDataCache[plate].lastUpdated = os.time()

    SaveVehicleDataToFile()

    print('[fish_normalizer] Vehicle ' .. plate .. ' normalized by ' .. GetPlayerName(src))
end)

-- Server export: Get vehicle rank
function GetVehicleRankServer(plate)
    if vehicleDataCache[plate] then
        return vehicleDataCache[plate]
    end
    return nil
end

-- Server export: Get vehicle data
function GetVehicleDataServer(plate)
    return vehicleDataCache[plate]
end

-- Server export: Save vehicle data (for other resources)
function SaveVehicleData(plate, data)
    if not plate or not data then return false end
    vehicleDataCache[plate] = data
    SaveVehicleDataToFile()
    return true
end

-- Server export: Get all normalized vehicles
function GetAllNormalizedVehicles()
    return vehicleDataCache
end

-- Player dropped cleanup (optional - keep data persistent)
AddEventHandler('playerDropped', function(reason)
    -- Data persists in file, no cleanup needed
end)
