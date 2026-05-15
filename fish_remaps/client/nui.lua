-- ============================================================
-- fish_remaps: Client NUI Handler
-- Routes all NUI callbacks to server events.
-- ============================================================

local isNuiOpen = false

-- ── Open (triggered from server) ─────────────────────────────

RegisterNetEvent('fish_remaps:openNUI')
AddEventHandler('fish_remaps:openNUI', function(data)
    isNuiOpen = true
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
        costs = {
            archetype_change      = 15000,
            subarchetype_change   = 5000,
            adjustment_per_point  = 1000,
        }
    })
end)

-- ── NUI Callbacks ────────────────────────────────────────────

RegisterNUICallback('close', function(data, cb)
    isNuiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('confirmRemap', function(data, cb)
    if not data.plate then cb('error'); return end
    TriggerServerEvent('fish_remaps:confirmRemap', data.plate, data.vehicleNetId, data.data)
    isNuiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ── Export ────────────────────────────────────────────────────

function IsRemapOpen()
    return isNuiOpen
end
