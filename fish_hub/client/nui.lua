-- ============================================================
-- FISH HUB - NUI Callbacks
-- ============================================================
-- Additional NUI callbacks that complement client/main.lua

RegisterNUICallback('refreshData', function(data, cb)
    TriggerServerEvent('fish_hub:requestData')
    cb({ success = true })
end)

RegisterNUICallback('getChipInfo', function(data, cb)
    cb({
        success = true,
        chipTypes = Config.ChipTypes,
        maxChips = Config.MaxChipsPerTablet
    })
end)

RegisterNUICallback('getServiceInfo', function(data, cb)
    cb({
        success = true,
        services = Config.ServiceTypes
    })
end)

RegisterNUICallback('getChannelInfo', function(data, cb)
    cb({
        success = true,
        channels = Config.ChatChannels
    })
end)

RegisterNUICallback('searchListings', function(data, cb)
    local query = (data.query or ''):lower()
    local filter = data.filter or 'all'

    TriggerServerEvent('fish_hub:searchListings', query, filter)
    cb({ success = true })
end)

RegisterNUICallback('reportListing', function(data, cb)
    if not data.listingId then
        cb({ success = false, error = 'Missing listing ID' })
        return
    end
    TriggerServerEvent('fish_hub:reportListing', data.listingId)
    cb({ success = true })
end)

RegisterNUICallback('dmPlayer', function(data, cb)
    if not data.targetId or not data.message then
        cb({ success = false, error = 'Missing target or message' })
        return
    end
    TriggerServerEvent('fish_hub:dmPlayer', data.targetId, data.message)
    cb({ success = true })
end)
