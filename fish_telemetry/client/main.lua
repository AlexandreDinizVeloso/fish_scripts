--[[
    FISH Telemetry - Client Main Module
    Vehicle telemetry recording and analysis system
]]

local isRecording = false
local recordingStartTime = 0
local recordingTimer = nil
local currentData = {}
local bestResults = nil
local lastResults = nil
local vehicleVersions = {}
local currentVersion = 1
local previousAccel = { x = 0, y = 0, z = 0 }
local previousSpeed = 0
local nuiOpen = false
local lastToggleTime = 0
local DEBOUNCE_COOLDOWN = 500

-- Timing milestones for acceleration
local milestone_0_100 = nil
local milestone_0_200 = nil

-- Timing milestones for braking
local milestone_100_0 = nil
local milestone_200_0 = nil

-- Last run timing trackers
local last_0_100 = nil
local last_0_200 = nil
local last_100_0 = nil
local last_200_0 = nil
local last_gforce = 0.0

-- Braking state tracking
local brakingFrom100 = false
local brakingFrom200 = false
local brakeStartSpeed = 0
local brakeStartTime100 = 0
local brakeStartTime200 = 0

-- G-force tracking
local maxLateralG = 0.0
local previousLateralAccel = 0.0
local accelerationStartTime = 0

-- Helper: Get current vehicle
function GetCurrentVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

-- Helper: Check if player is driving
function IsPlayerDriving()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end
    local veh = GetVehiclePedIsIn(ped, false)
    return GetPedInVehicleSeat(veh, -1) == ped
end

-- Helper: Get vehicle speed in km/h
local function GetVehicleSpeedKmh(veh)
    return GetEntitySpeed(veh) * 3.6
end

-- Helper: Get vehicle plate
local function GetVehiclePlate(veh)
    return string.gsub(GetVehicleNumberPlateText(veh), "^%s*(.-)%s*$", "%1")
end

-- Helper: Get vehicle display name
local function GetVehicleDisplayName(veh)
    local model = GetEntityModel(veh)
    local displayName = GetDisplayNameFromVehicleModel(model)
    return GetLabelText(displayName)
end

-- Helper: Check if value changed beyond threshold
local function HasChangedSignificantly(oldVal, newVal, threshold)
    if oldVal == 0 and newVal == 0 then return false end
    local base = math.max(math.abs(oldVal), 1.0)
    return math.abs(newVal - oldVal) / base > threshold
end

-- Reset recording data
local function ResetRecordingData()
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
    last_0_100 = nil
    last_0_200 = nil
    last_100_0 = nil
    last_200_0 = nil
    last_gforce = 0.0
    brakingFrom100 = false
    brakingFrom200 = false
    brakeStartSpeed = 0
    brakeStartTime100 = 0
    brakeStartTime200 = 0
    maxLateralG = 0.0
    previousSpeed = 0
    previousVel = vector3(0, 0, 0)
    lastDataTime = 0
    accelerationStartTime = 0
end

-- Collect telemetry data point
local function CollectDataPoint()
    local veh = GetCurrentVehicle()
    if not veh then
        StopRecording()
        return
    end

    local currentTime = GetGameTimer()
    local elapsed = currentTime - recordingStartTime
    local speed = GetVehicleSpeedKmh(veh)

    -- Track max speed for version detection
    if speed > (currentData.maxSpeed or 0) then
        currentData.maxSpeed = speed
    end

    -- Store speed data
    table.insert(currentData.speeds, speed)
    table.insert(currentData.timestamps, elapsed)

    -- Calculate global acceleration (dv / dt)
    local currentVel = GetEntityVelocity(veh)
    local dt = (currentTime - (lastDataTime or currentTime)) / 1000.0
    if dt <= 0 then dt = 0.001 end
    
    -- Ensure previousVel is initialized
    if lastDataTime == 0 then previousVel = currentVel end

    local accelX = (currentVel.x - previousVel.x) / dt
    local accelY = (currentVel.y - previousVel.y) / dt
    local accelZ = (currentVel.z - previousVel.z) / dt
    
    -- Calculate lateral G-force using entity matrix
    local rightVector, forwardVector, upVector, position = GetEntityMatrix(veh)
    local lateralAccel = (accelX * rightVector.x) + (accelY * rightVector.y) + (accelZ * rightVector.z)
    
    -- Smooth the acceleration to reduce noise
    lateralAccel = (lateralAccel * 0.3) + (previousLateralAccel * 0.7)
    if lateralAccel ~= lateralAccel then lateralAccel = 0.0 end -- Protect against NaN
    
    local gForce = (lateralAccel / 9.81)
    if gForce ~= gForce then gForce = 0.0 end -- Protect against NaN
    
    -- Cap max G-force to realistic values
    if math.abs(gForce) > 5.0 then
        gForce = 5.0 * (gForce / math.abs(gForce))
    end

    previousLateralAccel = lateralAccel

    -- Calculate if vehicle has traction (not sliding)
    local localVel = GetEntitySpeedVector(veh, true)
    local localVelX = type(localVel) == 'vector3' and localVel.x or (type(localVel) == 'table' and localVel.x or 0.0)
    local isSliding = math.abs(localVelX) > 2.0

    if not isSliding and speed > 10.0 then
        last_gforce = gForce
        if math.abs(gForce) > math.abs(maxLateralG) then
            maxLateralG = gForce
        end
    end

    table.insert(currentData.gforces, gForce)

    -- Acceleration tracking
    if speed > 2.0 and previousSpeed <= 2.0 then
        accelerationStartTime = currentTime
    elseif speed <= 2.0 then
        accelerationStartTime = 0
    end

    -- Acceleration milestones: 0-100 and 0-200
    if speed >= 100 and previousSpeed < 100 and accelerationStartTime > 0 then
        local timeTaken = (currentTime - accelerationStartTime) / 1000.0
        last_0_100 = timeTaken
        if milestone_0_100 == nil or timeTaken < milestone_0_100 then
            milestone_0_100 = timeTaken
        end
    end
    
    if speed >= 200 and previousSpeed < 200 and accelerationStartTime > 0 then
        local timeTaken = (currentTime - accelerationStartTime) / 1000.0
        last_0_200 = timeTaken
        if milestone_0_200 == nil or timeTaken < milestone_0_200 then
            milestone_0_200 = timeTaken
        end
    end

    -- Braking detection: speed decreasing
    local isDecelerating = speed < previousSpeed

    if not brakingFrom100 and previousSpeed >= 100 and speed < 100 and isDecelerating then
        brakingFrom100 = true
        brakeStartTime100 = currentTime
    end

    if not brakingFrom200 and previousSpeed >= 200 and speed < 200 and isDecelerating then
        brakingFrom200 = true
        brakeStartTime200 = currentTime
    end

    -- Process braking milestones
    if brakingFrom100 then
        if speed > previousSpeed + 5.0 then -- Cancel if clearly accelerating
            brakingFrom100 = false
        elseif speed < 3.0 then -- Reached standstill
            local timeTaken = (currentTime - brakeStartTime100) / 1000.0
            last_100_0 = timeTaken
            if milestone_100_0 == nil or timeTaken < milestone_100_0 then
                milestone_100_0 = timeTaken
            end
            brakingFrom100 = false
        end
    end

    if brakingFrom200 then
        if speed > previousSpeed + 5.0 then -- Cancel if clearly accelerating
            brakingFrom200 = false
        elseif speed < 3.0 then
            local timeTaken = (currentTime - brakeStartTime200) / 1000.0
            last_200_0 = timeTaken
            if milestone_200_0 == nil or timeTaken < milestone_200_0 then
                milestone_200_0 = timeTaken
            end
            brakingFrom200 = false
        end
    end

    -- Update previous values
    previousSpeed = speed
    previousVel = currentVel
    lastDataTime = currentTime

    -- Send live data to NUI
    if nuiOpen then
        SendNUIMessage({
            type = 'updateLive',
            speed = speed,
            maxSpeed = currentData.maxSpeed or 0,
            gforce = gForce,
            elapsed = elapsed / 1000.0,
            recording = true,
            version = currentVersion,
            milestones = {
                zero_to_100 = last_0_100 or 0,
                zero_to_200 = last_0_200 or 0,
                hundred_to_zero = last_100_0 or 0,
                two_hundred_to_zero = last_200_0 or 0,
                lateral_gforce = last_gforce or 0,
                best_zero_to_100 = milestone_0_100 or 0,
                best_zero_to_200 = milestone_0_200 or 0,
                best_hundred_to_zero = milestone_100_0 or 0,
                best_two_hundred_to_zero = milestone_200_0 or 0,
                best_lateral_gforce = maxLateralG or 0
            }
        })
    end

    -- Max duration check
    if elapsed >= Config.MaxRecordingDuration then
        StopRecording()
    end
end

-- Start recording
function StartRecording()
    if isRecording then return end

    if not IsPlayerDriving() then
        ShowNotification("~r~You must be driving a vehicle to record telemetry.")
        return
    end

    isRecording = true
    recordingStartTime = GetGameTimer()
    ResetRecordingData()

    -- Record vehicle info
    local veh = GetCurrentVehicle()
    currentData.vehicleName = GetVehicleDisplayName(veh)
    currentData.plate = GetPlate and GetPlate(veh) or GetVehiclePlate(veh)
    currentData.startSpeed = 0

    -- Notify NUI
    SendNUIMessage({
        type = 'recordingStarted',
        vehicleName = currentData.vehicleName,
        plate = currentData.plate
    })

    -- Start collection timer
    recordingTimer = Citizen.CreateThread(function()
        while isRecording do
            local success, err = pcall(CollectDataPoint)
            if not success then
                print("^1[FISH TELEMETRY ERROR]^7 " .. tostring(err))
                SendNUIMessage({
                    type = 'openTelemetry',
                    vehicleName = "CRASH DETECTED",
                    plate = string.sub(tostring(err), 1, 40),
                    recording = false
                })
                Citizen.Wait(2000)
                StopRecording()
                break
            end
            Citizen.Wait(Config.RecordingInterval)
        end
    end)
    nuiOpen = true
    SendNUIMessage({
        type = 'openTelemetry',
        vehicleName = currentData.vehicleName,
        plate = currentData.plate,
        recording = true
    })
    ShowNotification("~g~Telemetry recording started.")
end

-- Stop recording
function StopRecording()
    if not isRecording then return end
    isRecording = false

    if recordingTimer then
        recordingTimer = nil
    end

    -- Compile results
    local result = {
        vehicle_name = currentData.vehicleName or 'Unknown',
        plate = currentData.plate or 'Unknown',
        max_speed = currentData.maxSpeed or 0,
        zero_to_100 = milestone_0_100 or 0,
        zero_to_200 = milestone_0_200 or 0,
        hundred_to_zero = milestone_100_0 or 0,
        two_hundred_to_zero = milestone_200_0 or 0,
        lateral_gforce = maxLateralG or 0,
        version = currentVersion,
        timestamp = GetCloudTimeAsInt(),
        duration = (GetGameTimer() - recordingStartTime) / 1000.0
    }

    lastResults = result

    -- Version detection: check if stats changed significantly compared to previous best
    if bestResults then
        local statsChanged = false
        if HasChangedSignificantly(bestResults.max_speed or 0, result.max_speed or 0, Config.ChangeDetectionThreshold) then
            statsChanged = true
        end
        if result.zero_to_100 and result.zero_to_100 > 0 and bestResults.zero_to_100 and HasChangedSignificantly(bestResults.zero_to_100, result.zero_to_100, Config.ChangeDetectionThreshold) then
            statsChanged = true
        end
        if result.zero_to_200 and result.zero_to_200 > 0 and bestResults.zero_to_200 and HasChangedSignificantly(bestResults.zero_to_200, result.zero_to_200, Config.ChangeDetectionThreshold) then
            statsChanged = true
        end
        if result.hundred_to_zero and result.hundred_to_zero > 0 and bestResults.hundred_to_zero and HasChangedSignificantly(bestResults.hundred_to_zero, result.hundred_to_zero, Config.ChangeDetectionThreshold) then
            statsChanged = true
        end
        if result.two_hundred_to_zero and result.two_hundred_to_zero > 0 and bestResults.two_hundred_to_zero and HasChangedSignificantly(bestResults.two_hundred_to_zero, result.two_hundred_to_zero, Config.ChangeDetectionThreshold) then
            statsChanged = true
        end

        if statsChanged then
            -- Archive current best as a version
            table.insert(vehicleVersions, DeepCopy(bestResults))
            currentVersion = #vehicleVersions + 1
            -- Version detected notification will be handled when UI is open next time or via toast
            SendNUIMessage({
                type = 'versionDetected',
                version = currentVersion,
                versions = vehicleVersions
            })
        end
    end

    -- Update best results
    if bestResults == nil then
        bestResults = DeepCopy(result)
    else
        -- Compare and keep best (lower times are better, higher speed/G is better)
        if result.max_speed > (bestResults.max_speed or 0) then
            bestResults.max_speed = result.max_speed
        end
        if result.zero_to_100 and (bestResults.zero_to_100 == nil or result.zero_to_100 < bestResults.zero_to_100) then
            bestResults.zero_to_100 = result.zero_to_100
        end
        if result.zero_to_200 and (bestResults.zero_to_200 == nil or result.zero_to_200 < bestResults.zero_to_200) then
            bestResults.zero_to_200 = result.zero_to_200
        end
        if result.hundred_to_zero and (bestResults.hundred_to_zero == nil or result.hundred_to_zero < bestResults.hundred_to_zero) then
            bestResults.hundred_to_zero = result.hundred_to_zero
        end
        if result.two_hundred_to_zero and (bestResults.two_hundred_to_zero == nil or result.two_hundred_to_zero < bestResults.two_hundred_to_zero) then
            bestResults.two_hundred_to_zero = result.two_hundred_to_zero
        end
        if math.abs(result.lateral_gforce) > math.abs(bestResults.lateral_gforce or 0) then
            bestResults.lateral_gforce = result.lateral_gforce
        end
    end

    -- Store version
    vehicleVersions[currentVersion] = DeepCopy(result)

    -- Send to server for persistence
    TriggerServerEvent('fish_telemetry:saveResults', result)

    -- Copy result to clipboard
    local resultText = string.format("Veículo: %s | Max Speed: %.1f km/h | 0-100: %.2fs | 100-0: %.2fs | 200-0: %.2fs | Lateral G: %.2f", 
        result.vehicle_name, result.max_speed, result.zero_to_100 or 0.0, result.hundred_to_zero or 0.0, result.two_hundred_to_zero or 0.0, result.lateral_gforce or 0.0)
    
    -- Notify NUI to close UI and copy to clipboard
    SendNUIMessage({
        type = 'recordingStopped',
        result = result,
        best = bestResults,
        versions = vehicleVersions,
        closeUI = true,
        clipboard = resultText
    })
    
    nuiOpen = false
    ShowNotification("~b~Telemetry recording stopped. Max speed: " .. string.format("%.1f", result.max_speed) .. " km/h")
end

-- Toggle recording
function ToggleRecording()
    if isRecording then
        StopRecording()
    else
        StartRecording()
    end
end

-- Show nearby vehicle ratings (hold K)
local showingRatings = false
local ratingsThread = nil

function ShowNearbyVehicleRatings()
    if showingRatings then return end
    showingRatings = true

    ratingsThread = Citizen.CreateThread(function()
        while showingRatings do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local vehicles = GetGamePool('CVehicle')

            local nearbyVehicles = {}
            for _, veh in ipairs(vehicles) do
                local vehPos = GetEntityCoords(veh)
                local dist = #(pos - vehPos)
                if dist < 50.0 and veh ~= GetCurrentVehicle() then
                    local plate = GetVehiclePlate(veh)
                    local name = GetVehicleDisplayName(veh)
                    table.insert(nearbyVehicles, {
                        plate = plate,
                        name = name,
                        distance = dist
                    })
                end
            end

            -- Try to get telemetry data from server
            if #nearbyVehicles > 0 then
                TriggerServerEvent('fish_telemetry:requestNearbyData', nearbyVehicles)
            end

            Citizen.Wait(1000)
        end
    end)
end

function HideNearbyVehicleRatings()
    showingRatings = false
    if ratingsThread then
        ratingsThread = nil
    end
    SendNUIMessage({ type = 'hideRatings' })
end

-- Key bindings
RegisterCommand('telemetry_record', function()
    ToggleRecording()
end, false)
RegisterKeyMapping('telemetry_record', 'Toggle Telemetry Recording', 'keyboard', 'G')

-- Notification helper
function ShowNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

-- Deep copy helper
function DeepCopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

-- Export: GetTelemetryData
function GetTelemetryData(vehicle)
    if vehicle then
        local plate = GetVehiclePlate(vehicle)
        local data = nil
        TriggerServerEvent('fish_telemetry:requestData', plate)
        -- Return last known data for this plate
        for _, v in pairs(vehicleVersions) do
            if v.plate == plate then
                data = v
            end
        end
        return data
    end
    return {
        best = bestResults,
        last = lastResults,
        versions = vehicleVersions
    }
end

-- Export: IsRecording
function IsRecording()
    return isRecording
end

-- Export: GetSafePlayerName (accessible by nui.lua)
function GetSafeDisplayName(veh)
    return GetVehicleDisplayName(veh)
end

-- Export: ResetRecordingData (accessible by nui.lua)
function ExportedResetRecordingData()
    ResetRecordingData()
end

-- Receive nearby data from server
RegisterNetEvent('fish_telemetry:receiveNearbyData')
AddEventHandler('fish_telemetry:receiveNearbyData', function(data)
    if nuiOpen then
        SendNUIMessage({
            type = 'nearbyRatings',
            vehicles = data
        })
    end
end)

-- Receive requested telemetry data from server
RegisterNetEvent('fish_telemetry:receiveData')
AddEventHandler('fish_telemetry:receiveData', function(data)
    if data and nuiOpen then
        SendNUIMessage({
            type = 'historicalData',
            data = data
        })
    end
end)

-- Initialize
Citizen.CreateThread(function()
    -- Request stored data from server on spawn
    Citizen.Wait(2000)
    TriggerServerEvent('fish_telemetry:requestAllData')
end)

RegisterNetEvent('fish_telemetry:receiveAllData')
AddEventHandler('fish_telemetry:receiveAllData', function(data)
    if data then
        vehicleVersions = data.versions or {}
        bestResults = data.best or nil
        lastResults = data.last or nil
        currentVersion = #vehicleVersions + 1
    end
end)
