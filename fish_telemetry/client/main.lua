-- ============================================================
-- fish_telemetry: Client Main
-- G key: start/stop recording telemetry
-- K key: show nearby vehicle ratings (handled in normalizer too)
-- Version detection: detects when tune/remap changes mid-session
-- Clipboard export: copies formatted results with SetClipboardText
-- ============================================================

local isRecording   = false
local isNuiOpen     = false
local currentVehicle = nil

-- ============================================================
-- Telemetry Session Data
-- ============================================================

local versions = {}           -- array of version snapshots
local currentVersion = nil    -- active version being recorded
local sessionStartTime = 0

-- ============================================================
-- Per-version snapshot structure
-- ============================================================

local function NewVersionSnapshot(label, score, archetype, remapStage)
    return {
        label     = label,
        score     = score,
        archetype = archetype,
        remapStage = remapStage,
        startTime = GetGameTimer(),
        samples   = {},        -- raw speed samples (ms → km/h)

        -- Computed results
        maxSpeed      = 0,
        time0_100     = nil,   -- seconds
        time0_200     = nil,
        time100_0     = nil,
        dist100_0     = nil,   -- meters
        time200_0     = nil,
        dist200_0     = nil,
        bestGForce    = 0,
        lastGForce    = 0,

        -- Internal state machines
        sm_0_100      = { phase = 'waiting' },  -- waiting / measuring / done
        sm_0_200      = { phase = 'waiting' },
        sm_100_0      = { phase = 'waiting', startSpeed = 0, startTime = 0, startPos = nil },
        sm_200_0      = { phase = 'waiting', startSpeed = 0, startTime = 0, startPos = nil },
    }
end

-- ============================================================
-- State snapshot: what version are we in?
-- Called on start and whenever state bag changes
-- ============================================================

local function GetCurrentVehicleSignature()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh  = GetVehiclePedIsIn(ped, false)
    local score     = Entity(veh).state['fish:score'] or 0
    local archetype = Entity(veh).state['fish:archetype'] or 'stock'
    local heat      = Entity(veh).state['fish:heat'] or 0
    local plate     = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    return {
        plate     = plate,
        score     = score,
        archetype = archetype,
        heat      = heat
    }
end

local function GetVersionLabel(sig, idx)
    if idx == 1 then return 'Stock' end
    local labels = { [2] = 'Tuned', [3] = 'Remapped', [4] = 'Stage 2', [5] = 'Stage 3' }
    return labels[idx] or ('Version ' .. idx)
end

local function MaybeCreateNewVersion()
    local sig = GetCurrentVehicleSignature()
    if not sig then return end

    -- If no version or score changed significantly (>5 pts) → new version
    if not currentVersion then
        local idx   = #versions + 1
        local label = GetVersionLabel(sig, idx)
        currentVersion = NewVersionSnapshot(label, sig.score, sig.archetype, 0)
        table.insert(versions, currentVersion)
        return
    end

    local scoreDiff = math.abs((currentVersion.score or 0) - (sig.score or 0))
    if scoreDiff >= 5 or currentVersion.archetype ~= sig.archetype then
        -- Freeze current version
        currentVersion.endTime = GetGameTimer()

        -- Create new version
        local idx   = #versions + 1
        local label = GetVersionLabel(sig, idx)
        currentVersion = NewVersionSnapshot(label, sig.score, sig.archetype, 0)
        table.insert(versions, currentVersion)

        -- Notify NUI
        if isNuiOpen then
            SendNUIMessage({ action = 'newVersion', label = label, versionCount = #versions })
        end
    end
end

-- ============================================================
-- State Bag Listeners: detect tune/remap changes mid-session
-- ============================================================

AddStateBagChangeHandler('fish:score', nil, function(bagName, key, value, _, replicated)
    if not isRecording then return end
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    local veh   = GetVehiclePedIsIn(ped, false)
    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end
    local myVeh = NetworkGetEntityFromNetworkId(netId)
    if myVeh == veh then
        -- Debounce: wait 500ms then check
        Citizen.CreateThread(function()
            Citizen.Wait(500)
            MaybeCreateNewVersion()
        end)
    end
end)

AddStateBagChangeHandler('fish:archetype', nil, function(bagName, key, value, _, replicated)
    if not isRecording then return end
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    local veh   = GetVehiclePedIsIn(ped, false)
    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end
    local myVeh = NetworkGetEntityFromNetworkId(netId)
    if myVeh == veh then
        Citizen.CreateThread(function()
            Citizen.Wait(500)
            MaybeCreateNewVersion()
        end)
    end
end)

-- ============================================================
-- G-Force Calculation
-- ============================================================

local prevVelocity = vector3(0,0,0)
local prevVelTime  = 0

local function CalculateLateralGForce(vehicle)
    local vel = GetEntityVelocity(vehicle)
    local now = GetGameTimer()
    local dt  = (now - prevVelTime) / 1000.0
    if dt <= 0 then return 0 end

    -- Lateral acceleration = cross product of velocity delta with forward vector
    local heading = GetEntityHeading(vehicle)
    local rad     = math.rad(heading)
    local fwd     = vector3(-math.sin(rad), math.cos(rad), 0)
    local right   = vector3(math.cos(rad), math.sin(rad), 0)

    local accelX  = (vel.x - prevVelocity.x) / dt
    local accelY  = (vel.y - prevVelocity.y) / dt

    -- Lateral = component of acceleration perpendicular to forward
    local latAccel = accelX * right.x + accelY * right.y
    local gforce   = math.abs(latAccel) / 9.81

    prevVelocity = vel
    prevVelTime  = now

    return math.min(gforce, 5.0)
end

-- ============================================================
-- Telemetry Sampling Loop
-- ============================================================

local function StartSampling(vehicle)
    local SAMPLE_INTERVAL = 100  -- ms
    local lastSampleTime  = 0
    local tireInContact   = true

    Citizen.CreateThread(function()
        while isRecording and DoesEntityExist(vehicle) do
            local now      = GetGameTimer()
            local speedMS  = GetEntitySpeed(vehicle)  -- m/s
            local speedKMH = speedMS * 3.6
            local pos      = GetEntityCoords(vehicle)
            local gForce   = CalculateLateralGForce(vehicle)

            -- Check tire contact (G-force only when gripping)
            tireInContact = GetEntityHeightAboveGround(vehicle) < 1.0

            -- Record sample
            if now - lastSampleTime >= SAMPLE_INTERVAL then
                lastSampleTime = now
                table.insert(currentVersion.samples, { t = now, spd = speedKMH })
            end

            -- Update max speed
            if speedKMH > currentVersion.maxSpeed then
                currentVersion.maxSpeed = speedKMH
            end

            -- G-force tracking (only when gripping)
            if tireInContact and gForce > currentVersion.bestGForce then
                currentVersion.bestGForce = gForce
            end
            if tireInContact then
                currentVersion.lastGForce = gForce
            end

            -- ── 0→100 state machine ──────────────────────────
            local sm01 = currentVersion.sm_0_100
            if sm01.phase == 'waiting' and speedKMH < 5 then
                sm01.phase     = 'ready'
            elseif sm01.phase == 'ready' and speedKMH >= 5 then
                sm01.phase     = 'measuring'
                sm01.startTime = now
                sm01.startSpd  = speedKMH
            elseif sm01.phase == 'measuring' and speedKMH >= 100 then
                sm01.phase = 'done'
                local elapsed = (now - sm01.startTime) / 1000.0
                -- Interpolate back to exact 100 if we overshot
                if sm01.startSpd then
                    local overshoot = (speedKMH - 100) / (speedKMH - sm01.startSpd)
                    elapsed = elapsed - (overshoot * SAMPLE_INTERVAL / 1000.0)
                end
                currentVersion.time0_100 = math.max(0.1, elapsed)
            end

            -- ── 0→200 state machine ──────────────────────────
            local sm02 = currentVersion.sm_0_200
            if sm02.phase == 'waiting' and speedKMH < 5 then
                sm02.phase = 'ready'
            elseif sm02.phase == 'ready' and speedKMH >= 5 then
                sm02.phase     = 'measuring'
                sm02.startTime = now
            elseif sm02.phase == 'measuring' and speedKMH >= 200 then
                sm02.phase = 'done'
                currentVersion.time0_200 = (now - sm02.startTime) / 1000.0
            end

            -- ── 100→0 state machine ──────────────────────────
            local sm10 = currentVersion.sm_100_0
            if sm10.phase == 'waiting' and speedKMH >= 100 then
                sm10.phase     = 'ready'
                sm10.startTime = now
                sm10.startPos  = vector3(pos.x, pos.y, pos.z)
            elseif sm10.phase == 'ready' and speedKMH < 5 then
                sm10.phase = 'done'
                local endTime = now
                local dist    = #(vector3(pos.x, pos.y, pos.z) - sm10.startPos)
                currentVersion.time100_0 = (endTime - sm10.startTime) / 1000.0
                currentVersion.dist100_0 = dist
                -- Reset so it can be triggered again
                sm10.phase = 'waiting'
            end

            -- ── 200→0 state machine ──────────────────────────
            local sm20 = currentVersion.sm_200_0
            if sm20.phase == 'waiting' and speedKMH >= 200 then
                sm20.phase     = 'ready'
                sm20.startTime = now
                sm20.startPos  = vector3(pos.x, pos.y, pos.z)
            elseif sm20.phase == 'ready' and speedKMH < 5 then
                sm20.phase = 'done'
                local endTime = now
                local dist    = #(vector3(pos.x, pos.y, pos.z) - sm20.startPos)
                currentVersion.time200_0 = (endTime - sm20.startTime) / 1000.0
                currentVersion.dist200_0 = dist
                sm20.phase = 'waiting'
            end

            -- Push live data to NUI every 100ms
            if isNuiOpen then
                SendNUIMessage({
                    action    = 'liveTelemetry',
                    speed     = speedKMH,
                    maxSpeed  = currentVersion.maxSpeed,
                    gForce    = gForce,
                    time0_100 = currentVersion.time0_100,
                    time0_200 = currentVersion.time0_200,
                    time100_0 = currentVersion.time100_0,
                    dist100_0 = currentVersion.dist100_0,
                    time200_0 = currentVersion.time200_0,
                    dist200_0 = currentVersion.dist200_0,
                    bestGForce = currentVersion.bestGForce,
                    isRecording = true
                })
            end

            Citizen.Wait(SAMPLE_INTERVAL)
        end
    end)
end

-- ============================================================
-- Format results for clipboard
-- ============================================================

local function FormatResultsForClipboard()
    local lines = {}
    table.insert(lines, '═══════════════════════════════════')
    table.insert(lines, '  FISH TELEMETRY — SESSION RESULTS')
    table.insert(lines, '═══════════════════════════════════')

    local function fmt(val, unit, decimals)
        if not val then return '  N/A   ' end
        decimals = decimals or 2
        return string.format('%.' .. decimals .. 'f %s', val, unit)
    end

    for i, ver in ipairs(versions) do
        table.insert(lines, '')
        table.insert(lines, ('── %s (PI: %d | %s)'):format(ver.label, ver.score or 0, ver.archetype or '?'))
        table.insert(lines, '  Max Speed   : ' .. fmt(ver.maxSpeed,     'km/h', 1))
        table.insert(lines, '  0-100 km/h  : ' .. fmt(ver.time0_100,    's'))
        table.insert(lines, '  0-200 km/h  : ' .. fmt(ver.time0_200,    's'))
        table.insert(lines, '  100-0 km/h  : ' .. fmt(ver.time100_0,    's') .. '  /  ' .. fmt(ver.dist100_0, 'm', 0))
        table.insert(lines, '  200-0 km/h  : ' .. fmt(ver.time200_0,    's') .. '  /  ' .. fmt(ver.dist200_0, 'm', 0))
        table.insert(lines, '  Best Lat G  : ' .. fmt(ver.bestGForce,   'G'))
    end

    table.insert(lines, '')
    table.insert(lines, '═══════════════════════════════════')
    table.insert(lines, ('Generated by FISH Telemetry v2 | %s'):format(GetClockYearOfMonth and GetClockHours and '' or ''))
    -- Use FiveM natives for date
    local y,m,d = GetClockYear(), GetClockMonth()+1, GetClockDayOfMonth()
    local h,min = GetClockHours(), GetClockMinutes()
    lines[#lines] = ('Generated by FISH Telemetry v2 | %04d-%02d-%02d %02d:%02d'):format(y,m,d,h,min)

    return table.concat(lines, '\n')
end

-- ============================================================
-- Start Recording
-- ============================================================

local function StartRecording()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        ShowNotif('~r~You must be in a vehicle to record telemetry.')
        return
    end
    if IsPedInAnyVehicle(ped, true) then
        -- Check if driver seat
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then
            ShowNotif('~r~You must be in the driver seat to record.')
            return
        end
    end

    local veh = GetVehiclePedIsIn(ped, false)
    currentVehicle   = veh
    isRecording      = true
    versions         = {}
    currentVersion   = nil
    sessionStartTime = GetGameTimer()
    prevVelocity     = GetEntityVelocity(veh)
    prevVelTime      = GetGameTimer()

    -- Create first version snapshot
    MaybeCreateNewVersion()

    -- Open NUI (no mouse capture - it's a HUD sidebar)
    SetNuiFocus(false, false)
    isNuiOpen = true
    SendNUIMessage({
        action       = 'startRecording',
        versionLabel = currentVersion and currentVersion.label or 'Stock',
        vehicleName  = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
        plate        = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    })

    StartSampling(veh)
    ShowNotif('~g~Telemetry recording started.')
end

-- ============================================================
-- Stop Recording
-- ============================================================

local function StopRecording()
    if not isRecording then return end
    isRecording = false

    if currentVersion then
        currentVersion.endTime = GetGameTimer()
    end

    -- Push all versions to NUI (clipboard copy done via JS Clipboard API)
    local clipboardText = FormatResultsForClipboard()

    -- Push all versions to NUI
    local versionsForNUI = {}
    for _, ver in ipairs(versions) do
        table.insert(versionsForNUI, {
            label     = ver.label,
            score     = ver.score,
            archetype = ver.archetype,
            maxSpeed  = ver.maxSpeed,
            time0_100 = ver.time0_100,
            time0_200 = ver.time0_200,
            time100_0 = ver.time100_0,
            dist100_0 = ver.dist100_0,
            time200_0 = ver.time200_0,
            dist200_0 = ver.dist200_0,
            bestGForce = ver.bestGForce,
        })
    end

    SendNUIMessage({
        action   = 'stopRecording',
        versions = versionsForNUI,
        clipboard = true,
        clipboardText = clipboardText
    })

    ShowNotif('~g~Telemetry saved. Results copied to clipboard!')

    -- Auto-hide NUI after 3 seconds (show results briefly then disappear)
    Citizen.CreateThread(function()
        Citizen.Wait(3000)
        if not isRecording then
            isNuiOpen = false
            SendNUIMessage({ action = 'hide' })
        end
    end)

    currentVehicle = nil
end

-- ============================================================
-- G Key Toggle
-- ============================================================

RegisterCommand('telemetry', function()
    if not isRecording then
        StartRecording()
    else
        StopRecording()
    end
end, false)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        -- G key (input code 47)
        if IsControlJustPressed(0, 47) then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                if not isRecording then
                    StartRecording()
                else
                    StopRecording()
                end
            end
        end
    end
end)

-- ============================================================
-- NUI Callbacks
-- ============================================================

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isNuiOpen = false
    if isRecording then StopRecording() end
    cb('ok')
end)

RegisterNUICallback('copyClipboard', function(data, cb)
    local text = FormatResultsForClipboard()
    -- Send to NUI for JS Clipboard API (SetClipboardText doesn't exist client-side)
    SendNUIMessage({ action = 'copyToClipboard', text = text })
    cb('ok')
end)

RegisterNUICallback('startRecording', function(data, cb)
    if not isRecording then StartRecording() end
    cb('ok')
end)

RegisterNUICallback('stopRecording', function(data, cb)
    if isRecording then StopRecording() end
    cb('ok')
end)

-- ============================================================
-- Utility
-- ============================================================

function ShowNotif(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

-- ============================================================
-- Telemetry fxmanifest update needed:
-- Update server script list and add client telemetry
-- ============================================================
