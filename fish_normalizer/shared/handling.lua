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
-- These are calibrated so that archetype multipliers produce values
-- matching the hand-tuned examples in Tuning_Examples/
-- Reference targets at PI 500 (mid-range):
--   Esportivo: Pentro-like (MaxFlatVel~162, DriveForce~0.31, TractionMax~1.80)
--   Supercarro: balanced high performer
--   Possante: high accel, low handling
--   Exotico: top speed focused
local BASE_HANDLING = {
    -- Drive
    fInitialDriveMaxFlatVel        = 115.0,  -- Calibrated base flatvel to target exact class speeds (B: ~190, A L3: ~200, A L5 avg: ~208, A L5 top: ~215)
    fInitialDriveForce             = 0.30,
    fDriveInertia                  = 1.00,
    fDriveBiasFront                = 0.35,
    nInitialDriveGears             = 6,
    fClutchChangeRateScaleUpShift  = 2.0,
    fClutchChangeRateScaleDownShift = 2.0,
    -- Traction
    fTractionCurveMax              = 1.70,
    fTractionCurveMin              = 1.50,
    fTractionCurveLateral          = 22.0,
    fTractionLossMult              = 1.0,
    fLowSpeedTractionLossMult      = 1.0,
    fTractionBiasFront             = 0.49,
    fTractionSpringDeltaMax        = 0.10,
    fCamberStiffnesss              = 0.0,
    -- Steering
    fSteeringLock                  = 40.0,
    -- Brakes
    fBrakeForce                    = 0.50,
    fBrakeBiasFront                = 0.65,
    fHandBrakeForce                = 0.65,
    -- Body
    fMass                          = 1500.0,
    fInitialDragCoeff              = 7.0,
    fDownForceModifier             = 1.0,
    fPercentSubmerged              = 85.0,
    -- CRITICAL FIX: Added damage multipliers to prevent instant-explode bug
    -- These are applied by archetype profiles and must have base values
    fCollisionDamageMult           = 1.0,
    fWeaponDamageMult              = 0.4,
    fDeformationDamageMult         = 1.0,
    fEngineDamageMult              = 1.0,
}

-- ============================================================
-- Archetype Handling Personality Profiles
-- Each archetype overrides base values differently.
-- Values are MULTIPLIERS applied to the base.
-- Calibrated to produce hand-tuned example values at ~PI 500 (mid-class)
-- ============================================================

local ARCHETYPE_PROFILES = {
    esportivo = {
        -- High cornering, lightweight, limited top speed
        -- Targets: MaxFlatVel~162, DriveForce~0.31, TractionMax~1.80, SuspForce~3.0 (Pentro)
        fInitialDriveMaxFlatVel        = 1.08,  -- 150*1.08 = 162 ✓ (Pentro)
        fInitialDriveForce             = 1.03,  -- 0.30*1.03 = 0.309 ≈ 0.31 ✓
        fDriveInertia                  = 1.10,
        fTractionCurveMax              = 1.06,  -- 1.70*1.06 = 1.80 ✓
        fTractionCurveMin              = 1.03,  -- 1.50*1.03 = 1.545 ≈ 1.55 ✓
        fTractionCurveLateral          = 1.02,
        fTractionLossMult              = 0.90,
        fLowSpeedTractionLossMult      = 0.85,
        fTractionBiasFront             = 0.49,
        fSteeringLock                  = 1.05,
        fSuspensionForce               = 1.20,  -- 2.5*1.20 = 3.0 ✓
        fSuspensionCompDamp            = 0.80,  -- target 1.2 (Pentro)
        fSuspensionReboundDamp         = 0.63,  -- target 1.0 (Pentro)
        fSuspensionDampingReboundSlow  = 1.15,
        fSuspensionBiasFront           = 0.52,
        fAntiRollBarForce              = 0.40,  -- target 0.2 (Pentro)
        fAntiRollBarBiasFront          = 0.50,
        fRollCentreHeightFront         = 1.50,  -- target 0.30 (Pentro)
        fRollCentreHeightRear          = 1.50,
        fHandBrakeForce                = 1.23,  -- target 0.8 (Pentro)
        fBrakeForce                    = 0.80,  -- target 0.4 (Pentro)
        fBrakeBiasFront                = 0.60,  -- direct value (Pentro)
        fMass                          = 0.90,  -- target 1350 (Pentro)
        fInitialDragCoeff              = 0.96,  -- target 6.7 (Pentro)
        fDownForceModifier             = 1.15,
        fClutchChangeRateScaleUpShift  = 1.00,
        fClutchChangeRateScaleDownShift = 1.00,
        fCollisionDamageMult           = 1.0,
        fDeformationDamageMult         = 1.0,
        fEngineDamageMult              = 1.13,
    },
    possante = {
        -- Brutal acceleration, heavy, poor cornering
        -- Targets: DriveForce~0.45, Mass~2100, TractionMax~1.50
        fInitialDriveMaxFlatVel        = 0.95,
        fInitialDriveForce             = 1.50,  -- 0.30*1.50 = 0.45
        fDriveInertia                  = 0.85,
        fTractionCurveMax              = 0.88,  -- 1.70*0.88 = 1.50
        fTractionCurveMin              = 0.87,
        fTractionCurveLateral          = 1.10,
        fTractionLossMult              = 1.25,
        fLowSpeedTractionLossMult      = 0.70,
        fTractionBiasFront             = 0.42,
        fSteeringLock                  = 1.15,
        fSuspensionForce               = 0.90,
        fSuspensionCompDamp            = 0.85,
        fSuspensionReboundDamp         = 0.80,
        fSuspensionDampingReboundSlow  = 0.85,
        fSuspensionBiasFront           = 0.45,
        fAntiRollBarForce              = 0.80,
        fAntiRollBarBiasFront          = 0.50,
        fHandBrakeForce                = 0.70,
        fBrakeForce                    = 0.85,
        fBrakeBiasFront                = 0.52,
        fMass                          = 1.40,  -- target 2100
        fInitialDragCoeff              = 1.20,
        fDownForceModifier             = 0.80,
        fClutchChangeRateScaleUpShift  = 0.85,
        fClutchChangeRateScaleDownShift = 0.80,
        fCollisionDamageMult           = 0.70,
        fDeformationDamageMult         = 0.70,
        fEngineDamageMult              = 1.13,
    },
    exotico = {
        -- Top speed king, stable acceleration
        -- Targets: MaxFlatVel~170, Low drag~4.5, DriveForce~0.35
        fInitialDriveMaxFlatVel        = 1.13,  -- 150*1.13 = 170
        fInitialDriveForce             = 1.10,  -- 0.30*1.10 = 0.33
        fDriveInertia                  = 0.95,
        fTractionCurveMax              = 1.00,
        fTractionCurveMin              = 0.95,
        fTractionCurveLateral          = 0.95,
        fTractionLossMult              = 1.10,
        fLowSpeedTractionLossMult      = 1.05,
        fTractionBiasFront             = 0.48,
        fSteeringLock                  = 1.00,
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
        fClutchChangeRateScaleUpShift  = 1.15,
        fClutchChangeRateScaleDownShift = 1.10,
        fCollisionDamageMult           = 1.20,
        fDeformationDamageMult         = 1.20,
        fEngineDamageMult              = 1.13,
    },
    supercarro = {
        -- Balanced excellence, high everything
        -- Targets (NeroPS at S-TOP): MaxFlatVel~182, DriveForce~0.50, TractionMax~1.70, Mass~1800
        fInitialDriveMaxFlatVel        = 1.15,  -- 150*1.15 = 172.5 (base), scaled by PI perf for higher
        fInitialDriveForce             = 1.30,  -- 0.30*1.30 = 0.39 (base), scaled by PI perf
        fDriveInertia                  = 1.05,
        fTractionCurveMax              = 1.00,  -- 1.70*1.00 = 1.70 (NeroPS)
        fTractionCurveMin              = 1.00,  -- 1.50*1.00 = 1.50
        fTractionCurveLateral          = 0.95,
        fTractionLossMult              = 0.85,
        fLowSpeedTractionLossMult      = 0.90,
        fTractionBiasFront             = 0.48,
        fSteeringLock                  = 1.05,
        fSuspensionForce               = 1.40,  -- 2.5*1.40 = 3.5 ✓ (NeroPS)
        fSuspensionCompDamp            = 1.00,
        fSuspensionReboundDamp         = 1.25,  -- target 2.0 (NeroPS)
        fSuspensionDampingReboundSlow  = 1.10,
        fSuspensionBiasFront           = 0.50,
        fAntiRollBarForce              = 1.00,  -- target 0.5 (NeroPS)
        fAntiRollBarBiasFront          = 0.50,
        fRollCentreHeightFront         = 1.50,  -- target 0.30 (between NeroPS 0.40 and Pentro 0.30)
        fRollCentreHeightRear          = 1.50,
        fHandBrakeForce                = 1.08,  -- target 0.7 (NeroPS)
        fBrakeForce                    = 1.60,  -- target 0.80 (base prior to PI scaling that pushes to ~1.0)
        fBrakeBiasFront                = 0.60,  -- direct value
        fMass                          = 1.10,  -- target 1650-1800
        fInitialDragCoeff              = 0.93,  -- target 6.5 (NeroPS)
        fDownForceModifier             = 1.20,
        fClutchChangeRateScaleUpShift  = 1.50,  -- target 3.0 (NeroPS)
        fClutchChangeRateScaleDownShift = 1.50,  -- target 3.0 (NeroPS)
        fCollisionDamageMult           = 0.84,  -- target 0.8367 (NeroPS)
        fDeformationDamageMult         = 0.70,  -- target 0.70 (NeroPS)
        fEngineDamageMult              = 1.13,
    },
    moto = {
        -- Ultra-light, agile, fragile
        fInitialDriveMaxFlatVel        = 0.95,
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
        fRollCentreHeightFront         = 0.80,
        fRollCentreHeightRear          = 0.80,
        fHandBrakeForce                = 1.10,
        fBrakeForce                    = 1.05,
        fBrakeBiasFront                = 0.45,
        fMass                          = 0.35,
        fInitialDragCoeff              = 0.50,
        fDownForceModifier             = 0.80,
        fClutchChangeRateScaleUpShift  = 1.30,
        fClutchChangeRateScaleDownShift = 1.25,
        fCollisionDamageMult           = 1.00,
        fDeformationDamageMult         = 2.50,
        fEngineDamageMult              = 1.00,
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
        fCollisionDamageMult           = 0.50,
        fDeformationDamageMult         = 0.50,
        fEngineDamageMult              = 1.00,
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
        fCollisionDamageMult           = 1.00,
        fDeformationDamageMult         = 1.00,
        fEngineDamageMult              = 1.00,
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
        fTractionCurveLateral   = 1.20,
        fLowSpeedTractionLossMult = 0.80,
        fDriveInertia           = 1.05,
        fAntiRollBarForce       = 0.85,
    },
    dragster = {
        fInitialDriveForce      = 1.12,
        fDriveInertia           = 0.88,
        fBrakeBiasFront         = 0.52,
        fTractionCurveMax       = 1.05,
        fLowSpeedTractionLossMult = 0.60,
        fClutchChangeRateScaleUpShift = 0.80,
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
        fDownForceModifier      = 1.25,
        fAntiRollBarForce       = 1.20,
    },
    sleeper = {
        fInitialDriveForce      = 1.08,
        fDriveInertia           = 1.05,
        fInitialDriveMaxFlatVel = 1.03,
    },
}

-- ============================================================
-- Archetype-specific reference brackets for PI calculation
-- These map handling values to 0-100 normalised scores per archetype.
-- Weights are in the PI formula, not here.
-- maxFlatVel_ref brackets use effective speed: flatVel / sqrt(drag)
-- ============================================================

local ARCHETYPE_REFERENCE = {
    esportivo = {
        -- Esportivo: cornering-focused, moderate top speed
        maxFlatVel_ref       = {min = 15, max = 22},   -- flatVel/sqrt(drag): ~162/sqrt(6.7)≈62.6 normalised range
        driveForce_ref       = {min = 0.00015, max = 0.00035},  -- (force/mass)*gears
        tractionCurveMax_ref = {min = 1.40, max = 2.50},
        brakeForce_ref       = {min = 0.30, max = 0.70},
        mass_ref             = {min = 2000, max = 1200, inverted = true},
    },
    possante = {
        -- Possante: acceleration-focused, heavy
        maxFlatVel_ref       = {min = 14, max = 20},
        driveForce_ref       = {min = 0.00020, max = 0.00045},
        tractionCurveMax_ref = {min = 1.30, max = 2.00},
        brakeForce_ref       = {min = 0.30, max = 0.60},
        mass_ref             = {min = 1800, max = 1000, inverted = true},
    },
    exotico = {
        -- Exotico: top speed king, low drag
        maxFlatVel_ref       = {min = 18, max = 28},
        driveForce_ref       = {min = 0.00018, max = 0.00040},
        tractionCurveMax_ref = {min = 1.40, max = 2.30},
        brakeForce_ref       = {min = 0.30, max = 0.65},
        mass_ref             = {min = 2000, max = 1200, inverted = true},
    },
    supercarro = {
        -- Supercarro: balanced, high all-round
        maxFlatVel_ref       = {min = 17, max = 26},
        driveForce_ref       = {min = 0.00020, max = 0.00042},
        tractionCurveMax_ref = {min = 1.40, max = 2.50},
        brakeForce_ref       = {min = 0.40, max = 1.00},
        mass_ref             = {min = 2000, max = 1200, inverted = true},
    },
    moto = {
        maxFlatVel_ref       = {min = 16, max = 24},
        driveForce_ref       = {min = 0.00050, max = 0.00120},
        tractionCurveMax_ref = {min = 1.50, max = 2.60},
        brakeForce_ref       = {min = 0.30, max = 0.60},
        mass_ref             = {min = 600, max = 300, inverted = true},
    },
    utilitario = {
        maxFlatVel_ref       = {min = 8, max = 16},
        driveForce_ref       = {min = 0.00010, max = 0.00025},
        tractionCurveMax_ref = {min = 1.20, max = 2.00},
        brakeForce_ref       = {min = 0.25, max = 0.50},
        mass_ref             = {min = 2500, max = 1500, inverted = true},
    },
    especial = {
        maxFlatVel_ref       = {min = 14, max = 22},
        driveForce_ref       = {min = 0.00015, max = 0.00035},
        tractionCurveMax_ref = {min = 1.30, max = 2.10},
        brakeForce_ref       = {min = 0.30, max = 0.60},
        mass_ref             = {min = 2000, max = 1000, inverted = true},
    },
}

-- ============================================================
-- Calculate PI Score from Final Handling Profile
-- Cascade: M_final = (M_base + ΔT) × λ_remap
--   M_base  = Normalizer archetype-derived handling values
--   ΔT      = Tunes additive deltas (parts bonuses)
--   λ_remap = Remap multiplicative coefficient (ECU/archetype)
--
-- PI = (α × V_score) + (β × A_score) + (γ × H_score) + (δ × B_score)
-- Weights: α=0.25, β=0.35, γ=0.30, δ=0.10
-- ============================================================

function CalculatePIFromProfile(handlingProfile, archetype, tunePI)
    local ref = ARCHETYPE_REFERENCE[archetype] or ARCHETYPE_REFERENCE.esportivo

    local function normalize(value, refBracket)
        local min = refBracket.min
        local max = refBracket.max
        local inverted = refBracket.inverted or false

        if inverted then
            local clamped = math.max(math.min(value, max), min)
            return ((max - clamped) / (max - min)) * 100
        else
            local clamped = math.max(math.min(value, max), min)
            return ((clamped - min) / (max - min)) * 100
        end
    end

    -- ── V_score: Top Speed (drag-corrected) ──
    -- V_score is not raw flatVel — it accounts for the drag equilibrium.
    -- At terminal velocity: F_motor = F_drag × v²
    -- A vehicle with high flatVel but extreme drag is slower in practice.
    -- Effective speed proxy = flatVel / sqrt(dragCoeff) normalised to archetype bracket.
    local vRaw = handlingProfile.fInitialDriveMaxFlatVel or 115.0
    local drag = handlingProfile.fInitialDragCoeff or 7.0
    local vEffective = vRaw / math.sqrt(math.max(drag, 1.0))
    local vScore = normalize(vEffective, ref.maxFlatVel_ref)

    -- ── A_score: Acceleration (force-to-mass ratio × gear count) ──
    -- F/M ratio determines how quickly the vehicle reaches V_max.
    -- More gears = smoother power delivery = faster average acceleration.
    local driveForce = handlingProfile.fInitialDriveForce or 0.30
    local mass       = handlingProfile.fMass or 1500.0
    local gears      = handlingProfile.nInitialDriveGears or 6
    local forceToMass = (driveForce / math.max(mass, 1.0)) * gears
    local aScore = normalize(forceToMass, ref.driveForce_ref)

    -- ── H_score: Handling/Grip ──
    -- Average of traction curve max and lateral, weighted by bias distribution.
    local tMax      = handlingProfile.fTractionCurveMax or 1.70
    local tMin      = handlingProfile.fTractionCurveMin or 1.50
    local tLateral  = handlingProfile.fTractionCurveLateral or 22.0
    local hRaw = (tMax * 0.50) + (tMin * 0.30) + (tLateral * 0.20)
    local hScore = normalize(hRaw, ref.tractionCurveMax_ref)

    -- ── B_score: Braking ──
    local bRaw = handlingProfile.fBrakeForce or 0.50
    local bScore = normalize(bRaw, ref.brakeForce_ref)

    -- ── PI composite (weights from Config.Weights) ──
    local alpha = 0.25  -- top speed
    local beta  = 0.35  -- acceleration
    local gamma = 0.30  -- handling
    local delta = 0.10  -- braking

    local basePI = (alpha * vScore) + (beta * aScore) + (gamma * hScore) + (delta * bScore)

    -- ── Cascade: additive tune delta ──
    -- ΔT is added AFTER base PI, before remap multiplier.
    -- tunePI comes from CalculateTunePI (part bonuses as PI offsets).
    basePI = basePI + (tunePI or 0)

    -- Clamp to 0-1000
    return math.max(0, math.min(1000, math.floor(basePI)))
end

-- ============================================================
-- Score-to-Handling Scalar
-- Converts a PI score (0-1000) to a performance multiplier
-- so that higher-class cars feel proportionally stronger.
-- ============================================================

local function ScoreToPerformanceMultiplier(score)
    -- PI 0 -> 0.85x | PI 500 -> 1.0x | PI 1000 -> 1.15x
    local normalized = math.max(0, score) / 1000.0
    return 0.85 + (normalized * 0.30)
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
    local tractionPenalty    = 1.0 - (instabilityScore * 0.0005) -- Maps 80 instability to a subtle, realistic 4% grip penalty
    local suspensionPenalty  = 1.0 - (instabilityScore * 0.0004) -- Maps 80 instability to a subtle 3.2% damping penalty
    profile.fTractionCurveMax = (profile.fTractionCurveMax or 1.0) * tractionPenalty
    profile.fTractionCurveMin = (profile.fTractionCurveMin or 1.0) * tractionPenalty
    profile.fTractionLossMult = (profile.fTractionLossMult or 1.0) * (1.0 + instabilityScore * 0.0008)
    profile.fSuspensionDampingReboundSlow = (profile.fSuspensionDampingReboundSlow or 1.0) * suspensionPenalty
    return profile
end

-- ============================================================
-- Health Degradation Multiplier
-- ============================================================

local function GetHealthMultiplier(health)
    if health >= 90 then return 1.00
    elseif health >= 75 then return 0.97
    elseif health >= 50 then return 0.93
    elseif health >= 25 then return 0.85
    else return 0.72 end
end

-- ============================================================
-- Get Archetype Classification from Vehicle Class
-- ============================================================

function GetArchetypeForClass(classId)
    local map = {
        [0]  = 'utilitario',  -- Compacts
        [1]  = 'utilitario',  -- Sedans
        [2]  = 'utilitario',  -- SUVs
        [3]  = 'esportivo',   -- Coupes
        [4]  = 'possante',    -- Muscle   [FIXED from utilitario to possante]
        [5]  = 'esportivo',   -- Sports Classics
        [6]  = 'esportivo',   -- Sports
        [7]  = 'supercarro',  -- Super
        [8]  = 'moto',        -- Motorcycles
        [9]  = 'utilitario',  -- Off-road
        [10] = 'utilitario',  -- Industrial
        [11] = 'utilitario',  -- Utility
        [12] = 'utilitario',  -- Vans
        [13] = 'especial',    -- Cycles
        [14] = 'especial',    -- Boats
        [15] = 'especial',    -- Helicopters
        [16] = 'especial',    -- Planes
        [17] = 'utilitario',  -- Service
        [18] = 'especial',    -- Emergency
        [19] = 'especial',    -- Military
        [20] = 'utilitario',  -- Commercial
        [21] = 'especial'     -- Trains
    }
    return map[classId] or 'esportivo'
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

    -- Step 3: Scale by PI score performance multiplier (acceleration & braking only, top speed capped by archetype and parts)
    local perfMult = ScoreToPerformanceMultiplier(score)
    profile.fInitialDriveForce     = (profile.fInitialDriveForce or 1.0)    * perfMult
    profile.fInitialDriveMaxFlatVel = (profile.fInitialDriveMaxFlatVel or 1.0)
    profile.fBrakeForce            = (profile.fBrakeForce or 1.0)           * perfMult

    -- Step 4: Apply instability from illegal parts
    profile = ApplyInstability(profile, instability)

    -- Step 5: Apply degradation from health
    local engineMult     = GetHealthMultiplier(health.engine or 100)
    local tiresMult      = GetHealthMultiplier(health.tires or 100)
    local brakesMult     = GetHealthMultiplier(health.brakes or 100)

    profile.fInitialDriveForce      = (profile.fInitialDriveForce or 1.0)    * engineMult
    profile.fInitialDriveMaxFlatVel = (profile.fInitialDriveMaxFlatVel or 1.0) * engineMult
    profile.fTractionCurveMax       = (profile.fTractionCurveMax or 1.0)     * tiresMult
    profile.fTractionCurveMin       = (profile.fTractionCurveMin or 1.0)     * tiresMult
    profile.fBrakeForce             = (profile.fBrakeForce or 1.0)           * brakesMult

    -- Step 6: Multiply ALL base handling keys by their multipliers
    local finalHandling = {}
    for key, base in pairs(BASE_HANDLING) do
        local multiplier = profile[key] or 1.0
        finalHandling[key] = base * multiplier
    end

    -- Direct-value fields (bias/proportions/percentages — NOT multiplied by base)
    local directValueFields = {
        'fBrakeBiasFront', 'fBrakeBiasRear', 'fDriveBiasFront',
        'fTractionBiasFront',
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
-- Safe Runtime Modifiable Handling Fields Whitelist
-- Prevents read-only or unsupported fields from being modified,
-- which causes GTA V to gltich their values to 0.0 (e.g. fMass, fSteeringLock).
-- ============================================================

local WRITABLE_HANDLING_FIELDS = {
    fInitialDriveMaxFlatVel       = true,
    fInitialDriveForce            = true,
    fDriveInertia                 = true,
    fBrakeForce                   = true,
    fTractionCurveMax             = true,
    fTractionCurveMin             = true,
    fTractionCurveLateral         = true,
    fTractionLossMult             = true,
    fLowSpeedTractionLossMult     = true,
    fTractionSpringDeltaMax       = true,
    fCamberStiffnesss             = true,
    fHandBrakeForce               = true,
    fInitialDragCoeff             = true,
    fDownForceModifier            = true,
}

-- ============================================================
-- Apply Handling to Vehicle Entity (CLIENT ONLY)
-- ============================================================

function HandlingEngine.ApplyHandlingToVehicle(vehicle, handlingProfile)
    if not DoesEntityExist(vehicle) then return false end
    if not handlingProfile then return false end

    for key, value in pairs(handlingProfile) do
        if WRITABLE_HANDLING_FIELDS[key] then
            if string.sub(key, 1, 1) == 'f' then
                SetVehicleHandlingFloat(vehicle, 'CHandlingData', key, value)
            elseif string.sub(key, 1, 1) == 'n' then
                SetVehicleHandlingInt(vehicle, 'CHandlingData', key, math.floor(value))
            end
        end
    end

    return true
end

-- ============================================================
-- Read Current Base Handling from Vehicle (CLIENT ONLY)
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