-- ============================================================
-- fish_hub: Client Main
-- Opens the hub NUI, handles all NUI callbacks,
-- forwards messages to server, receives server broadcasts.
-- ============================================================

local isNuiOpen = false

-- ============================================================
-- Open Hub
-- ============================================================

function OpenHub()
    if isNuiOpen then return end
    TriggerServerEvent('fish_hub:open')
end

RegisterCommand('hub', function()
    OpenHub()
end, false)

-- ============================================================
-- Server → Client: Hub Opened (data loaded)
-- ============================================================

RegisterNetEvent('fish_hub:opened')
AddEventHandler('fish_hub:opened', function(data)
    SetNuiFocus(true, true)
    isNuiOpen = true
    -- Forward to NUI
    SendNUIMessage({
        action     = 'opened',
        name       = data.name,
        chips      = data.chips,
    })
end)

-- ============================================================
-- Server → Client: Listings
-- ============================================================

RegisterNetEvent('fish_hub:receiveListings')
AddEventHandler('fish_hub:receiveListings', function(listings, isIllegal)
    SendNUIMessage({
        action     = 'receiveListings',
        listings   = listings,
        isIllegal  = isIllegal
    })
end)

RegisterNetEvent('fish_hub:listingCreated')
AddEventHandler('fish_hub:listingCreated', function(listing)
    SendNUIMessage({ action = 'listingCreated', listing = listing })
end)

RegisterNetEvent('fish_hub:listingDeleted')
AddEventHandler('fish_hub:listingDeleted', function(listingId)
    SendNUIMessage({ action = 'listingDeleted', listingId = listingId })
end)

-- ============================================================
-- Server → Client: Chat
-- ============================================================

RegisterNetEvent('fish_hub:receiveMessages')
AddEventHandler('fish_hub:receiveMessages', function(channel, messages)
    SendNUIMessage({ action = 'receiveMessages', channel = channel, messages = messages })
end)

RegisterNetEvent('fish_hub:newMessage')
AddEventHandler('fish_hub:newMessage', function(msgData)
    SendNUIMessage(msgData)
end)

RegisterNetEvent('fish_hub:dmOpened')
AddEventHandler('fish_hub:dmOpened', function(channel, messages, targetIdentifier)
    SendNUIMessage({ action = 'dmOpened', channel = channel, messages = messages, targetIdentifier = targetIdentifier })
end)

-- ============================================================
-- Server → Client: HEAT Ranking
-- ============================================================

RegisterNetEvent('fish_hub:receiveHeatRanking')
AddEventHandler('fish_hub:receiveHeatRanking', function(ranking)
    SendNUIMessage({ action = 'receiveHeatRanking', ranking = ranking })
end)

-- ============================================================
-- Server → Client: Chip
-- ============================================================

RegisterNetEvent('fish_hub:chipInstalled')
AddEventHandler('fish_hub:chipInstalled', function(chipType)
    SendNUIMessage({ action = 'chipInstalled', chipType = chipType })
end)

RegisterNetEvent('fish_hub:notify')
AddEventHandler('fish_hub:notify', function(data)
    if type(data) == 'table' then
        SetNotificationTextEntry('STRING')
        AddTextComponentString(data.message or '')
        DrawNotification(false, false)
    end
end)

-- ============================================================
-- NUI Callbacks → Server
-- ============================================================

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isNuiOpen = false
    TriggerServerEvent('fish_hub:close')
    cb('ok')
end)

RegisterNUICallback('getListings', function(data, cb)
    TriggerServerEvent('fish_hub:getListings', data.isIllegal)
    cb('ok')
end)

RegisterNUICallback('createListing', function(data, cb)
    TriggerServerEvent('fish_hub:createListing', data)
    cb('ok')
end)

RegisterNUICallback('deleteListing', function(data, cb)
    TriggerServerEvent('fish_hub:deleteListing', data.id)
    cb('ok')
end)

RegisterNUICallback('getMessages', function(data, cb)
    TriggerServerEvent('fish_hub:getMessages', data.channel)
    cb('ok')
end)

RegisterNUICallback('sendMessage', function(data, cb)
    TriggerServerEvent('fish_hub:sendMessage', data.channel, data.message)
    cb('ok')
end)

RegisterNUICallback('getHeatRanking', function(data, cb)
    TriggerServerEvent('fish_hub:getHeatRanking')
    cb('ok')
end)

RegisterNUICallback('installChip', function(data, cb)
    TriggerServerEvent('fish_hub:installChip', data.chipType)
    cb('ok')
end)

RegisterNUICallback('getMyData', function(data, cb)
    TriggerServerEvent('fish_hub:getMyData')
    cb('ok')
end)

RegisterNetEvent('fish_hub:receiveMyData')
AddEventHandler('fish_hub:receiveMyData', function(vehicleList)
    SendNUIMessage({ action = 'receiveMyData', vehicles = vehicleList })
end)

RegisterNUICallback('startDM', function(data, cb)
    TriggerServerEvent('fish_hub:startDM', data.targetIdentifier)
    cb('ok')
end)
