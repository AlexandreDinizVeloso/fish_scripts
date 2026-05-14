-- ============================================================
-- FISH HUB - Server Data Layer
-- ============================================================
-- Handles persistent storage via JSON files

DataStore = {}

local files = {
    listings  = 'server/listings.json',
    messages  = 'server/messages.json',
    heat      = 'server/heat.json',
    chips     = 'server/chips.json',
    profiles  = 'server/profiles.json',
    channels  = 'server/channels.json'
}

-- In-memory caches
DataStore.listings  = {}
DataStore.messages  = {}
DataStore.heat      = {}
DataStore.chips     = {}
DataStore.profiles  = {}
DataStore.channels  = {}

-- ============================================================
-- File I/O Helpers
-- ============================================================

local function ReadJSON(filepath)
    local content = LoadResourceFile(GetCurrentResourceName(), filepath)
    if content and content ~= '' then
        local success, result = pcall(json.decode, content)
        if success then return result end
    end
    return nil
end

local function WriteJSON(filepath, data)
    local content = json.encode(data, { indent = true })
    SaveResourceFile(GetCurrentResourceName(), filepath, content, -1)
end

-- ============================================================
-- Load / Save
-- ============================================================

function DataStore.LoadAll()
    DataStore.listings  = ReadJSON(files.listings)  or {}
    DataStore.messages  = ReadJSON(files.messages)   or {}
    DataStore.heat      = ReadJSON(files.heat)       or {}
    DataStore.chips     = ReadJSON(files.chips)      or {}
    DataStore.profiles  = ReadJSON(files.profiles)   or {}
    DataStore.channels  = ReadJSON(files.channels)   or {}

    -- Ensure default General channel exists
    DataStore.EnsureDefaultChannel()

    print('[FISH HUB Data] Loaded: ' .. #DataStore.listings .. ' listings, ' ..
          #DataStore.messages .. ' messages, ' ..
          #DataStore.heat .. ' heat entries, ' ..
          'chips for ' .. CountTable(DataStore.chips) .. ' players, ' ..
          'profiles for ' .. CountTable(DataStore.profiles) .. ' players, ' ..
          CountTable(DataStore.channels) .. ' channels')
end

function DataStore.SaveListings()  WriteJSON(files.listings, DataStore.listings)  end
function DataStore.SaveMessages()  WriteJSON(files.messages, DataStore.messages)  end
function DataStore.SaveHeat()      WriteJSON(files.heat, DataStore.heat)          end
function DataStore.SaveChips()     WriteJSON(files.chips, DataStore.chips)        end
function DataStore.SaveProfiles()  WriteJSON(files.profiles, DataStore.profiles)  end
function DataStore.SaveChannels()  WriteJSON(files.channels, DataStore.channels)  end

function DataStore.SaveAll()
    DataStore.SaveListings()
    DataStore.SaveMessages()
    DataStore.SaveHeat()
    DataStore.SaveChips()
    DataStore.SaveProfiles()
    DataStore.SaveChannels()
end

-- ============================================================
-- Profile Operations
-- ============================================================

function DataStore.GetProfile(playerId)
    local id = tostring(playerId)
    return DataStore.profiles[id] or { username = '', profilePic = '' }
end

function DataStore.UpdateProfile(playerId, data)
    local id = tostring(playerId)
    DataStore.profiles[id] = {
        username  = data.username  or '',
        profilePic = data.profilePic or ''
    }
    DataStore.SaveProfiles()
    return true
end

-- ============================================================
-- Chip Operations
-- ============================================================

function DataStore.GetPlayerChips(playerId)
    local id = tostring(playerId)
    return DataStore.chips[id] or {}
end

function DataStore.InstallChip(playerId, chipType)
    local id = tostring(playerId)
    if not DataStore.chips[id] then DataStore.chips[id] = {} end

    if #DataStore.chips[id] >= Config.MaxChipsPerTablet then
        return false, 'No free chip slots'
    end

    for _, chip in ipairs(DataStore.chips[id]) do
        if chip.type == chipType then
            return false, 'Chip already installed'
        end
    end

    table.insert(DataStore.chips[id], { type = chipType, installedAt = os.time() })
    DataStore.SaveChips()
    return true, 'Chip installed'
end

function DataStore.RemoveChip(playerId, chipType)
    local id = tostring(playerId)
    if not DataStore.chips[id] then return false, 'No chips installed' end

    for i, chip in ipairs(DataStore.chips[id]) do
        if chip.type == chipType then
            table.remove(DataStore.chips[id], i)
            DataStore.SaveChips()
            return true, 'Chip removed'
        end
    end
    return false, 'Chip not found'
end

-- ============================================================
-- Listing Operations
-- ============================================================

function DataStore.GetListings()
    return DataStore.listings
end

function DataStore.CreateListing(playerId, data)
    if #DataStore.listings >= Config.MarketplaceMaxListings then
        return false, 'Marketplace is full'
    end

    local listing = {
        id          = 'lst_' .. os.time() .. '_' .. math.random(1000, 9999),
        sellerId    = playerId,
        sellerName  = data.sellerName or 'Unknown',
        name        = data.name,
        description = data.description or '',
        price       = tonumber(data.price) or 0,
        tag         = data.tag or 'selling',  -- buying / selling
        type        = data.listingType or 'legal', -- legal / illegal
        status      = 'active',
        createdAt   = os.time(),
        expiresAt   = os.time() + Config.ListingDuration
    }

    table.insert(DataStore.listings, listing)
    DataStore.SaveListings()
    return true, listing
end

function DataStore.AcceptListing(playerId, listingId)
    for i, listing in ipairs(DataStore.listings) do
        if listing.id == listingId and listing.status == 'active' then
            DataStore.listings[i].status = 'sold'
            DataStore.listings[i].buyerId = playerId
            DataStore.listings[i].soldAt = os.time()
            DataStore.SaveListings()
            return true, listing
        end
    end
    return false, 'Listing not found or already sold'
end

function DataStore.CleanExpiredListings()
    local now = os.time()
    local changed = false
    for i = #DataStore.listings, 1, -1 do
        if DataStore.listings[i].expiresAt and DataStore.listings[i].expiresAt < now then
            if DataStore.listings[i].status == 'active' then
                DataStore.listings[i].status = 'expired'
                changed = true
            end
        end
    end
    if changed then DataStore.SaveListings() end
end

-- ============================================================
-- Channel Operations
-- ============================================================

function DataStore.EnsureDefaultChannel()
    if not DataStore.channels['general'] then
        DataStore.channels['general'] = {
            name      = 'General',
            type      = 'general',
            icon      = '💬',
            members   = {},
            createdBy = nil,
            createdAt = os.time()
        }
        DataStore.SaveChannels()
    end
end

function DataStore.GetChannels()
    return DataStore.channels
end

function DataStore.GetPlayerChannels(playerId)
    local id = tostring(playerId)
    local result = {}
    for cid, ch in pairs(DataStore.channels) do
        if ch.type == 'general' then
            result[cid] = ch
        else
            for _, m in ipairs(ch.members or {}) do
                if m == id then
                    result[cid] = ch
                    break
                end
            end
        end
    end
    return result
end

function DataStore.HasChannelAccess(playerId, channelId)
    local ch = DataStore.channels[channelId]
    if not ch then return false end
    if ch.type == 'general' then return true end
    local id = tostring(playerId)
    for _, m in ipairs(ch.members or {}) do
        if m == id then return true end
    end
    return false
end

function DataStore.CreateChannel(playerId, name)
    local id = 'ch_' .. os.time() .. '_' .. math.random(1000, 9999)
    local pid = tostring(playerId)
    DataStore.channels[id] = {
        name      = name,
        type      = 'custom',
        icon      = '📢',
        createdBy = pid,
        members   = { pid },
        createdAt = os.time()
    }
    DataStore.SaveChannels()
    return id
end

function DataStore.InviteToChannel(channelId, targetId)
    local ch = DataStore.channels[channelId]
    if not ch then return false, 'Channel not found' end
    if ch.type == 'general' then return false, 'Cannot invite to General' end

    local tid = tostring(targetId)
    for _, m in ipairs(ch.members or {}) do
        if m == tid then return false, 'Already a member' end
    end

    table.insert(ch.members, tid)
    DataStore.SaveChannels()
    return true, 'Invited'
end

function DataStore.GetOrCreateDMChannel(playerId1, playerId2)
    local id1 = tostring(playerId1)
    local id2 = tostring(playerId2)
    local minId = id1 < id2 and id1 or id2
    local maxId = id1 < id2 and id2 or id1
    local channelId = 'dm_' .. minId .. '_' .. maxId

    if not DataStore.channels[channelId] then
        DataStore.channels[channelId] = {
            name      = 'DM',
            type      = 'dm',
            icon      = '📩',
            createdBy = id1,
            members   = { id1, id2 },
            createdAt = os.time()
        }
        DataStore.SaveChannels()
    end
    return channelId
end

-- ============================================================
-- Message Operations
-- ============================================================

function DataStore.GetMessages()
    return DataStore.messages
end

function DataStore.AddMessage(playerId, playerName, channel, message)
    local profile = DataStore.GetProfile(playerId)
    local msg = {
        id         = 'msg_' .. os.time() .. '_' .. math.random(1000, 9999),
        playerId   = playerId,
        playerName = playerName,
        profilePic = profile.profilePic or '',
        channel    = channel,
        message    = message,
        timestamp  = os.time()
    }

    table.insert(DataStore.messages, msg)

    while #DataStore.messages > Config.ChatMaxMessages do
        table.remove(DataStore.messages, 1)
    end

    DataStore.SaveMessages()
    return msg
end

-- ============================================================
-- HEAT Operations
-- ============================================================

function DataStore.GetHeatData()
    return DataStore.heat
end

function DataStore.UpdateHeat(playerId, vehicleData)
    local id = tostring(playerId)
    local now = os.time()

    local found = false
    for i, entry in ipairs(DataStore.heat) do
        if entry.playerId == id and entry.vehicleModel == vehicleData.model then
            DataStore.heat[i].heatLevel  = vehicleData.heatLevel
            DataStore.heat[i].lastSeen   = now
            DataStore.heat[i].plate      = vehicleData.plate
            if vehicleData.name then
                DataStore.heat[i].vehicleName = vehicleData.name
            end
            found = true
            break
        end
    end

    if not found then
        table.insert(DataStore.heat, {
            playerId    = id,
            playerName  = vehicleData.playerName or 'Unknown',
            vehicleModel = vehicleData.model,
            vehicleName  = vehicleData.name or vehicleData.model,
            plate       = vehicleData.plate or 'UNKNOWN',
            heatLevel   = vehicleData.heatLevel or 0,
            photoUrl    = '',
            lastSeen    = now
        })
    end

    DataStore.SaveHeat()
end

function DataStore.SetVehiclePhoto(playerId, vehicleModel, photoUrl)
    local id = tostring(playerId)
    for i, entry in ipairs(DataStore.heat) do
        if entry.playerId == id and entry.vehicleModel == vehicleModel then
            DataStore.heat[i].photoUrl = photoUrl or ''
            DataStore.SaveHeat()
            return true
        end
    end
    return false, 'Vehicle not found'
end

function DataStore.GetHeatRanking(max)
    max = max or Config.HEATRankingMax

    -- Per-vehicle ranking sorted by heat level
    local sorted = {}
    for _, entry in ipairs(DataStore.heat) do
        if entry.heatLevel and entry.heatLevel > 0 then
            table.insert(sorted, {
                playerId    = entry.playerId,
                playerName  = entry.playerName,
                vehicleName = entry.vehicleName or entry.vehicleModel,
                heatLevel   = entry.heatLevel,
                photoUrl    = entry.photoUrl or ''
            })
        end
    end

    table.sort(sorted, function(a, b)
        return a.heatLevel > b.heatLevel
    end)

    local result = {}
    for i = 1, math.min(max, #sorted) do
        sorted[i].rank = i
        table.insert(result, sorted[i])
    end
    return result
end

-- ============================================================
-- Helpers
-- ============================================================

function CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end
