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
-- Version cooldown: prevent rapid-fire new version creation
-- ============================================================

local lastVersionCreateTime = 0
local VERSION_COOLDOWN_MS = 15000  -- 15s mínimo entre novas versões

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
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local activePerf = nil
    local handlingXML = {}
    
    if veh ~= 0 and DoesEntityExist(veh) then
        local plate = string.gsub(GetVehicleNumberPlateText(veh), '%s+', '')
        pcall(function()
            activePerf = exports['fish_normalizer']:GetActivePerformanceData(plate)
        end)
        
        handlingXML = {
            fInitialDriveMaxFlatVel = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel'),
            fInitialDriveForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce'),
            fBrakeForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce'),
            fTractionCurveMax = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax'),
            fTractionCurveMin = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMin'),
            fInitialDragCoeff = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDragCoeff'),
            fSuspensionForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionForce'),
            fSuspensionCompDamp = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionCompDamp'),
            fSuspensionReboundDamp = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionReboundDamp'),
            fSuspensionRaise = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionRaise'),
        }
    end

    return {
        label     = label,
        score     = score,
        archetype = archetype,
        remapStage = remapStage,
        startTime = GetGameTimer(),
        samples   = {},        -- raw speed samples (ms → km/h)
        activePerf = activePerf,
        handlingXML = handlingXML,

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
    local plate     = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    
    local score = 0
    pcall(function()
        score = exports['fish_normalizer']:GetVehicleScore(veh) or 0
    end)
    
    local archetype = 'stock'
    pcall(function()
        archetype = exports['fish_normalizer']:GetVehicleArchetype(veh) or 'stock'
    end)
    
    local matrix = Entity(veh).state['fish_physics_matrix']
    local heat = (matrix and matrix.heat) or 0
    
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
    local now = GetGameTimer()
    if not now then return end  -- protege contra nil

    -- Cooldown: não cria versão nova se criou uma há menos de 15s
    if now - lastVersionCreateTime < VERSION_COOLDOWN_MS then return end

    local sig = GetCurrentVehicleSignature()
    if not sig then return end

    -- Se não tem versão ainda, cria a primeira
    if not currentVersion then
        local idx   = #versions + 1
        local label = GetVersionLabel(sig, idx)
        currentVersion = NewVersionSnapshot(label, sig.score, sig.archetype, 0)
        table.insert(versions, currentVersion)
        lastVersionCreateTime = now
        return
    end

    -- Só cria nova versão se a mudança for REALMENTE significativa
    local scoreDiff = math.abs((currentVersion.score or 0) - (sig.score or 0))
    if scoreDiff >= 5 or currentVersion.archetype ~= sig.archetype then
        -- Congela versão atual
        currentVersion.endTime = now

        -- Cria nova versão
        local idx   = #versions + 1
        local label = GetVersionLabel(sig, idx)
        currentVersion = NewVersionSnapshot(label, sig.score, sig.archetype, 0)
        table.insert(versions, currentVersion)
        lastVersionCreateTime = now

        -- Notifica NUI
        if isNuiOpen then
            SendNUIMessage({ action = 'newVersion', label = label, versionCount = #versions })
        end
    end
end

-- ============================================================
-- State Bag Listener: detect tune/remap changes mid-session
-- Consolidated: reads from fish_physics_matrix instead of individual bags
-- ============================================================

AddStateBagChangeHandler('fish_physics_matrix', nil, function(bagName, key, value, _, replicated)
    if not isRecording then return end
    if not value then return end
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    local veh   = GetVehiclePedIsIn(ped, false)
    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end
    local myVeh = NetworkGetEntityFromNetworkId(netId)
    if myVeh == veh then
        -- Debounce: wait 1000ms then check
        Citizen.CreateThread(function()
            Citizen.Wait(1000)
            if not isRecording then return end
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
    if not now then return 0 end
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
-- Delta-Encoding: Shadow DOM e Payload Pré-Alocado para IPC Zero-Allocation
-- ============================================================
local lastTelemetryState = {}     -- Shadow DOM: armazena último estado enviado via IPC
local TELEMETRY_EPSILON = 0.01    -- ε = 1% threshold mínimo para mutação de campo numérico

-- Payload delta pré-alocado (NUNCA recriado dentro do loop — Zero-Allocation)
local deltaPayload = { action = 'liveTelemetry' }

-- Limpeza de chaves mortas após despacho: anula ponteiros sem destruir a matriz base
local function ResetDeltaPayload()
    for k in pairs(deltaPayload) do
        if k ~= 'action' then
            deltaPayload[k] = nil  -- Anula referência em O(1), preserva alocação da tabela
        end
    end
end

-- checkDelta: compara newVal contra oldVal com inversão algébrica (FMUL sobre FDIV)
-- retorna true se o valor mudou além do threshold ε
-- A inversão algébrica substitui math.abs(A-B)/max(|B|,1) > ε por math.abs(A-B) > ε * max(|B|,1)
-- Isto elimina a instrução FDIV (10-40 ciclos) em favor de FMUL (1-3 ciclos)
local function checkDelta(key, newVal, threshold)
    local oldVal = lastTelemetryState[key]
    
    -- 1. Mitigação de IPC Flood O(N):
    -- Se a propriedade está nula na engine de física E no Shadow DOM,
    -- o estado é idêntico e indefinido. Não aloque banda de rede/IPC.
    if newVal == nil and oldVal == nil then 
        return false 
    end
    
    -- 2. Type Transition & Cache Invalidation:
    -- Se ocorreu uma transição de Floating Point para Nil (ou vice-versa),
    -- o estado sofreu mutação absoluta. Grave a transição na cache e notifique o CEF.
    if newVal == nil or oldVal == nil then
        deltaPayload[key] = newVal
        lastTelemetryState[key] = newVal
        return true
    end
    
    -- 3. Inversão Algébrica FPU (Zero-Allocation):
    -- Ambos os valores são provados como numéricos. O processador está seguro.
    threshold = threshold or TELEMETRY_EPSILON
    if math.abs(newVal - oldVal) > (threshold * math.max(math.abs(oldVal), 1.0)) then
        deltaPayload[key] = newVal
        lastTelemetryState[key] = newVal
        return true
    end
    
    return false
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
            if not now then
                Citizen.Wait(SAMPLE_INTERVAL)
            else
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

                -- Inputs for precise measurement starting
                local isThrottling = IsControlPressed(0, 32) or IsControlPressed(0, 87) or IsControlPressed(2, 71) -- W, Gamepad throttle
                local isBraking = IsControlPressed(0, 72) or IsControlPressed(0, 76) or IsControlPressed(2, 72) or IsControlPressed(0, 88) -- S, Handbrake, Gamepad brake

                -- ── 0→100 state machine ──────────────────────────
                local sm01 = currentVersion.sm_0_100
                if sm01.phase == 'waiting' and speedKMH < 2.0 then
                    sm01.phase = 'ready'
                elseif sm01.phase == 'ready' and speedKMH >= 2.0 and isThrottling then
                    sm01.phase     = 'measuring'
                    sm01.startTime = now
                    sm01.startSpd  = speedKMH
                elseif sm01.phase == 'measuring' then
                    if speedKMH >= 100 then
                        sm01.phase = 'done'
                        local elapsed = (now - sm01.startTime) / 1000.0
                        -- Interpolate back to exact 100 if we overshot
                        if sm01.startSpd then
                            local overshoot = (speedKMH - 100) / (speedKMH - sm01.startSpd)
                            elapsed = elapsed - (overshoot * SAMPLE_INTERVAL / 1000.0)
                        end
                        currentVersion.time0_100 = math.max(0.1, elapsed)
                    elseif not isThrottling and speedKMH < 5.0 then
                        -- Reset if they aborted the run
                        sm01.phase = 'waiting'
                    end
                end

                -- ── 0→200 state machine ──────────────────────────
                local sm02 = currentVersion.sm_0_200
                if sm02.phase == 'waiting' and speedKMH < 2.0 then
                    sm02.phase = 'ready'
                elseif sm02.phase == 'ready' and speedKMH >= 2.0 and isThrottling then
                    sm02.phase     = 'measuring'
                    sm02.startTime = now
                elseif sm02.phase == 'measuring' then
                    if speedKMH >= 200 then
                        sm02.phase = 'done'
                        currentVersion.time0_200 = (now - sm02.startTime) / 1000.0
                    elseif not isThrottling and speedKMH < 5.0 then
                        sm02.phase = 'waiting'
                    end
                end

                -- ── 100→0 state machine ──────────────────────────
                local sm10 = currentVersion.sm_100_0
                if sm10.phase == 'waiting' and speedKMH >= 100 then
                    sm10.phase = 'ready'
                elseif sm10.phase == 'ready' then
                    if isBraking then
                        sm10.phase     = 'measuring'
                        sm10.startTime = now
                        sm10.startPos  = vector3(pos.x, pos.y, pos.z)
                        sm10.startSpd  = speedKMH
                    elseif speedKMH < 90 then
                        -- Reset if speed drops below target without braking
                        sm10.phase = 'waiting'
                    end
                elseif sm10.phase == 'measuring' then
                    if speedKMH < 2.0 then
                        sm10.phase = 'done'
                        local endTime = now
                        local dist    = #(vector3(pos.x, pos.y, pos.z) - sm10.startPos)
                        currentVersion.time100_0 = (endTime - sm10.startTime) / 1000.0
                        currentVersion.dist100_0 = dist
                        -- Reset so it can be triggered again
                        sm10.phase = 'waiting'
                    elseif not isBraking and speedKMH > sm10.startSpd then
                        -- Aborted braking run by accelerating again
                        sm10.phase = 'waiting'
                    end
                end

                -- ── 200→0 state machine ──────────────────────────
                local sm20 = currentVersion.sm_200_0
                if sm20.phase == 'waiting' and speedKMH >= 200 then
                    sm20.phase = 'ready'
                elseif sm20.phase == 'ready' then
                    if isBraking then
                        sm20.phase     = 'measuring'
                        sm20.startTime = now
                        sm20.startPos  = vector3(pos.x, pos.y, pos.z)
                        sm20.startSpd  = speedKMH
                    elseif speedKMH < 180 then
                        sm20.phase = 'waiting'
                    end
                elseif sm20.phase == 'measuring' then
                    if speedKMH < 2.0 then
                        sm20.phase = 'done'
                        local endTime = now
                        local dist    = #(vector3(pos.x, pos.y, pos.z) - sm20.startPos)
                        currentVersion.time200_0 = (endTime - sm20.startTime) / 1000.0
                        currentVersion.dist200_0 = dist
                        sm20.phase = 'waiting'
                    elseif not isBraking and speedKMH > sm20.startSpd then
                        sm20.phase = 'waiting'
                    end
                end

                -- Delta-Encoding: apenas campos com mutação além de ε são despachados via IPC
                -- Payload deltaPayload é pré-alocado (Zero-Allocation), anulado após despacho
                if isNuiOpen then
                    -- checkDelta usa inversão algébrica FMUL (poupa FDIV) e threshold ε = 1%
                    local changed = false

                    if checkDelta('speed', speedKMH) then changed = true end
                    if checkDelta('maxSpeed', currentVersion.maxSpeed) then changed = true end
                    if checkDelta('gForce', gForce, 0.05) then changed = true end          -- ε = 5% (gForce é mais ruidoso)
                    if checkDelta('time0_100', currentVersion.time0_100) then changed = true end
                    if checkDelta('time0_200', currentVersion.time0_200) then changed = true end
                    if checkDelta('time100_0', currentVersion.time100_0) then changed = true end
                    if checkDelta('dist100_0', currentVersion.dist100_0) then changed = true end
                    if checkDelta('time200_0', currentVersion.time200_0) then changed = true end
                    if checkDelta('dist200_0', currentVersion.dist200_0) then changed = true end
                    if checkDelta('bestGForce', currentVersion.bestGForce) then changed = true end

                    -- Campo booleano isRecording: envia no primeiro frame apenas
                    if lastTelemetryState.isRecording ~= true then
                        deltaPayload.isRecording = true
                        lastTelemetryState.isRecording = true
                        changed = true
                    end

                    -- Só despacha via IPC se houver ao menos uma mutação significativa
                    if changed then
                        SendNUIMessage(deltaPayload)
                    end

                    -- Reset das chaves mortas: anula ponteiros em O(1) sem realocar a tabela
                    ResetDeltaPayload()
                end

                Citizen.Wait(SAMPLE_INTERVAL)
            end
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
        
        -- Include active performance setup in telemetry clipboard!
        if ver.activePerf then
            local remapInfo = "None"
            if ver.activePerf.remap and ver.activePerf.remap.final_stats then
                local stats = ver.activePerf.remap.final_stats
                remapInfo = string.format("TS %d / AC %d / HD %d / BR %d", stats.top_speed or 50, stats.acceleration or 50, stats.handling or 50, stats.braking or 50)
            end
            table.insert(lines, '  Remap Setup : ' .. remapInfo)
            
            local tuneInfo = "Stock"
            if ver.activePerf.tune and ver.activePerf.tune.parts then
                local parts = ver.activePerf.tune.parts
                local partsList = {}
                local categories = {
                    { key = 'engine', label = 'Eng' },
                    { key = 'transmission', label = 'Trn' },
                    { key = 'turbo', label = 'Trb' },
                    { key = 'suspension', label = 'Sus' },
                    { key = 'brakes', label = 'Brk' },
                    { key = 'tires', label = 'Trs' },
                    { key = 'weight', label = 'Wgt' },
                    { key = 'ecu', label = 'ECU' }
                }
                for _, cat in ipairs(categories) do
                    local lvl = (parts[cat.key] or 'stock'):upper()
                    table.insert(partsList, cat.label .. ': ' .. lvl)
                end
                tuneInfo = table.concat(partsList, ' | ')
            end
            table.insert(lines, '  Tuning Parts: ' .. tuneInfo)
            
            if ver.activePerf.tune and ver.activePerf.tune.drivetrain then
                table.insert(lines, '  Drivetrain  : ' .. tostring(ver.activePerf.tune.drivetrain))
            end
        end

        -- Include actual XML-level live handling memory values!
        if ver.handlingXML and ver.handlingXML.fInitialDriveMaxFlatVel then
            local h = ver.handlingXML
            table.insert(lines, string.format('  XML FlatVel : %.2f mph  /  Force: %.4f  /  Drag: %.2f', 
                h.fInitialDriveMaxFlatVel, h.fInitialDriveForce, h.fInitialDragCoeff))
            table.insert(lines, string.format('  XML Traction: Max: %.3f  /  Min: %.3f  /  BrakeForce: %.2f', 
                h.fTractionCurveMax, h.fTractionCurveMin, h.fBrakeForce))
            table.insert(lines, string.format('  XML Suspen. : Force: %.3f  /  Damp: %.3f  /  Raise: %.3f', 
                h.fSuspensionForce, h.fSuspensionCompDamp, h.fSuspensionRaise))
        end

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
    lastVersionCreateTime = 0  -- reseta cooldown ao iniciar gravação

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
