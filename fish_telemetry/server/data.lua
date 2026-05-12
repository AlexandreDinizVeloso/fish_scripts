--[[
    FISH Telemetry - Server Data Module
    JSON persistence for telemetry data
]]

local dataFile = 'fish_telemetry_data.json'

-- Save telemetry data to JSON file
function SaveTelemetryData()
    local dataStr = json.encode(telemetryData)
    SaveResourceFile(GetCurrentResourceName(), dataFile, dataStr, -1)
end

-- Load telemetry data from JSON file
function LoadTelemetryData()
    local dataStr = LoadResourceFile(GetCurrentResourceName(), dataFile)
    if dataStr and dataStr ~= '' then
        local success, data = pcall(json.decode, dataStr)
        if success and data then
            telemetryData = data
        else
            print('[FISH Telemetry] Error loading data file: ' .. tostring(data))
            telemetryData = {}
        end
    else
        telemetryData = {}
    end
end

-- Initialize: load data on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LoadTelemetryData()
        print('[FISH Telemetry] Loaded telemetry data for ' .. CountKeys(telemetryData) .. ' vehicles')
    end
end)

-- Save on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SaveTelemetryData()
        print('[FISH Telemetry] Saved telemetry data')
    end
end)

-- Utility: count keys in table
function CountKeys(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end
