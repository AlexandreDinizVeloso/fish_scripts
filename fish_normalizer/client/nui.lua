-- ============================================================
-- fish_normalizer: Client NUI Handler
-- All NUI callbacks route through here to the server.
-- ============================================================

local isNuiOpen = false

-- ── Open / Close ─────────────────────────────────────────────

RegisterNetEvent('fish_normalizer:openNUI')
AddEventHandler('fish_normalizer:openNUI', function(data)
    if not isAdmin then return end
    isNuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action      = 'openNormalizer',
        plate       = data.plate,
        vehicleNetId = data.vehicleNetId,
        vehicleName = data.vehicleName or '—',
        existing    = data.existing or {},
        remapData   = data.remapData,
        tuneData    = data.tuneData,
    })
end)

RegisterNUICallback('close', function(data, cb)
    isNuiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ── Save (admin confirms normalization) ──────────────────────

RegisterNUICallback('saveData', function(data, cb)
    if not data.plate then cb('error'); return end
    TriggerServerEvent('fish_normalizer:saveData', data.plate, data, data.vehicleNetId)
    isNuiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ── Export ────────────────────────────────────────────────────

function IsNormalizerOpen()
    return isNuiOpen
end
