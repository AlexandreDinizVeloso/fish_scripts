-- ============================================================
-- fish_remaps: Server Main (oxmysql + DNA Blend + State Bags)
-- ============================================================

local DB = nil  -- set on resource start from FishDB global

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- FishDB global is set by fish_normalizer's shared/database.lua
    DB = FishDB
    if not DB then
        print('[fish_remaps] ERROR: FishDB not available. Is fish_normalizer running?')
        return
    end
    print('[fish_remaps] Started. Using shared oxmysql schema.')
end)

-- ============================================================
-- Helper: Get player identifier
-- ============================================================

local function GetIdentifier(src)
    return GetPlayerIdentifier(src, 0) or ('player:' .. src)
end

-- ============================================================
-- Helper: Push handling update via normalizer export
-- ============================================================

local function RefreshVehicleState(plate, vehicleNetId)
    local normData = exports['fish_normalizer']:GetVehicleDataServer(plate)
    if not normData then return end
    local remapData = DB.GetRemap(plate)
    local tuneData  = DB.GetTunes(plate)
    exports['fish_normalizer']:PushVehicleState(vehicleNetId, normData, remapData, tuneData)
end

-- ============================================================
-- DNA Inheritance Blend (75% new / 25% original)
-- Applied when archetype changes. Sub-archetype is 100% new.
-- ============================================================

local function BlendArchetypeStats(originalArchetype, newArchetype, statAdjustments)
    -- The blend is handled in the handling engine via BuildHandlingProfile.
    -- Here we only need to persist the original/current archetype correctly.
    return {
        original_archetype = originalArchetype,
        current_archetype  = newArchetype,
    }
end

-- ============================================================
-- Net Event: Confirm Remap (costs + save + state bag update)
-- ============================================================

RegisterNetEvent('fish_remaps:confirmRemap')
AddEventHandler('fish_remaps:confirmRemap', function(plate, data, vehicleNetId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if not plate or not data then
        TriggerClientEvent('fish_remaps:notify', src, {type='error', message='Invalid remap data.'})
        return
    end

    local identifier = GetIdentifier(src)
    local existing   = DB.GetRemap(plate)
    local costs      = Config.Costs or {}
    local totalCost  = 0

    -- Calculate cost based on changes
    local currentArch = existing and existing.current_archetype
    if data.current_archetype and currentArch ~= data.current_archetype then
        totalCost = totalCost + (costs.archetype_change or 15000)
    end

    local currentSub = existing and existing.sub_archetype
    if data.sub_archetype and currentSub ~= data.sub_archetype then
        totalCost = totalCost + (costs.subarchetype_change or 5000)
    end

    if data.stat_adjustments then
        local totalPoints = 0
        for _, val in pairs(data.stat_adjustments) do
            totalPoints = totalPoints + math.abs(val or 0)
        end
        totalCost = totalCost + (totalPoints * (costs.adjustment_per_point or 1000))
    end

    -- Validate stat adjustment limits per stage
    local stage       = data.stage or (existing and existing.stage) or 0
    local stageLimits = { [0]=2, [1]=2, [2]=4, [3]=6 }
    local stageLimit  = stageLimits[stage] or 2
    if data.stat_adjustments then
        for stat, val in pairs(data.stat_adjustments) do
            if math.abs(val) > stageLimit then
                TriggerClientEvent('fish_remaps:notify', src, {
                    type = 'error',
                    message = ('Stat adjustment for %s exceeds Stage %d limit (%d pts)'):format(stat, stage, stageLimit)
                })
                return
            end
        end
    end

    -- Charge money
    if totalCost > 0 then
        if not player.Functions.RemoveMoney('bank', totalCost, 'vehicle-remap') then
            TriggerClientEvent('fish_remaps:notify', src, {
                type    = 'error',
                message = ('Not enough money. Need $%d'):format(totalCost)
            })
            return
        end
    end

    -- Preserve original archetype (only set on first remap)
    local normData = exports['fish_normalizer']:GetVehicleDataServer(plate)
    if not data.original_archetype then
        data.original_archetype = (existing and existing.original_archetype)
                                or (normData and normData.archetype)
                                or 'esportivo'
    end
    data.total_cost = (existing and existing.total_cost or 0) + totalCost

    -- Save to DB
    DB.SaveRemap(plate, data, identifier)

    print(('[fish_remaps] %s remapped %s → archetype:%s sub:%s ($%d)'):format(
        GetPlayerName(src), plate,
        data.current_archetype or '?',
        data.sub_archetype or 'none',
        totalCost
    ))

    -- Refresh state bags
    if vehicleNetId and vehicleNetId > 0 then
        RefreshVehicleState(plate, vehicleNetId)
    end

    TriggerClientEvent('fish_remaps:notify', src, {
        type    = 'success',
        message = ('Remap applied! Cost: $%d'):format(totalCost)
    })
    TriggerClientEvent('fish_remaps:remapApplied', src, plate, data)
end)

-- ============================================================
-- Net Event: Save Dyno (ECU flash)
-- ============================================================

RegisterNetEvent('fish_remaps:saveDyno')
AddEventHandler('fish_remaps:saveDyno', function(plate, dynoData, vehicleNetId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local cost = Config.Costs and Config.Costs.dyno_flash or 2000
    if not player.Functions.RemoveMoney('bank', cost, 'dyno-flash') then
        TriggerClientEvent('fish_remaps:notify', src, {type='error', message=('Need $%d for ECU flash'):format(cost)})
        return
    end

    local identifier = GetIdentifier(src)
    local existing   = DB.GetRemap(plate) or {}
    existing.dyno    = dynoData
    DB.SaveRemap(plate, existing, identifier)

    if vehicleNetId and vehicleNetId > 0 then
        RefreshVehicleState(plate, vehicleNetId)
    end

    TriggerClientEvent('fish_remaps:notify', src, {type='success', message=('ECU Flash applied! -$%d'):format(cost)})
end)

-- ============================================================
-- Net Event: Save Transmission settings
-- ============================================================

RegisterNetEvent('fish_remaps:saveTransmission')
AddEventHandler('fish_remaps:saveTransmission', function(plate, transData, vehicleNetId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local costs = Config.Costs or {}
    local cost  = 0
    if transData.mode     then cost = cost + (costs.trans_mode  or 3000) end
    if transData.gearPreset then cost = cost + (costs.gear_ratio or 5000) end

    if cost > 0 and not player.Functions.RemoveMoney('bank', cost, 'trans-tune') then
        TriggerClientEvent('fish_remaps:notify', src, {type='error', message=('Need $%d'):format(cost)})
        return
    end

    local identifier = GetIdentifier(src)
    local existing   = DB.GetRemap(plate) or {}
    if transData.mode       then existing.trans_mode  = transData.mode end
    if transData.gearPreset then existing.gear_preset = transData.gearPreset end
    DB.SaveRemap(plate, existing, identifier)

    if vehicleNetId and vehicleNetId > 0 then
        RefreshVehicleState(plate, vehicleNetId)
    end

    TriggerClientEvent('fish_remaps:notify', src, {type='success', message=('Transmission updated! -$%d'):format(cost)})
end)

-- ============================================================
-- Net Event: Client requests remap data for a single plate
-- ============================================================

RegisterNetEvent('fish_remaps:requestData')
AddEventHandler('fish_remaps:requestData', function(plate)
    local src = source
    local data = DB.GetRemap(plate) or {}
    TriggerClientEvent('fish_remaps:receiveData', src, plate, data)
end)

-- ============================================================
-- Net Event: Client requests ALL remap data (on spawn)
-- Returns a table keyed by plate for client-side cache
-- ============================================================

RegisterNetEvent('fish_remaps:requestAllData')
AddEventHandler('fish_remaps:requestAllData', function()
    local src = source
    local identifier = GetIdentifier(src)
    -- Query all remaps belonging to this player
    local result = MySQL.query.await(
        'SELECT * FROM fish_vehicle_remaps WHERE owner_identifier = ?', {identifier}
    )
    local allData = {}
    if result then
        for _, row in ipairs(result) do
            if row.stat_adjustments and type(row.stat_adjustments) == 'string' then
                row.stat_adjustments = json.decode(row.stat_adjustments) or {}
            end
            if row.dyno and type(row.dyno) == 'string' then
                row.dyno = json.decode(row.dyno) or {}
            end
            allData[row.plate] = row
        end
    end
    TriggerClientEvent('fish_remaps:receiveAllData', src, allData)
end)

-- ============================================================
-- Server Exports
-- ============================================================

exports('GetVehicleRemapDataServer', function(plate)
    return DB.GetRemap(plate)
end)
