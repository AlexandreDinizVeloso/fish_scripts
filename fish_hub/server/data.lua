-- ============================================================
-- FISH HUB - Server Data Layer
-- ============================================================
-- Handles persistent storage via JSON files

DataStore = {}

local DATA_PATH = GetResourcePath(GetCurrentResourceName()) .. '/data/'
local files = {
    listings = DATA_PATH .. 'listings.json',
    messages = DATA_PATH .. 'messages.json',
    heat = DATA_PATH .. 'heat.json',
    chips = DATA_PATH .. 'chips.json'
}

-- In-memory caches
DataStore.listings = {}
DataStore.messages = {}
DataStore.heat = {}
DataStore.chips = {}

-- ============================================================
-- File I/O Helpers
-- ============================================================

local function EnsureDataDir()
    os.execute('mkdir -p "' .. DATA_PATH .. '"')
end

local function ReadJSON(filepath)
    local content = LoadResourceFile(GetCurrentResourceName(), filepath:sub(#GetResourcePath(GetCurrentResourceName()) + 2))
    if content and content ~= '' then
        local success, result = pcall(json.decode, content)
        if success then
            return result
        end
    end
    return nil
end

local function WriteJSON(filepath, data)
    local content = json.encode(data, { indent = true })
    local relativePath = filepath:sub(#GetResourcePath(GetCurrentResourceName()) + 2)
    SaveResourceFile(GetCurrentResourceName(), relativePath, content, -1)
end

-- ============================================================
-- Load / Save
-- ============================================================

function DataStore.LoadAll()
    EnsureDataDir()

    DataStore.listings = ReadJSON(files.listings) or {}
    DataStore.messages = ReadJSON(files.messages) or {}
    DataStore.heat = ReadJSON(files.heat) or {}
    DataStore.chips = ReadJSON(files.chips) or {}

    print('[FISH HUB Data] Loaded: ' .. #DataStore.listings .. ' listings, ' ..
          #DataStore.messages .. ' messages, ' ..
          #DataStore.heat .. ' heat entries, ' ..
          'chips for ' .. CountTable(DataStore.chips) .. ' players')
end

function DataStore.SaveListings()
    WriteJSON(files.listings, DataStore.listings)
end

function DataStore.SaveMessages()
    WriteJSON(files.messages, DataStore.messages)
end

function DataStore.SaveHeat()
    WriteJSON(files.heat, DataStore.heat)
end

function DataStore.SaveChips()
    WriteJSON(files.chips, DataStore.chips)
end

function DataStore.SaveAll()
    DataStore.SaveListings()
    DataStore.SaveMessages()
    DataStore.SaveHeat()
    DataStore.SaveChips()
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
    if not DataStore.chips[id] then
        DataStore.chips[id] = {}
    end

    -- Check max chips
    if #DataStore.chips[id] >= Config.MaxChipsPerTablet then
        return false, 'No free chip slots'
    end

    -- Check duplicate
    for _, chip in ipairs(DataStore.chips[id]) do
        if chip.type == chipType then
            return false, 'Chip already installed'
        end
    end

    table.insert(DataStore.chips[id], {
        type = chipType,
        installedAt = os.time()
    })

    DataStore.SaveChips()
    return true, 'Chip installed'
end

function DataStore.RemoveChip(playerId, chipType)
    local id = tostring(playerId)
    if not DataStore.chips[id] then
        return false, 'No chips installed'
    end

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
        id = 'lst_' .. os.time() .. '_' .. math.random(1000, 9999),
        sellerId = playerId,
        sellerName = data.sellerName or 'Unknown',
        name = data.name,
        description = data.description or '',
        price = tonumber(data.price) or 0,
        type = data.listingType or 'legal', -- legal or illegal
        category = data.category or 'parts',
        status = 'active',
        createdAt = os.time(),
        expiresAt = os.time() + Config.ListingDuration
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
    if changed then
        DataStore.SaveListings()
    end
end

-- ============================================================
-- Message Operations
-- ============================================================

function DataStore.GetMessages()
    return DataStore.messages
end

function DataStore.AddMessage(playerId, playerName, channel, message)
    local msg = {
        id = 'msg_' .. os.time() .. '_' .. math.random(1000, 9999),
        playerId = playerId,
        playerName = playerName,
        channel = channel,
        message = message,
        timestamp = os.time()
    }

    table.insert(DataStore.messages, msg)

    -- Trim to max
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

    -- Find existing entry or create new
    local found = false
    for i, entry in ipairs(DataStore.heat) do
        if entry.playerId == id and entry.vehicleModel == vehicleData.model then
            DataStore.heat[i].heatLevel = vehicleData.heatLevel
            DataStore.heat[i].lastSeen = now
            DataStore.heat[i].plate = vehicleData.plate
            found = true
            break
        end
    end

    if not found then
        table.insert(DataStore.heat, {
            playerId = id,
            playerName = vehicleData.playerName or 'Unknown',
            vehicleModel = vehicleData.model,
            vehicleName = vehicleData.name or vehicleData.model,
            plate = vehicleData.plate or 'UNKNOWN',
            heatLevel = vehicleData.heatLevel or 0,
            lastSeen = now
        })
    end

    DataStore.SaveHeat()
end

function DataStore.GetHeatRanking(max)
    max = max or Config.HEATRankingMax

    -- Aggregate heat per player
    local playerHeat = {}
    for _, entry in ipairs(DataStore.heat) do
        local pid = entry.playerId
        if not playerHeat[pid] then
            playerHeat[pid] = {
                playerId = pid,
                playerName = entry.playerName,
                totalHeat = 0,
                vehicleCount = 0
            }
        end
        playerHeat[pid].totalHeat = playerHeat[pid].totalHeat + (entry.heatLevel or 0)
        playerHeat[pid].vehicleCount = playerHeat[pid].vehicleCount + 1
        -- Update name if we have a newer one
        if entry.playerName and entry.playerName ~= 'Unknown' then
            playerHeat[pid].playerName = entry.playerName
        end
    end

    -- Convert to sorted array
    local ranking = {}
    for _, data in pairs(playerHeat) do
        table.insert(ranking, data)
    end

    table.sort(ranking, function(a, b)
        return a.totalHeat > b.totalHeat
    end)

    -- Trim
    local result = {}
    for i = 1, math.min(max, #ranking) do
        ranking[i].rank = i
        table.insert(result, ranking[i])
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

-- DataStore is available as a global for other scripts in this resource
