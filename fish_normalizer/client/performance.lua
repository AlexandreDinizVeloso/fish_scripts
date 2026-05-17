--[[
    FISH Normalizer - Performance Application (Refatorado O(1))
    
    Mudanças:
    - Polling loop removido → Event-Driven via gameEventTriggered
    - plateCache por ID de entidade → O(1) lookup, 1 alocação/veículo
    - appliedValues como single source of truth → delta checking sem ler natives
    - entityRemoved handler → desalocação determinística de memória
    - Zero alocações de string no game thread
]]

-- ==========================================================
-- ALOCAÇÃO DE ESTADO LOCAL (Heap Controlado)
-- ==========================================================
local originalHandlingCache = {}    -- Original base handling values (cleared on reapply)
local originalSuspensionCache = {}  -- Persistent authentic suspension values (never cleared)
local remapData = {}                -- Remap data pushed from fish_remaps
local tuneData = {}                 -- Tune data pushed from fish_tunes
local appliedPlates = {}            -- Track which plates have been applied this session
local appliedValues = {}            -- Últimos valores escritos via native (Single Source of Truth)
local plateCache = {}               -- Entity-indexed plate cache O(1)
local isReady = false               -- Pub-Sub Ready State Flag

local m_abs = math.abs

-- ==========================================================
-- GERENCIADOR DE CACHE DE PLACA (Entity-Indexed O(1))
-- ==========================================================
local function GetVehiclePlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    
    if not plateCache[vehicle] then
        -- string.gsub é alocado apenas UMA VEZ por veículo
        plateCache[vehicle] = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
    end
    
    return plateCache[vehicle]
end

-- ==========================================================
-- Data Push Event Handlers
-- ==========================================================

-- Listen for remap updates from fish_remaps
RegisterNetEvent('fish_remaps:performanceUpdated')
AddEventHandler('fish_remaps:performanceUpdated', function(plate, data)
    remapData[plate] = data
    appliedPlates[plate] = nil  -- Force reapplication
    
    -- Reapply immediately if player is in this vehicle
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local currentPlate = GetVehiclePlate(vehicle)
            if currentPlate == plate then
                ApplyPerformanceModifications(vehicle)
            end
        end
    end
end)

-- Listen for tune updates from fish_tunes
RegisterNetEvent('fish_tunes:performanceUpdated')
AddEventHandler('fish_tunes:performanceUpdated', function(plate, data)
    tuneData[plate] = data
    appliedPlates[plate] = nil  -- Force reapplication
    
    -- Reapply immediately if player is in this vehicle
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local currentPlate = GetVehiclePlate(vehicle)
            if currentPlate == plate then
                ApplyPerformanceModifications(vehicle)
            end
        end
    end
end)

-- Listen for reapply requests from other resources
RegisterNetEvent('fish_normalizer:requestReapply')
AddEventHandler('fish_normalizer:requestReapply', function(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        local plate = GetVehiclePlate(vehicle)
        originalHandlingCache[plate] = nil  -- Reset cache to get fresh base values
        appliedPlates[plate] = nil
        appliedValues[plate] = nil
        ApplyPerformanceModifications(vehicle)
    end
end)

-- ==========================================================
-- Remap Multiplier Calculation
-- ==========================================================

local function GetRemapMultipliers(plate)
    local remap = remapData[plate]
    
    if not remap or not remap.finalStats then
        return {
            top_speed = 1.0,
            acceleration = 1.0,
            handling = 1.0,
            braking = 1.0
        }
    end
    
    -- Normalize stats from 0-100 to multipliers (0.8x to 1.2x)
    local stats = remap.finalStats
    return {
        top_speed = 0.8 + (stats.top_speed or 50) / 100 * 0.4,
        acceleration = 0.8 + (stats.acceleration or 50) / 100 * 0.4,
        handling = 0.8 + (stats.handling or 50) / 100 * 0.4,
        braking = 0.8 + (stats.braking or 50) / 100 * 0.4
    }
end

-- ==========================================================
-- Tune Bonus Calculation
-- ==========================================================

local function GetTuneMultipliers(plate)
    local tune = tuneData[plate]
    
    if not tune then
        return {
            top_speed = 0,
            acceleration = 0,
            handling = 0,
            braking = 0
        }
    end
    
    -- Check if exports are ready before proceeding
    if GetResourceState('fish_tunes') == 'started' then
        local ready = pcall(function() return exports.fish_tunes:GetPartBonuses('engine', 'stock') end)
        if not ready then
            return nil  -- Signals to caller that exports are not ready yet, retry required
        end
    end
    
    -- Calculate total bonuses from parts
    local totalBonuses = { top_speed = 0, acceleration = 0, handling = 0, braking = 0 }
    
    if tune.parts then
        for category, level in pairs(tune.parts) do
            -- Try to get bonuses from the tunes config
            local success, bonuses = pcall(function()
                return exports.fish_tunes:GetPartBonuses(category, level)
            end)
            if success and bonuses then
                for stat, val in pairs(bonuses) do
                    if stat ~= 'instability' and stat ~= 'durability_loss' and totalBonuses[stat] then
                        totalBonuses[stat] = totalBonuses[stat] + val
                    end
                end
            end
        end
    end
    
    -- If we have pre-calculated bonuses from the data, use those
    if tune.bonuses then
        for stat, val in pairs(tune.bonuses) do
            if totalBonuses[stat] ~= nil then
                totalBonuses[stat] = val
            end
        end
    end
    
    return totalBonuses
end

-- ==========================================================
-- Helper: Apply GTA V Native Modifications based on parts
-- ==========================================================

local function ApplyNativeMods(vehicle, parts)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleModKit(vehicle, 0)

    if not parts then
        -- Reset all native performance mods to stock if no parts data
        SetVehicleMod(vehicle, 11, -1, false) -- Engine
        SetVehicleMod(vehicle, 12, -1, false) -- Brakes
        SetVehicleMod(vehicle, 13, -1, false) -- Transmission
        SetVehicleMod(vehicle, 15, -1, false) -- Suspension
        ToggleVehicleMod(vehicle, 18, false)  -- Turbo
        return
    end

    -- Engine mod mapping (0 to 3)
    local engineLvl = parts.engine or 'stock'
    if engineLvl == 'l1' then SetVehicleMod(vehicle, 11, 0, false)
    elseif engineLvl == 'l2' then SetVehicleMod(vehicle, 11, 1, false)
    elseif engineLvl == 'l3' then SetVehicleMod(vehicle, 11, 2, false)
    elseif engineLvl == 'l4' or engineLvl == 'l5' then SetVehicleMod(vehicle, 11, 3, false)
    else SetVehicleMod(vehicle, 11, -1, false) end

    -- Brakes mod mapping (0 to 2)
    local brakesLvl = parts.brakes or 'stock'
    if brakesLvl == 'l1' then SetVehicleMod(vehicle, 12, 0, false)
    elseif brakesLvl == 'l2' then SetVehicleMod(vehicle, 12, 1, false)
    elseif brakesLvl == 'l3' or brakesLvl == 'l4' or brakesLvl == 'l5' then SetVehicleMod(vehicle, 12, 2, false)
    else SetVehicleMod(vehicle, 12, -1, false) end

    -- Transmission mod mapping (0 to 2)
    local transLvl = parts.transmission or 'stock'
    if transLvl == 'l1' then SetVehicleMod(vehicle, 13, 0, false)
    elseif transLvl == 'l2' then SetVehicleMod(vehicle, 13, 1, false)
    elseif transLvl == 'l3' or transLvl == 'l4' or transLvl == 'l5' then SetVehicleMod(vehicle, 13, 2, false)
    else SetVehicleMod(vehicle, 13, -1, false) end

    -- Suspension mod mapping (0 to 3)
    local suspLvl = parts.suspension or 'stock'
    if suspLvl == 'l1' then SetVehicleMod(vehicle, 15, 0, false)
    elseif suspLvl == 'l2' then SetVehicleMod(vehicle, 15, 1, false)
    elseif suspLvl == 'l3' then SetVehicleMod(vehicle, 15, 2, false)
    elseif suspLvl == 'l4' or suspLvl == 'l5' then SetVehicleMod(vehicle, 15, 3, false)
    else SetVehicleMod(vehicle, 15, -1, false) end

    -- Turbo mod mapping
    local turboLvl = parts.turbo or 'stock'
    if turboLvl ~= 'stock' then
        ToggleVehicleMod(vehicle, 18, true)
    else
        ToggleVehicleMod(vehicle, 18, false)
    end
end

-- ==========================================================
-- Delta Checking Helper (Bypass C++/Lua Boundary)
-- ==========================================================
-- Só chama SetVehicleHandlingFloat se o valor difere do cache local.
-- Zero leituras de GetVehicleHandlingFloat em loop quente.
local function SetHandlingFloatIfChanged(vehicle, handlingType, fieldName, newValue, plate)
    local lastApplied = appliedValues[plate]
    if not lastApplied then
        lastApplied = {}
        appliedValues[plate] = lastApplied
    end
    
    local current = lastApplied[fieldName]
    if current == nil or m_abs(current - newValue) > 0.001 then
        SetVehicleHandlingFloat(vehicle, handlingType, fieldName, newValue)
        lastApplied[fieldName] = newValue
    end
end

-- ==========================================================
-- Main Performance Application
-- ==========================================================

function ApplyPerformanceModifications(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = GetVehiclePlate(vehicle)
    if not plate then return end
    
    -- Request the server to push/restore the entity state bag on first encounter
    if not appliedPlates[plate] then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        if netId and netId > 0 then
            TriggerServerEvent('fish_normalizer:pushVehicleState', plate, netId)
        end
    end
    
    -- Retrieve authoritative base handling profile from server state bag to completely prevent compounding loops
    local physicsMatrix = Entity(vehicle).state['fish_physics_matrix']
    local stateBagProfile = physicsMatrix and physicsMatrix.handling
    local fishScore = physicsMatrix and physicsMatrix.score
    
    -- Guard: If vehicle is unnormalized (has no score in state bag after a brief check), exit and leave stock vanilla untouched
    if not fishScore and not stateBagProfile then
        return
    end
    
    -- Get tune bonuses (raw percentage values from fish_tunes config)
    local tuneBonus = GetTuneMultipliers(plate)
    if not tuneBonus then
        -- Exports not fully ready yet, do NOT mark as applied, retry on next frame/entry
        return
    end
    
    local cache = {}
    
    if stateBagProfile and type(stateBagProfile) == 'table' then
        cache = {
            fInitialDriveMaxFlatVel = stateBagProfile.fInitialDriveMaxFlatVel or 124.20,
            fInitialDriveForce = stateBagProfile.fInitialDriveForce or 0.3286,
            fBrakeForce = stateBagProfile.fBrakeForce or 0.60,
            fTractionCurveMax = stateBagProfile.fTractionCurveMax or 1.802,
            fTractionCurveMin = stateBagProfile.fTractionCurveMin or 1.545,
            fInitialDragCoeff = stateBagProfile.fInitialDragCoeff or 6.72
        }
        originalHandlingCache[plate] = cache
    else
        -- Fallback to current vehicle handling memory if state bag is not yet synced
        if not originalHandlingCache[plate] then
            originalHandlingCache[plate] = {
                fInitialDriveMaxFlatVel = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel'),
                fInitialDriveForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce'),
                fBrakeForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce'),
                fTractionCurveMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax'),
                fTractionCurveMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin'),
                fInitialDragCoeff = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDragCoeff')
            }
        end
        cache = originalHandlingCache[plate]
    end
    
    -- Cache authentic suspension values only ONCE per session (NEVER cleared, preserving unmodified stock values)
    if not originalSuspensionCache[plate] then
        originalSuspensionCache[plate] = {
            fSuspensionForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce'),
            fSuspensionCompDamp = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionCompDamp'),
            fSuspensionReboundDamp = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionReboundDamp')
        }
    end
    
    cache = originalHandlingCache[plate]
    local suspCache = originalSuspensionCache[plate]
    
    -- Get remap multipliers (maps finalStats 0-100 to 0.8x to 1.2x)
    local remapMult = GetRemapMultipliers(plate)
    
    -- Start from base values
    local finalTopSpeed = cache.fInitialDriveMaxFlatVel
    local finalAccel = cache.fInitialDriveForce
    local finalBraking = cache.fBrakeForce
    local finalTractionMax = cache.fTractionCurveMax
    local finalTractionMin = cache.fTractionCurveMin
    local finalDrag = cache.fInitialDragCoeff

    -- Apply native vehicle mods based on custom parts
    local tune = tuneData[plate]
    ApplyNativeMods(vehicle, tune and tune.parts)
    
    -- Layer 1: Apply remap multipliers (multiplicative from base)
    finalTopSpeed = finalTopSpeed * remapMult.top_speed
    finalAccel = finalAccel * remapMult.acceleration
    finalBraking = finalBraking * remapMult.braking
    finalTractionMax = finalTractionMax * remapMult.handling
    finalTractionMin = finalTractionMin * remapMult.handling
    
    -- Layer 2: Apply calibrated tune bonuses
    finalTopSpeed = finalTopSpeed * (1.0 + (tuneBonus.top_speed / 320.0))
    finalAccel = finalAccel * (1.0 + (tuneBonus.acceleration / 400.0))
    finalBraking = finalBraking * (1.0 + (tuneBonus.braking / 120.0))
    finalTractionMax = finalTractionMax * (1.0 + (tuneBonus.handling / 200.0))
    finalTractionMin = finalTractionMin * (1.0 + (tuneBonus.handling / 200.0))
    
    -- Layer 3: Apply drivetrain layout multipliers (Clean Consolidation)
    local drivetrain = physicsMatrix and physicsMatrix.drivetrain
    if not drivetrain then
        drivetrain = tune and tune.drivetrain
    end
    if not drivetrain then
        local driveBias = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveBiasFront')
        if driveBias == 0.0 then drivetrain = "RWD"
        elseif driveBias == 1.0 then drivetrain = "FWD"
        else drivetrain = "AWD" end
    end

    -- Physically apply drivetrain layout under network authority check to prevent physical simulation thrashing
    if NetworkHasControlOfEntity(vehicle) and GetResourceState('fish_tunes') == 'started' then
        pcall(function()
            exports.fish_tunes:ApplyDrivetrainModifiers(vehicle, drivetrain)
        end)
    end
    
    local dtForceMult = 1.0
    local dtTopSpeedMult = 1.0
    local dtTractionMult = 1.0
    
    if drivetrain == "RWD" then
        dtForceMult = 1.10
        dtTopSpeedMult = 1.0
        dtTractionMult = 0.95
    elseif drivetrain == "FWD" then
        dtForceMult = 1.10
        dtTopSpeedMult = 0.95
        dtTractionMult = 1.05
    elseif drivetrain == "AWD" then
        dtForceMult = 1.25
        dtTopSpeedMult = 0.90
        dtTractionMult = 1.15
    end
    
    finalTopSpeed = finalTopSpeed * dtTopSpeedMult
    finalAccel = finalAccel * dtForceMult
    finalTractionMax = finalTractionMax * dtTractionMult
    finalTractionMin = finalTractionMin * dtTractionMult
    
    -- Layer 4: Apply engine swap power scaling
    local engineData = tune and (tune.engine_swap or tune.engine)
    if engineData and type(engineData) == 'table' then
        local basePower = engineData.base_power or 100
        local healthMult = 1.0
        if engineData.current_power and engineData.base_power and engineData.base_power > 0 then
            healthMult = engineData.current_power / engineData.base_power
        end
        local powerScale = 1.0 + ((basePower - 100) / 200.0)
        powerScale = powerScale * healthMult
        
        finalAccel = finalAccel * powerScale
        
        if basePower > 100 then
            local speedBonus = 1.0 + ((basePower - 100) / 500.0)
            finalTopSpeed = finalTopSpeed * speedBonus
        end
    end
    
    -- FIX: Drag reduction - properly calculated and NOT overwritten
    -- Reduced drag for top speed tunes (linear decrease from 0 to 30% reduction)
    local dragReduction = 1.0 - math.min(0.30, (tuneBonus.top_speed / 150.0))
    finalDrag = cache.fInitialDragCoeff * dragReduction

    -- Calculate upgraded suspension physical values based on suspension level
    local finalSuspForce = suspCache.fSuspensionForce
    local finalSuspCompDamp = suspCache.fSuspensionCompDamp
    local finalSuspReboundDamp = suspCache.fSuspensionReboundDamp
    local finalSuspRaise = 0.0

    if tune and tune.parts and tune.parts.suspension then
        local suspLvl = tune.parts.suspension
        local forceMult = 1.0
        local dampMult = 1.0
        local raiseOffset = 0.0

        if suspLvl == 'l1' then
            forceMult = 1.05
            dampMult = 1.08
            raiseOffset = 0.002
        elseif suspLvl == 'l2' then
            forceMult = 1.10
            dampMult = 1.15
            raiseOffset = 0.004
        elseif suspLvl == 'l3' then
            forceMult = 1.18
            dampMult = 1.25
            raiseOffset = 0.008
        elseif suspLvl == 'l4' then
            forceMult = 1.24
            dampMult = 1.35
            raiseOffset = 0.012
        elseif suspLvl == 'l5' then
            forceMult = 1.30       -- Stable +30% spring stiffness (preventing the trampoline bounce glitch)
            dampMult = 1.45        -- Stable +45% dampening (clean spring control)
            raiseOffset = 0.016    -- 1.6cm clearance raise to offset visual slammed scraping
        end

        finalSuspForce = finalSuspForce * forceMult
        finalSuspCompDamp = finalSuspCompDamp * dampMult
        finalSuspReboundDamp = finalSuspReboundDamp * dampMult
        finalSuspRaise = raiseOffset
    end
    
    -- ==========================================================
    -- Layer 5: Native Upgrade Compensation
    -- ==========================================================
    -- GTA V's native Engine, Turbo, and Transmission mods add massive hardcoded torque and speed scaling factors.
    -- We divide the XML values by these native boosts so that the final physical speed and acceleration exactly match our targets.
    local nativeSpeedComp = 1.0
    local nativeAccelComp = 1.0
    
    if tune and tune.parts then
        local parts = tune.parts
        -- Native Engine Mod Boost (L1: +3% Speed/5% Accel, L2: +6% Speed/10% Accel, L3: +10% Speed/15% Accel, L4/L5: +15% Speed/25% Accel)
        if parts.engine == 'l1' then 
            nativeSpeedComp = nativeSpeedComp * 1.03
            nativeAccelComp = nativeAccelComp * 1.05
        elseif parts.engine == 'l2' then 
            nativeSpeedComp = nativeSpeedComp * 1.06
            nativeAccelComp = nativeAccelComp * 1.10
        elseif parts.engine == 'l3' then 
            nativeSpeedComp = nativeSpeedComp * 1.10
            nativeAccelComp = nativeAccelComp * 1.15
        elseif parts.engine == 'l4' or parts.engine == 'l5' then 
            nativeSpeedComp = nativeSpeedComp * 1.15
            nativeAccelComp = nativeAccelComp * 1.25
        end
        
        -- Native Turbo Mod Boost (+10% Speed, +25% Accel)
        if parts.turbo and parts.turbo ~= 'stock' then
            nativeSpeedComp = nativeSpeedComp * 1.10
            nativeAccelComp = nativeAccelComp * 1.25
        end
        
        -- Native Transmission Mod Boost (L1: +2% Speed, L2: +4% Speed, L3/L4/L5: +6% Speed)
        if parts.transmission == 'l1' then 
            nativeSpeedComp = nativeSpeedComp * 1.02
        elseif parts.transmission == 'l2' then 
            nativeSpeedComp = nativeSpeedComp * 1.04
        elseif parts.transmission == 'l3' or parts.transmission == 'l4' or parts.transmission == 'l5' then 
            nativeSpeedComp = nativeSpeedComp * 1.06
        end
    end
    
    -- GTA V's native Engine, Turbo, and Transmission mods add massive hardcoded torque, but fInitialDriveMaxFlatVel is a hard limit.
    -- We only divide fInitialDriveForce by a soft-dampened nativeAccelComp (40% damping factor) to maintain launch launch-power
    -- while still capping overall acceleration at target class bounds.
    local compensatedAccelComp = 1.0 + (nativeAccelComp - 1.0) * 0.40
    finalAccel = finalAccel / compensatedAccelComp
    
    -- Aplica modificações com delta checking (Lua-side single source of truth)
    -- Zero leituras GetVehicleHandlingFloat — comparamos contra cache appliedValues
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel", finalTopSpeed, plate)
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fInitialDriveForce", finalAccel, plate)
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fBrakeForce", finalBraking, plate)
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fTractionCurveMax", finalTractionMax, plate)
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fTractionCurveMin", finalTractionMin, plate)
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fInitialDragCoeff", finalDrag, plate)
    
    -- Aplica modificações de suspensão com delta checking
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fSuspensionForce", finalSuspForce, plate)
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fSuspensionCompDamp", finalSuspCompDamp, plate)
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fSuspensionReboundDamp", finalSuspReboundDamp, plate)
    SetHandlingFloatIfChanged(vehicle, "CHandlingData", "fSuspensionRaise", finalSuspRaise, plate)

    -- Force handling changes to take effect (FiveM workaround)
    if GetResourceState('fish_tunes') == 'started' then
        pcall(function() exports.fish_tunes:ForceHandlingRefresh(vehicle) end)
    else
        SetVehicleModKit(vehicle, 0)
        for i = 0, 35 do
            SetVehicleMod(vehicle, i, GetVehicleMod(vehicle, i), false)
        end
    end

    -- FIX: Engine power buff properly applied and NOT reset
    -- Acceleration tune now gives a subtle power multiplier
    local enginePowerBuff = 1.0 + (tuneBonus.acceleration / 400.0)
    ModifyVehicleTopSpeed(vehicle, enginePowerBuff)
    
    -- Set entity max speed (1.3x factor for handling-to-actual speed difference)
    -- fInitialDriveMaxFlatVel is in mph, convert to m/s
    SetEntityMaxSpeed(vehicle, (finalTopSpeed * enginePowerBuff * 1.35) / 2.236936)
    SetVehicleMaxSpeed(vehicle, 0.0)
    
    appliedPlates[plate] = true
end

-- ==========================================================
-- State Synchronization: Wait for fish_tunes to load
-- Handles late joiners in O(1) and detaches immediately to clear LuaJIT heap
-- ==========================================================
local function InitializeNormalizer()
    if isReady then return end
    isReady = true
    print('[fish_normalizer] PI Normalizer initialized and active.')
    TriggerServerEvent('fish_normalizer:requestPerformanceData')
end

Citizen.CreateThread(function()
    -- Late Joiner Check: If server is already ready, initialize immediately
    if GlobalState.fish_tunes_ready then
        InitializeNormalizer()
        return
    end

    -- Early Joiner / Restart Fallback: Listen for dynamic state bag replication
    local initHandler
    initHandler = AddStateBagChangeHandler('fish_tunes_ready', 'global', function(bagName, key, value, _, replicated)
        if value then
            InitializeNormalizer()
            if initHandler then
                RemoveStateBagChangeHandler(initHandler)
                initHandler = nil
            end
        end
    end)
end)

-- ==========================================================
-- EVENT-DRIVEN VEHICLE ENTRY DETECTION (Substitui Polling Loop)
-- ==========================================================
-- Escuta CEventNetworkPlayerEnteredVehicle via gameEventTriggered
-- Zero alocações no game thread — apenas reage a transições de estado

AddEventHandler('gameEventTriggered', function(eventName, args)
    if not isReady then return end
    
    if eventName == 'CEventNetworkPlayerEnteredVehicle' then
        local playerPed = args[1]  -- Ped do jogador que entrou
        local vehicle = args[2]     -- Veículo alvo
        
        -- Verifica se o jogador local é o que entrou
        if playerPed == PlayerPedId() then
            local plate = GetVehiclePlate(vehicle)
            if plate then
                -- Popula cache inicial de handling se ainda não existir
                if not originalHandlingCache[plate] then
                    originalHandlingCache[plate] = {
                        fInitialDriveMaxFlatVel = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel'),
                        fInitialDriveForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce'),
                        fBrakeForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce'),
                        fTractionCurveMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax'),
                        fTractionCurveMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin'),
                        fInitialDragCoeff = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDragCoeff')
                    }
                end
                
                -- Aciona a avaliação (delta checking impede natives se não houver mudança)
                ApplyPerformanceModifications(vehicle)
            end
        end
    end
end)

-- ==========================================================
-- GERENCIAMENTO DE MEMÓRIA (Garbage Collection Manual)
-- ==========================================================
-- Escuta entityRemoved e desaloca todos os caches do veículo deletado
-- Previne memory leak progressivo em sessões longas

AddEventHandler('entityRemoved', function(entity)
    -- Se a entidade não é veículo, ignoramos
    if GetEntityType(entity) ~= 2 then return end
    
    -- Verifica se temos cache para esta entidade
    if plateCache[entity] then
        local plate = plateCache[entity]
        
        -- Desalocação determinística de todos os sub-caches
        originalHandlingCache[plate] = nil
        originalSuspensionCache[plate] = nil
        appliedPlates[plate] = nil
        appliedValues[plate] = nil
        plateCache[entity] = nil
    end
end)

-- ==========================================================
-- Server Data Sync (receive saved data on connect)
-- ==========================================================

RegisterNetEvent('fish_normalizer:receivePerformanceData')
AddEventHandler('fish_normalizer:receivePerformanceData', function(rData, tData)
    local syncPlates = {}
    if rData then
        for plate, data in pairs(rData) do
            remapData[plate] = data
            appliedPlates[plate] = nil  -- Clear cache to force reapplication
            syncPlates[plate] = true
        end
    end
    if tData then
        for plate, data in pairs(tData) do
            tuneData[plate] = data
            appliedPlates[plate] = nil  -- Clear cache to force reapplication
            syncPlates[plate] = true
        end
    end

    -- If player is inside one of the synced vehicles, reapply its handling immediately
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local plate = GetVehiclePlate(vehicle)
            if syncPlates[plate] then
                originalHandlingCache[plate] = nil  -- Clear base handling cache to read fresh state bag value
                ApplyPerformanceModifications(vehicle)
            end
        end
    end
end)

exports('ClearDrivetrainCache', function(plate)
    originalHandlingCache[plate] = nil
    appliedPlates[plate] = nil
end)

exports('GetActivePerformanceData', function(plate)
    return {
        tune = tuneData[plate],
        remap = remapData[plate]
    }
end)