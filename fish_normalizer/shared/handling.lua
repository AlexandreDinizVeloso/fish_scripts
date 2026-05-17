-- ============================================================
-- fish_normalizer: Shared Handling Engine
-- Pure functions to build and apply vehicle handling profiles.
-- Loaded as a shared_script, but ApplyHandlingToVehicle is
-- client-only. Server uses BuildHandlingProfile only.
-- ============================================================

HandlingEngine = {}

-- ============================================================
-- Handling Key Mappings
-- Maps our abstract stats → FiveM SetVehicleHandling keys
-- ============================================================

-- Base reference values for a "neutral" stock vehicle
local BASE_HANDLING = {
    -- Drive
    fInitialDriveMaxFlatVel        = 155.0,  -- Aligned with XMLs (midpoint between 148 and 162)
    fInitialDriveForce             = 0.35,   -- Stock force baseline
    fDriveInertia                  = 1.10,
    fDriveBiasFront                = 0.35,   -- RWD-leaning AWD for better corner exit
    nInitialDriveGears             = 6,      
    fClutchChangeRateScaleUpShift  = 2.5,    -- Fast shifts based on XML (2.0 to 3.3)
    fClutchChangeRateScaleDownShift = 2.5,
    -- Traction
    fTractionCurveMax              = 2.10,   -- Based on XMLs (1.80 to 2.40)
    fTractionCurveMin              = 1.85,
    fTractionCurveLateral          = 22.0,   
    fTractionLossMult              = 1.0,
    fLowSpeedTractionLossMult      = 1.0,    
    fTractionBiasFront             = 0.49,   
    fTractionSpringDeltaMax        = 0.10,   
    fCamberStiffnesss              = 0.0,    
    -- Steering
    fSteeringLock                  = 40.0,   -- XMLs use 40-42
    -- Suspension
    fSuspensionForce               = 2.6,    -- Firmer suspension based on XMLs (2.2 to 3.5)
    fSuspensionCompDamp            = 1.5,    
    fSuspensionReboundDamp         = 1.6,    
    fSuspensionDampingReboundSlow  = 0.25,
    fSuspensionUpperLimit          = 0.10,   
    fSuspensionLowerLimit          = -0.12,  
    fSuspensionRaise               = 0.0,    
    fSuspensionBiasFront           = 0.50,   
    fAntiRollBarForce              = 0.4,    
    fAntiRollBarBiasFront          = 0.50,   
    fRollCentreHeightFront         = 0.25,   -- Increased stability from XMLs
    fRollCentreHeightRear          = 0.25,
    -- Brakes
    fBrakeForce                    = 0.55,
    fBrakeBiasFront                = 0.65,   -- Heavy front braking per XML
    fHandBrakeForce                = 0.65,
    -- Body
    fMass                          = 1500.0,
    fInitialDragCoeff              = 7.5,    -- Critical: Balanced drag (XMLs use 6.0 to 10.0)
    fDownForceModifier             = 1.0,    
    fPercentSubmerged              = 85.0,   
    fDeformationDamageMult         = 0.8,
    fWeaponDamageMult              = 1.0,
    fCollisionDamageMult           = 0.8,
    fEngineDamageMult              = 1.0,
}

-- ============================================================
-- Archetype Handling Personality Profiles
-- Each archetype overrides base values differently.
-- Values are MULTIPLIERS applied to the base.
-- ============================================================

local ARCHETYPE_PROFILES = {
    esportivo = {
        -- High cornering, lightweight, limited top speed
        fInitialDriveMaxFlatVel        = 1.02,
        fInitialDriveForce             = 1.08,
        fDriveInertia                  = 1.10,
        fTractionCurveMax              = 1.05,
        fTractionCurveMin              = 1.02,
        fTractionCurveLateral          = 1.05,  -- sharper lateral response
        fTractionLossMult              = 0.90,
        fLowSpeedTractionLossMult      = 0.85,
        fTractionBiasFront             = 0.52,  -- slight front bias
        fSteeringLock                  = 0.85,
        fSuspensionForce               = 1.20,
        fSuspensionCompDamp            = 1.15,
        fSuspensionReboundDamp         = 1.12,
        fSuspensionDampingReboundSlow  = 1.15,
        fSuspensionBiasFront           = 0.52,
        fAntiRollBarForce              = 1.25,  -- less body roll
        fAntiRollBarBiasFront          = 0.50,
        fRollCentreHeightFront         = 0.95,
        fRollCentreHeightRear          = 0.95,
        fHandBrakeForce                = 0.90,
        fBrakeForce                    = 1.10,
        fBrakeBiasFront                = 0.48,
        fMass                          = 0.75,
        fInitialDragCoeff              = 0.90,  -- low drag
        fDownForceModifier             = 1.15,  -- more grip at speed
        fClutchChangeRateScaleUpShift  = 1.15,
        fClutchChangeRateScaleDownShift = 1.15,
        fDeformationDamageMult         = 1.40,
    },
    possante = {
        -- Brutal acceleration, heavy, poor cornering
        fInitialDriveMaxFlatVel        = 0.93,
        fInitialDriveForce             = 1.30,
        fDriveInertia                  = 0.80,
        fTractionCurveMax              = 0.85,
        fTractionCurveMin              = 0.80,
        fTractionCurveLateral          = 1.15,  -- wide lateral curve = looser
        fTractionLossMult              = 1.30,
        fLowSpeedTractionLossMult      = 0.70,  -- burnouts
        fTractionBiasFront             = 0.42,  -- rear bias = oversteer
        fSteeringLock                  = 1.20,
        fSuspensionForce               = 0.90,
        fSuspensionCompDamp            = 0.85,
        fSuspensionReboundDamp         = 0.80,
        fSuspensionDampingReboundSlow  = 0.85,
        fSuspensionBiasFront           = 0.45,
        fAntiRollBarForce              = 0.80,  -- more body roll
        fAntiRollBarBiasFront          = 0.50,
        fHandBrakeForce                = 0.70,
        fBrakeForce                    = 0.85,
        fBrakeBiasFront                = 0.52,
        fMass                          = 1.35,
        fInitialDragCoeff              = 1.20,  -- high drag (brick)
        fDownForceModifier             = 0.80,
        fClutchChangeRateScaleUpShift  = 0.85,  -- slower shifts
        fClutchChangeRateScaleDownShift = 0.80,
        fDeformationDamageMult         = 0.65,
    },
    exotico = {
        -- Top speed king, stable acceleration
        fInitialDriveMaxFlatVel        = 1.08,
        fInitialDriveForce             = 1.05,
        fDriveInertia                  = 0.95,
        fTractionCurveMax              = 1.00,
        fTractionCurveMin              = 0.92,
        fTractionCurveLateral          = 0.95,
        fTractionLossMult              = 1.10,
        fLowSpeedTractionLossMult      = 1.05,
        fTractionBiasFront             = 0.48,
        fSteeringLock                  = 0.95,
        fSuspensionForce               = 1.10,
        fSuspensionCompDamp            = 1.05,
        fSuspensionReboundDamp         = 1.05,
        fSuspensionDampingReboundSlow  = 1.05,
        fSuspensionBiasFront           = 0.50,
        fAntiRollBarForce              = 1.10,
        fAntiRollBarBiasFront          = 0.50,
        fHandBrakeForce                = 1.00,
        fBrakeForce                    = 1.00,
        fBrakeBiasFront                = 0.50,
        fMass                          = 0.95,
        fInitialDragCoeff              = 0.65,  -- very low drag
        fDownForceModifier             = 1.05,
        fClutchChangeRateScaleUpShift  = 1.15,  -- fast shifts
        fClutchChangeRateScaleDownShift = 1.10,
        fDeformationDamageMult         = 1.20,
    },
    supercarro = {
        -- Balanced excellence
        fInitialDriveMaxFlatVel        = 1.08,
        fInitialDriveForce             = 1.15,
        fDriveInertia                  = 1.05,
        fTractionCurveMax              = 1.15,
        fTractionCurveMin              = 1.10,
        fTractionCurveLateral          = 0.92,
        fTractionLossMult              = 0.85,
        fLowSpeedTractionLossMult      = 0.90,
        fTractionBiasFront             = 0.50,
        fSteeringLock                  = 0.90,
        fSuspensionForce               = 1.15,
        fSuspensionCompDamp            = 1.10,
        fSuspensionReboundDamp         = 1.10,
        fSuspensionDampingReboundSlow  = 1.10,
        fSuspensionBiasFront           = 0.50,
        fAntiRollBarForce              = 1.15,
        fAntiRollBarBiasFront          = 0.50,
        fHandBrakeForce                = 1.05,
        fBrakeForce                    = 1.15,
        fBrakeBiasFront                = 0.47,
        fMass                          = 0.88,
        fInitialDragCoeff              = 0.75,
        fDownForceModifier             = 1.20,  -- downforce king
        fClutchChangeRateScaleUpShift  = 1.12,
        fClutchChangeRateScaleDownShift = 1.10,
        fDeformationDamageMult         = 1.00,
    },
    moto = {
        -- Ultra-light, agile, fragile
        fInitialDriveMaxFlatVel        = 0.92,
        fInitialDriveForce             = 1.10,
        fDriveInertia                  = 1.20,
        fTractionCurveMax              = 1.10,
        fTractionCurveMin              = 1.05,
        fTractionCurveLateral          = 0.85,
        fTractionLossMult              = 0.85,
        fLowSpeedTractionLossMult      = 0.95,
        fTractionBiasFront             = 0.55,
        fSteeringLock                  = 0.60,
        fSuspensionForce               = 1.30,
        fSuspensionCompDamp            = 1.25,
        fSuspensionReboundDamp         = 1.20,
        fSuspensionDampingReboundSlow  = 1.25,
        fSuspensionBiasFront           = 0.55,
        fAntiRollBarForce              = 1.50,
        fAntiRollBarBiasFront          = 0.50,
        fRollCentreHeightFront         = 0.80,  -- lower CoG to prevent flipping
        fRollCentreHeightRear          = 0.80,
        fHandBrakeForce                = 1.10,
        fBrakeForce                    = 1.05,
        fBrakeBiasFront                = 0.45,
        fMass                          = 0.35,
        fInitialDragCoeff              = 0.50,
        fDownForceModifier             = 0.80,
        fClutchChangeRateScaleUpShift  = 1.30,  -- very fast shifts
        fClutchChangeRateScaleDownShift = 1.25,
        fDeformationDamageMult         = 2.50,
    },
    utilitario = {
        -- Slow, heavy, high torque
        fInitialDriveMaxFlatVel        = 0.55,
        fInitialDriveForce             = 0.65,
        fDriveInertia                  = 0.60,
        fTractionCurveMax              = 0.80,
        fTractionCurveMin              = 0.75,
        fTractionCurveLateral          = 1.20,
        fTractionLossMult              = 1.20,
        fLowSpeedTractionLossMult      = 1.30,
        fTractionBiasFront             = 0.55,
        fSteeringLock                  = 1.40,
        fSuspensionForce               = 0.75,
        fSuspensionCompDamp            = 0.70,
        fSuspensionReboundDamp         = 0.70,
        fSuspensionDampingReboundSlow  = 0.70,
        fSuspensionBiasFront           = 0.55,
        fAntiRollBarForce              = 0.70,
        fAntiRollBarBiasFront          = 0.50,
        fHandBrakeForce                = 0.60,
        fBrakeForce                    = 0.70,
        fBrakeBiasFront                = 0.55,
        fMass                          = 2.20,
        fInitialDragCoeff              = 1.50,
        fDownForceModifier             = 0.60,
        fClutchChangeRateScaleUpShift  = 0.70,
        fClutchChangeRateScaleDownShift = 0.65,
        fDeformationDamageMult         = 0.50,
    },
    especial = {
        fInitialDriveMaxFlatVel        = 1.00,
        fInitialDriveForce             = 1.00,
        fDriveInertia                  = 1.00,
        fTractionCurveMax              = 1.00,
        fTractionCurveMin              = 1.00,
        fTractionCurveLateral          = 1.00,
        fTractionLossMult              = 1.00,
        fLowSpeedTractionLossMult      = 1.00,
        fTractionBiasFront             = 0.50,
        fSteeringLock                  = 1.00,
        fSuspensionForce               = 1.00,
        fSuspensionCompDamp            = 1.00,
        fSuspensionReboundDamp         = 1.00,
        fSuspensionDampingReboundSlow  = 1.00,
        fSuspensionBiasFront           = 0.50,
        fAntiRollBarForce              = 1.00,
        fAntiRollBarBiasFront          = 0.50,
        fHandBrakeForce                = 1.00,
        fBrakeForce                    = 1.00,
        fBrakeBiasFront                = 0.50,
        fMass                          = 1.00,
        fInitialDragCoeff              = 1.00,
        fDownForceModifier             = 1.00,
        fClutchChangeRateScaleUpShift  = 1.00,
        fClutchChangeRateScaleDownShift = 1.00,
        fDeformationDamageMult         = 1.00,
    }
}

-- ============================================================
-- Sub-Archetype Fine-Tuning (applied AFTER archetype profile)
-- ============================================================

local SUBARCHETYPE_TWEAKS = {
    drifter = {
        fTractionCurveMax       = 0.88,
        fTractionCurveMin       = 0.82,
        fTractionLossMult       = 1.25,
        fTractionCurveLateral   = 1.20,  -- wider lateral curve for slides
        fLowSpeedTractionLossMult = 0.80,
        fDriveInertia           = 1.05,
        fAntiRollBarForce       = 0.85,  -- more body roll helps drifting
    },
    dragster = {
        fInitialDriveForce      = 1.12,
        fDriveInertia           = 0.88,
        fBrakeBiasFront         = 0.52,
        fTractionCurveMax       = 1.05,
        fLowSpeedTractionLossMult = 0.60,  -- lots of wheelspin
        fClutchChangeRateScaleUpShift = 0.80,  -- slower shifts for drag
    },
    late_surger = {
        fInitialDriveMaxFlatVel = 1.08,
        fDriveInertia           = 0.92,
        fBrakeForce             = 1.05,
        fDownForceModifier      = 1.10,
    },
    curve_king = {
        fTractionCurveMax       = 1.10,
        fTractionCurveMin       = 1.08,
        fTractionLossMult       = 0.88,
        fSteeringLock           = 0.90,
        fSuspensionForce        = 1.08,
        fAntiRollBarForce       = 1.15,
        fAntiRollBarBiasFront   = 0.52,
    },
    grip_master = {
        fTractionCurveMax       = 1.15,
        fTractionCurveMin       = 1.12,
        fTractionLossMult       = 0.82,
        fTractionSpringDeltaMax = 0.85,
        fCamberStiffnesss       = 1.20,
        fSuspensionForce        = 1.05,
    },
    street_racer = {
        fInitialDriveForce      = 1.05,
        fTractionCurveMax       = 1.03,
        fBrakeForce             = 1.03,
        fSteeringLock           = 0.95,
        fClutchChangeRateScaleUpShift = 1.05,
    },
    rally_spec = {
        fTractionCurveMax       = 1.05,
        fTractionCurveMin       = 1.03,
        fSuspensionForce        = 1.10,
        fSuspensionDampingReboundSlow = 1.10,
        fSuspensionRaise        = 1.03,  -- slight raise for offroad
    },
    drift_king = {
        fTractionCurveMax       = 0.78,
        fTractionCurveMin       = 0.72,
        fTractionLossMult       = 1.40,
        fTractionCurveLateral   = 1.30,
        fLowSpeedTractionLossMult = 0.70,
        fDriveInertia           = 1.08,
        fSteeringLock           = 1.10,
        fAntiRollBarForce       = 0.75,
    },
    time_attack = {
        fTractionCurveMax       = 1.08,
        fBrakeForce             = 1.10,
        fSuspensionForce        = 1.12,
        fSuspensionDampingReboundSlow = 1.12,
        fInitialDriveMaxFlatVel = 0.97,
        fDownForceModifier      = 1.25,  -- aero dependent
        fAntiRollBarForce       = 1.20,
    },
    sleeper = {
        fInitialDriveForce      = 1.08,
        fDriveInertia           = 1.05,
        fInitialDriveMaxFlatVel = 1.03,
    },
}

-- ============================================================
-- Score-to-Handling Scalar
-- Converts a PI score (0-1000) to a performance multiplier
-- so that higher-class cars feel proportionally stronger.
-- ============================================================

local function ScoreToPerformanceMultiplier(score)
    -- PI 0 -> 0.75x | PI 500 -> 1.0x | PI 750 (Class A) -> 1.125x | PI 1000 (Class S) -> 1.25x
    local normalized = math.max(0, score) / 1000.0
    return 0.75 + (normalized * 0.50)
end

-- ============================================================
-- DNA Blend: 75% new archetype + 25% original (if remapped)
-- ============================================================

local function BlendArchetypeProfiles(originalArchetype, newArchetype, blendRatio)
    blendRatio = blendRatio or 0.75
    local origProfile = ARCHETYPE_PROFILES[originalArchetype] or ARCHETYPE_PROFILES.esportivo
    local newProfile  = ARCHETYPE_PROFILES[newArchetype]  or ARCHETYPE_PROFILES.esportivo
    local blended = {}
    for key, newVal in pairs(newProfile) do
        local origVal = origProfile[key] or newVal
        blended[key] = (newVal * blendRatio) + (origVal * (1.0 - blendRatio))
    end
    return blended
end

-- ============================================================
-- Instability Drawback from illegal parts
-- High instability reduces traction and suspension control.
-- ============================================================

local function ApplyInstability(profile, instabilityScore)
    if not instabilityScore or instabilityScore <= 0 then return profile end
    -- Each instability point reduces traction by 0.4% and suspension by 0.3%
    local tractionPenalty    = 1.0 - (instabilityScore * 0.004)
    local suspensionPenalty  = 1.0 - (instabilityScore * 0.003)
    profile.fTractionCurveMax = (profile.fTractionCurveMax or 1.0) * tractionPenalty
    profile.fTractionCurveMin = (profile.fTractionCurveMin or 1.0) * tractionPenalty
    profile.fTractionLossMult = (profile.fTractionLossMult or 1.0) * (1.0 + instabilityScore * 0.006)
    profile.fSuspensionDampingReboundSlow = (profile.fSuspensionDampingReboundSlow or 1.0) * suspensionPenalty
    return profile
end

-- ============================================================
-- Health Degradation Multiplier
-- Reduces handling values based on part health.
-- ============================================================

local function GetHealthMultiplier(health)
    if health >= 90 then return 1.00
    elseif health >= 75 then return 0.97
    elseif health >= 50 then return 0.93
    elseif health >= 25 then return 0.85
    else return 0.72 end
end

-- ============================================================
-- Build Handling Profile (Main Entry Point)
-- Returns a flat table of handling key/value pairs.
-- ============================================================

function HandlingEngine.BuildHandlingProfile(params)
    --[[
    params = {
        score             = 750,          -- PI score
        archetype         = 'esportivo',  -- current archetype
        subArchetype      = 'drifter',    -- optional sub-archetype
        originalArchetype = nil,          -- if remapped, the original DNA
        remapBlend        = 0.75,         -- DNA blend ratio (default 0.75)
        instability       = 0,            -- total instability from illegal parts
        healthData        = { engine=100, tires=100, suspension=100, brakes=100 }
    }
    --]]

    local archetype         = params.archetype or 'esportivo'
    local originalArchetype = params.originalArchetype
    local subArchetype      = params.subArchetype
    local score             = params.score or 500
    local instability       = params.instability or 0
    local health            = params.healthData or {}

    -- Step 1: Get archetype profile (with optional DNA blend)
    local profile
    if originalArchetype and originalArchetype ~= archetype then
        profile = BlendArchetypeProfiles(originalArchetype, archetype, params.remapBlend or 0.75)
    else
        profile = {}
        local src = ARCHETYPE_PROFILES[archetype] or ARCHETYPE_PROFILES.esportivo
        for k, v in pairs(src) do profile[k] = v end
    end

    -- Step 2: Apply sub-archetype tweaks
    if subArchetype and SUBARCHETYPE_TWEAKS[subArchetype] then
        local tweaks = SUBARCHETYPE_TWEAKS[subArchetype]
        for k, v in pairs(tweaks) do
            if profile[k] then
                profile[k] = profile[k] * v
            end
        end
    end

    -- Step 3: Scale by PI score performance multiplier
    local perfMult = ScoreToPerformanceMultiplier(score)
    profile.fInitialDriveForce     = (profile.fInitialDriveForce or 1.0)    * perfMult
    profile.fInitialDriveMaxFlatVel = (profile.fInitialDriveMaxFlatVel or 1.0) * perfMult
    profile.fBrakeForce            = (profile.fBrakeForce or 1.0)           * perfMult

    -- Step 4: Apply instability from illegal parts
    profile = ApplyInstability(profile, instability)

    -- Step 5: Apply degradation from health
    local engineMult     = GetHealthMultiplier(health.engine or 100)
    local tiresMult      = GetHealthMultiplier(health.tires or 100)
    local suspMult       = GetHealthMultiplier(health.suspension or 100)
    local brakesMult     = GetHealthMultiplier(health.brakes or 100)

    profile.fInitialDriveForce      = (profile.fInitialDriveForce or 1.0)    * engineMult
    profile.fInitialDriveMaxFlatVel = (profile.fInitialDriveMaxFlatVel or 1.0) * engineMult
    profile.fTractionCurveMax       = (profile.fTractionCurveMax or 1.0)     * tiresMult
    profile.fTractionCurveMin       = (profile.fTractionCurveMin or 1.0)     * tiresMult
    profile.fSuspensionForce        = (profile.fSuspensionForce or 1.0)      * suspMult
    profile.fSuspensionDampingReboundSlow = (profile.fSuspensionDampingReboundSlow or 1.0) * suspMult
    profile.fBrakeForce             = (profile.fBrakeForce or 1.0)           * brakesMult

    -- Step 6: Multiply ALL base handling keys by their multipliers
    -- This ensures all 30+ handling keys are always applied
    local finalHandling = {}
    for key, base in pairs(BASE_HANDLING) do
        local multiplier = profile[key] or 1.0
        finalHandling[key] = base * multiplier
    end

    -- Direct-value fields (bias/proportions/percentages — NOT multiplied by base)
    -- These are set as direct values in the archetype profiles, not multipliers
    local directValueFields = {
        'fBrakeBiasFront', 'fBrakeBiasRear', 'fDriveBiasFront',
        'fSuspensionBiasFront', 'fTractionBiasFront',
        'fPercentSubmerged',
    }
    for _, key in ipairs(directValueFields) do
        if profile[key] then
            finalHandling[key] = profile[key]
        end
    end
    -- Derived fields
    finalHandling.fBrakeBiasRear = 1.0 - (finalHandling.fBrakeBiasFront or 0.50)

    return finalHandling
end

-- ============================================================
-- Apply Handling to Vehicle Entity (CLIENT ONLY)
-- Call this inside AddStateBagChangeHandler or on vehicle spawn.
-- ============================================================

function HandlingEngine.ApplyHandlingToVehicle(vehicle, handlingProfile)
    if not DoesEntityExist(vehicle) then return false end
    if not handlingProfile then return false end

    -- Apply each key using the appropriate native
    for key, value in pairs(handlingProfile) do
        if string.sub(key, 1, 1) == 'f' then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', key, value)
        elseif string.sub(key, 1, 1) == 'n' then
            SetVehicleHandlingInt(vehicle, 'CHandlingData', key, math.floor(value))
        end
    end

    return true
end

-- ============================================================
-- Read Current Base Handling from Vehicle (CLIENT ONLY)
-- Used to capture stock values before overriding.
-- ============================================================

function HandlingEngine.GetBaseHandling(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local result = {}
    for key, _ in pairs(BASE_HANDLING) do
        if string.sub(key, 1, 1) == 'f' then
            result[key] = GetVehicleHandlingFloat(vehicle, 'CHandlingData', key)
        elseif string.sub(key, 1, 1) == 'n' then
            result[key] = GetVehicleHandlingInt(vehicle, 'CHandlingData', key)
        end
    end
    return result
end

-- ============================================================
-- Exports
-- ============================================================

function BuildHandlingProfile(params)
    return HandlingEngine.BuildHandlingProfile(params)
end

-- Client-only export (will fail gracefully server-side)
if IsDuplicityVersion and not IsDuplicityVersion() then
    function ApplyHandlingToVehicle(vehicle, profile)
        return HandlingEngine.ApplyHandlingToVehicle(vehicle, profile)
    end
    function GetBaseHandling(vehicle)
        return HandlingEngine.GetBaseHandling(vehicle)
    end
end

