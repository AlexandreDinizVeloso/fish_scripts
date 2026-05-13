--[[
    FISH Telemetry - NUI Callbacks
    Handles all NUI interactions
]]

-- Close NUI
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    cb('ok')
end)

-- Start recording from NUI
RegisterNUICallback('startRecording', function(data, cb)
    StartRecording()
    cb('ok')
end)

-- Stop recording from NUI
RegisterNUICallback('stopRecording', function(data, cb)
    StopRecording()
    cb('ok')
end)

-- Clear data from NUI
RegisterNUICallback('clearData', function(data, cb)
    bestResults = nil
    lastResults = nil
    vehicleVersions = {}
    currentVersion = 1
    
    -- Reset recording data safely
    pcall(function()
        currentData = {
            speeds = {},
            timestamps = {},
            gforces = {},
            accelData = {}
        }
        milestone_0_100 = nil
        milestone_0_200 = nil
        milestone_100_0 = nil
        milestone_200_0 = nil
        brakingFrom100 = false
        brakingFrom200 = false
        brakeStartSpeed = 0
        brakeStartTime = 0
        maxLateralG = 0.0
        previousSpeed = 0
    end)

    TriggerServerEvent('fish_telemetry:clearData')

    SendNUIMessage({
        type = 'dataCleared'
    })

    ShowNotification("~y~Telemetry data cleared.")
    cb('ok')
end)

-- Copy results to clipboard
RegisterNUICallback('copyResults', function(data, cb)
    local result = data.result or lastResults
    if not result then
        cb({ success = false, message = 'No data to copy' })
        return
    end

    local text = string.format(
        "═══ FISH TELEMETRY REPORT ═══\n" ..
        "Vehicle: %s\n" ..
        "Plate: %s\n" ..
        "Version: %d\n" ..
        "─────────────────────────────\n" ..
        "Max Speed: %.1f km/h\n" ..
        "0-100 km/h: %s\n" ..
        "0-200 km/h: %s\n" ..
        "100-0 km/h: %s\n" ..
        "200-0 km/h: %s\n" ..
        "Lateral G: %.2f G\n" ..
        "Duration: %.1f s\n" ..
        "═══════════════════════════",
        result.vehicle_name or 'Unknown',
        result.plate or 'Unknown',
        result.version or 1,
        result.max_speed or 0,
        result.zero_to_100 and string.format("%.2f s", result.zero_to_100) or 'N/A',
        result.zero_to_200 and string.format("%.2f s", result.zero_to_200) or 'N/A',
        result.hundred_to_zero and string.format("%.2f s", result.hundred_to_zero) or 'N/A',
        result.two_hundred_to_zero and string.format("%.2f s", result.two_hundred_to_zero) or 'N/A',
        result.lateral_gforce or 0,
        result.duration or 0
    )

    SendNUIMessage({
        type = 'copySuccess',
        text = text
    })

    cb({ success = true })
end)

-- Get specific version results
RegisterNUICallback('getVersionResults', function(data, cb)
    local version = data.version
    if version and vehicleVersions[version] then
        cb({ success = true, result = vehicleVersions[version] })
    else
        cb({ success = false, message = 'Version not found' })
    end
end)

-- Toggle NUI visibility
function ToggleNUI()
    nuiOpen = not nuiOpen
    SetNuiFocus(nuiOpen, nuiOpen)

    if nuiOpen then
        local veh = GetCurrentVehicle()
        local vehicleName = 'No Vehicle'
        local plate = ''
        
        if veh then
            pcall(function()
                vehicleName = GetVehicleDisplayName(veh) or 'Vehicle'
                plate = GetVehiclePlate(veh) or ''
            end)
        end

        SendNUIMessage({
            type = 'openTelemetry',
            vehicleName = vehicleName,
            plate = plate,
            recording = isRecording,
            best = bestResults,
            last = lastResults,
            versions = vehicleVersions,
            currentVersion = currentVersion
        })
    end
end

-- Command to open telemetry UI
RegisterCommand('telemetry', function()
    ToggleNUI()
end, false)

RegisterCommand('fish', function()
    ToggleNUI()
end, false)

-- Key mappings
RegisterKeyMapping('telemetry', 'Open FISH Telemetry', 'keyboard', 'F7')
