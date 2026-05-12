-- fish_remaps: Server Data Management
local DataStore = {}

function DataStore.Init()
    local data = LoadResourceFile(GetCurrentResourceName(), 'server/remap_data.json')
    if data then return json.decode(data) or {} end
    return {}
end

function DataStore.Save(data)
    SaveResourceFile(GetCurrentResourceName(), 'server/remap_data.json', json.encode(data), -1)
end

function DataStore.Get(data, plate)
    return data[plate]
end

function DataStore.Set(data, plate, info)
    data[plate] = info
    DataStore.Save(data)
    return true
end

function DataStore.Delete(data, plate)
    data[plate] = nil
    DataStore.Save(data)
    return true
end

function DataStore.GetByOwner(data, owner)
    local results = {}
    for plate, info in pairs(data) do
        if info.owner == owner then
            results[plate] = info
        end
    end
    return results
end

return DataStore
