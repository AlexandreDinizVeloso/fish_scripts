-- ============================================================
-- FISH HUB - Client Main
-- ============================================================

local isOpen = false
local playerChips = {}
local cachedData = {
    listings = {},
    messages = {},
    heat = {},
    ranking = {},
    services = {}
}

-- ============================================================
-- Utility Functions
-- ============================================================

local function DebugPrint(msg)
    print('[FISH HUB Client] ' .. tostring(msg))
end

local function SendNUI(action, data)
    SendNUIMessage({
        action = action,
        data = data or {}
    })
end

local function GetPlayerIdentifier()
    return GetPlayerServerId(PlayerId())
end

-- ============================================================
-- Data Building
-- ============================================================

local function BuildMarketplaceData(filter)
    local listings = cachedData.listings or {}
    local result = { legal = {}, illegal = {} }

    for _, listing in ipairs(listings) do
        if listing.status == 'active' then
            if listing.type == 'legal' then
                table.insert(result.legal, listing)
            elseif listing.type == 'illegal' then
                table.insert(result.illegal, listing)
            end
        end
    end

    if filter == 'legal' then
        return { legal = result.legal, illegal = {} }
    elseif filter == 'illegal' then
        return { legal = {}, illegal = result.illegal }
    end

    return result
end

local function BuildChatData()
    local messages = cachedData.messages or {}
    local channels = {}

    for channel, channelConfig in pairs(Config.ChatChannels) do
        local channelMessages = {}
        for _, msg in ipairs(messages) do
            if msg.channel == channel then
                table.insert(channelMessages, msg)
            end
        end

        -- Sort by timestamp
        table.sort(channelMessages, function(a, b)
            return (a.timestamp or 0) < (b.timestamp or 0)
        end)

        -- Limit messages
        local maxMsgs = Config.ChatMaxMessages
        if #channelMessages > maxMsgs then
            local trimmed = {}
            for i = #channelMessages - maxMsgs + 1, #channelMessages do
                table.insert(trimmed, channelMessages[i])
            end
            channelMessages = trimmed
        end

        channels[channel] = {
            label = channelConfig.label,
            icon = channelConfig.icon,
            requiresV2 = channelConfig.requiresV2,
            messages = channelMessages
        }
    end

    return channels
end

local function BuildHeatData()
    local serverId = GetPlayerIdentifier()
    local heat = cachedData.heat or {}
    local personal = {}
    local totalHeat = 0

    for _, entry in ipairs(heat) do
        if entry.playerId == serverId then
            table.insert(personal, entry)
            totalHeat = totalHeat + (entry.heatLevel or 0)
        end
    end

    return {
        vehicles = personal,
        totalHeat = totalHeat,
        ranking = cachedData.ranking or {}
    }
end

local function BuildHubData()
    local hasV1 = false
    local hasV2 = false

    for _, chip in ipairs(playerChips) do
        if chip.type == 'v1' then hasV1 = true end
        if chip.type == 'v2' then hasV2 = true end
    end

    local marketplaceData
    if hasV2 then
        marketplaceData = BuildMarketplaceData()
    elseif hasV1 then
        marketplaceData = BuildMarketplaceData('legal')
    else
        marketplaceData = { legal = {}, illegal = {} }
    end

    local services = {}
    if hasV2 then
        for key, svc in pairs(Config.ServiceTypes) do
            table.insert(services, {
                id = key,
                label = svc.label,
                description = svc.description,
                icon = svc.icon,
                requiresV2 = svc.requiresV2
            })
        end
    else
        for key, svc in pairs(Config.ServiceTypes) do
            if not svc.requiresV2 then
                table.insert(services, {
                    id = key,
                    label = svc.label,
                    description = svc.description,
                    icon = svc.icon,
                    requiresV2 = svc.requiresV2
                })
            end
        end
    end

    local chatData = BuildChatData()
    -- Filter out underground channel if no v2
    if not hasV2 then
        chatData.underground = nil
    end

    return {
        chips = playerChips,
        maxChips = Config.MaxChipsPerTablet,
        chipTypes = Config.ChipTypes,
        hasV1 = hasV1,
        hasV2 = hasV2,
        marketplace = marketplaceData,
        services = services,
        chat = chatData,
        heat = BuildHeatData(),
        serverId = GetPlayerIdentifier()
    }
end

-- ============================================================
-- Hub Control
-- ============================================================

function OpenHub()
    if isOpen then return end
    isOpen = true

    -- Request fresh data from server
    TriggerServerEvent('fish_hub:requestData')

    -- Small delay to allow server response
    Citizen.SetTimeout(200, function()
        local hubData = BuildHubData()
        SendNUI('openHub', hubData)
        SetNuiFocus(true, true)
    end)
end

function CloseHub()
    if not isOpen then return end
    isOpen = false
    SendNUI('closeHub')
    SetNuiFocus(false, false)
end

-- ============================================================
-- Commands
-- ============================================================

RegisterCommand('hub', function()
    if isOpen then
        CloseHub()
    else
        OpenHub()
    end
end, false)

-- Register key mapping
RegisterKeyMapping('hub', 'Open FISH HUB', 'keyboard', 'F7')

-- ============================================================
-- NUI Callbacks (close handled in nui.lua)
-- ============================================================

RegisterNUICallback('close', function(data, cb)
    CloseHub()
    cb('ok')
end)

RegisterNUICallback('sendMessage', function(data, cb)
    if not data.message or data.message == '' then
        cb({ success = false, error = 'Empty message' })
        return
    end
    TriggerServerEvent('fish_hub:sendMessage', data.channel or 'general', data.message)
    cb({ success = true })
end)

RegisterNUICallback('createListing', function(data, cb)
    if not data.name or not data.price then
        cb({ success = false, error = 'Missing name or price' })
        return
    end
    TriggerServerEvent('fish_hub:createListing', data)
    cb({ success = true })
end)

RegisterNUICallback('acceptListing', function(data, cb)
    if not data.listingId then
        cb({ success = false, error = 'Missing listing ID' })
        return
    end
    TriggerServerEvent('fish_hub:acceptListing', data.listingId)
    cb({ success = true })
end)

RegisterNUICallback('requestPart', function(data, cb)
    if not data.serviceType or not data.details then
        cb({ success = false, error = 'Missing service type or details' })
        return
    end
    TriggerServerEvent('fish_hub:requestPart', data.serviceType, data.details)
    cb({ success = true })
end)

RegisterNUICallback('installChip', function(data, cb)
    if not data.chipType then
        cb({ success = false, error = 'Missing chip type' })
        return
    end
    if #playerChips >= Config.MaxChipsPerTablet then
        cb({ success = false, error = 'No free chip slots' })
        return
    end

    -- Check if chip type already installed
    for _, chip in ipairs(playerChips) do
        if chip.type == data.chipType then
            cb({ success = false, error = 'Chip type already installed' })
            return
        end
    end

    TriggerServerEvent('fish_hub:installChip', data.chipType)
    cb({ success = true })
end)

RegisterNUICallback('removeChip', function(data, cb)
    if not data.chipType then
        cb({ success = false, error = 'Missing chip type' })
        return
    end
    TriggerServerEvent('fish_hub:removeChip', data.chipType)
    cb({ success = true })
end)

RegisterNUICallback('openChat', function(data, cb)
    local channel = data.channel or 'general'
    local chatData = BuildChatData()
    cb({ success = true, channel = channel, data = chatData[channel] or {} })
end)

RegisterNUICallback('getHeatRanking', function(data, cb)
    local heatData = BuildHeatData()
    cb({ success = true, data = heatData })
end)

RegisterNUICallback('toggleService', function(data, cb)
    if not data.serviceId then
        cb({ success = false, error = 'Missing service ID' })
        return
    end
    TriggerServerEvent('fish_hub:toggleService', data.serviceId)
    cb({ success = true })
end)

-- ============================================================
-- Server Event Handlers
-- ============================================================

RegisterNetEvent('fish_hub:receiveData')
AddEventHandler('fish_hub:receiveData', function(data)
    if not data then return end

    if data.chips then
        playerChips = data.chips
    end
    if data.listings then
        cachedData.listings = data.listings
    end
    if data.messages then
        cachedData.messages = data.messages
    end
    if data.heat then
        cachedData.heat = data.heat
    end
    if data.ranking then
        cachedData.ranking = data.ranking
    end

    -- If hub is open, refresh NUI
    if isOpen then
        local hubData = BuildHubData()
        SendNUI('updateHub', hubData)
    end
end)

RegisterNetEvent('fish_hub:newMessage')
AddEventHandler('fish_hub:newMessage', function(message)
    if not message then return end
    table.insert(cachedData.messages, message)

    -- Trim to max
    while #cachedData.messages > Config.ChatMaxMessages do
        table.remove(cachedData.messages, 1)
    end

    if isOpen then
        SendNUI('newMessage', message)
    end
end)

RegisterNetEvent('fish_hub:listingUpdate')
AddEventHandler('fish_hub:listingUpdate', function(listings)
    cachedData.listings = listings or cachedData.listings
    if isOpen then
        local hubData = BuildHubData()
        SendNUI('updateMarketplace', hubData.marketplace)
    end
end)

RegisterNetEvent('fish_hub:heatUpdate')
AddEventHandler('fish_hub:heatUpdate', function(heatData)
    cachedData.heat = heatData.heat or cachedData.heat
    cachedData.ranking = heatData.ranking or cachedData.ranking
    if isOpen then
        SendNUI('updateHeat', BuildHeatData())
    end
end)

RegisterNetEvent('fish_hub:chipsUpdated')
AddEventHandler('fish_hub:chipsUpdated', function(chips)
    playerChips = chips or {}
    if isOpen then
        local hubData = BuildHubData()
        SendNUI('updateHub', hubData)
    end
end)

RegisterNetEvent('fish_hub:notification')
AddEventHandler('fish_hub:notification', function(msg, type)
    SendNUI('notification', { message = msg, type = type or 'info' })
end)

-- ============================================================
-- Initialization
-- ============================================================

Citizen.CreateThread(function()
    -- Request initial data on spawn
    Citizen.Wait(2000)
    TriggerServerEvent('fish_hub:requestData')
end)
