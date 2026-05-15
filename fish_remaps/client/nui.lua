-- ============================================================
-- fish_remaps: Client NUI Handler (server-triggered open only)
-- NOTE: close and confirmRemap callbacks are in client/main.lua
--       to avoid duplicate registration conflicts.
-- ============================================================

-- ── Open (triggered from server via mechanic interaction) ────

RegisterNetEvent('fish_remaps:openNUI')
AddEventHandler('fish_remaps:openNUI', function(data)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action            = 'openRemap',
        plate             = data.plate,
        vehicleNetId      = data.vehicleNetId,
        originalArchetype = data.originalArchetype,
        currentArchetype  = data.currentArchetype,
        subArchetype      = data.subArchetype,
        stage             = data.stage,
        existingData      = data.existingData,
        adjustments       = data.adjustments,
        costs = {
            archetype_change      = 15000,
            subarchetype_change   = 5000,
            adjustment_per_point  = 1000,
        }
    })
end)

function IsRemapOpen()
    return isNuiOpen
end
