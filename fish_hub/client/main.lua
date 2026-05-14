-- ============================================================
-- FISH HUB - Client Main
-- ============================================================

local isOpen = false
local playerChips = {}
local cachedData = {
    listings  = {},
    messages  = {},
    heat      = {},
    ranking   = {},
    profile   = { username = '', profilePic = '' },
    channels  = {}
}

-- ============================================================
-- Utility Functions
-- ============================================================

local function DebugPrint(msg)
    print('[FISH HUB Client] ' .. tostring(msg))
end

local function SendNUI(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function GetPlayerIdentifier()
    return GetPlayerServerId(PlayerId())
end

local function HasChipType(chipType)
    for _, chip in ipairs(playerChips) do
        if chip.type == chipType then return true end
    end
    return false
end

local function HasV1()
    return HasChipType('v1') or HasChipType('v2')
end

local function HasV2()
    return HasChipType('v2')
end

-- ============================================================
-- Data Building
-- ============================================================

local function BuildChatData()
    local messages = cachedData.messages or {}
    local channels = cachedData.channels or {}
    local result = {}

    for channelId, ch in pairs(channels) do
        local channelMessages = {}
        for _, msg in ipairs(messages) do
            if msg.channel == channelId then
                table.insert(channelMessages, msg)
            end
        end

        table.sort(channelMessages, function(a, b)
            return (a.timestamp or 0) < (b.timestamp or 0)
        end)

        -- Trim to max
        local maxMsgs = Config.ChatMaxMessages
        if #channelMessages > maxMsgs then
            local trimmed = {}
            for i = #channelMessages - maxMsgs + 1, #channelMessages do
                table.insert(trimmed, channelMessages[i])
            end
            channelMessages = trimmed
        end

        result[channelId] = {
            name    = ch.name,
            type    = ch.type,
            icon    = ch.icon,
            members = ch.members or {},
            messages = channelMessages
        }
    end

    return result
end

local function BuildHeatData()
    local serverId = GetPlayerIdentifier()
    local heat = cachedData.heat or {}
    local personal = {}
    local totalHeat = 0

    for _, entry in ipairs(heat) do
        if tostring(entry.playerId) == tostring(serverId) then
            table.insert(personal, entry)
            totalHeat = totalHeat + (entry.heatLevel or 0)
        end
    end

    return {
        vehicles  = personal,
        totalHeat = totalHeat,
        ranking   = cachedData.ranking or {}
    }
end

local function BuildHubData()
    local hasV1 = HasV1()
    local hasV2 = HasV2()

    -- Services
    local services = {}
    for key, svc in pairs(Config.ServiceTypes) do
        table.insert(services, {
            id          = key,
            label       = svc.label,
            description = svc.description,
            icon        = svc.icon,
            requiresV1  = svc.requiresV1
        })
    end

    return {
        chips     = playerChips,
        maxChips  = Config.MaxChipsPerTablet,
        chipTypes = Config.ChipTypes,
        hasV1     = hasV1,
        hasV2     = hasV2,
        serverId  = GetPlayerIdentifier(),
        profile   = cachedData.profile or { username = '', profilePic = '' },
        listings  = cachedData.listings or {},
        services  = services,
        channels  = BuildChatData(),
        heat      = BuildHeatData()
    }
end

-- ============================================================
-- Hub Control
-- ============================================================

function OpenHub()
    if isOpen then return end
    isOpen = true

    TriggerServerEvent('fish_hub:requestData')

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
    if isOpen then CloseHub() else OpenHub() end
end, false)

-- ============================================================
-- NUI Callbacks
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

RegisterNUICallback('contactSeller', function(data, cb)
    if not data.listingId or not data.sellerId then
        cb({ success = false, error = 'Missing data' })
        return
    end
    if not HasV1() then
        cb({ success = false, error = 'V1 chip required' })
        return
    end
    TriggerServerEvent('fish_hub:contactSeller', data.listingId, data.sellerId)
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

RegisterNUICallback('createChannel', function(data, cb)
    if not data.name or data.name == '' then
        cb({ success = false, error = 'Missing channel name' })
        return
    end
    TriggerServerEvent('fish_hub:createChannel', data.name)
    cb({ success = true })
end)

RegisterNUICallback('inviteToChannel', function(data, cb)
    if not data.channelId or not data.targetId then
        cb({ success = false, error = 'Missing channel or target' })
        return
    end
    TriggerServerEvent('fish_hub:inviteToChannel', data.channelId, data.targetId)
    cb({ success = true })
end)

RegisterNUICallback('uploadCarPhoto', function(data, cb)
    if not data.vehicleModel then
        cb({ success = false, error = 'Missing vehicle model' })
        return
    end
    TriggerServerEvent('fish_hub:uploadCarPhoto', data.vehicleModel, data.photoUrl or '')
    cb({ success = true })
end)

RegisterNUICallback('updateProfile', function(data, cb)
    if not data then
        cb({ success = false, error = 'Missing data' })
        return
    end
    TriggerServerEvent('fish_hub:updateProfile', data)
    cb({ success = true })
end)



-- ============================================================
-- Server Event Handlers
-- ============================================================

RegisterNetEvent('fish_hub:receiveData')
AddEventHandler('fish_hub:receiveData', function(data)
    if not data then return end

    if data.chips    then playerChips = data.chips end
    if data.listings then cachedData.listings = data.listings end
    if data.messages then cachedData.messages = data.messages end
    if data.heat     then cachedData.heat = data.heat end
    if data.ranking  then cachedData.ranking = data.ranking end
    if data.profile  then cachedData.profile = data.profile end
    if data.channels then cachedData.channels = data.channels end

    if isOpen then
        SendNUI('updateHub', BuildHubData())
    end
end)

RegisterNetEvent('fish_hub:newMessage')
AddEventHandler('fish_hub:newMessage', function(message)
    if not message then return end
    table.insert(cachedData.messages, message)
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
        SendNUI('updateMarketplace', cachedData.listings)
    end
end)

RegisterNetEvent('fish_hub:heatUpdate')
AddEventHandler('fish_hub:heatUpdate', function(heatData)
    if heatData.heat    then cachedData.heat = heatData.heat end
    if heatData.ranking then cachedData.ranking = heatData.ranking end
    if isOpen then
        SendNUI('updateHeat', BuildHeatData())
    end
end)

RegisterNetEvent('fish_hub:chipsUpdated')
AddEventHandler('fish_hub:chipsUpdated', function(chips)
    playerChips = chips or {}
    if isOpen then
        SendNUI('updateHub', BuildHubData())
    end
end)

RegisterNetEvent('fish_hub:profileUpdated')
AddEventHandler('fish_hub:profileUpdated', function(profile)
    cachedData.profile = profile or cachedData.profile
    if isOpen then
        SendNUI('updateHub', BuildHubData())
    end
end)

RegisterNetEvent('fish_hub:channelsUpdated')
AddEventHandler('fish_hub:channelsUpdated', function(channels)
    cachedData.channels = channels or cachedData.channels
    if isOpen then
        SendNUI('updateHub', BuildHubData())
    end
end)

RegisterNetEvent('fish_hub:dmChannelCreated')
AddEventHandler('fish_hub:dmChannelCreated', function(channelId)
    -- Refresh data then open the DM channel in chat
    TriggerServerEvent('fish_hub:requestData')
    Citizen.SetTimeout(300, function()
        if isOpen then
            SendNUI('openChatChannel', { channelId = channelId })
        end
    end)
end)

RegisterNetEvent('fish_hub:notification')
AddEventHandler('fish_hub:notification', function(msg, type)
    SendNUI('notification', { message = msg, type = type or 'info' })
end)

-- ============================================================
-- Initialization
-- ============================================================

Citizen.CreateThread(function()
    Citizen.Wait(2000)
    TriggerServerEvent('fish_hub:requestData')
end)
