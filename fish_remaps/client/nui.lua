-- fish_remaps: Client NUI Handler
RegisterNUICallback('nuiReady', function(data, cb)
    cb('ok')
end)

RegisterNUICallback('adjustStat', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local stat = data.stat
    local value = tonumber(data.value) or 0

    -- Clamp to max adjustment
    value = math.max(-Config.MaxStatAdjustment, math.min(Config.MaxStatAdjustment, value))

    cb(json.encode({
        stat = stat,
        value = value,
        clamped = value ~= tonumber(data.value)
    }))
end)

RegisterNUICallback('getArchetypeList', function(data, cb)
    local archetypes = {}
    local normalizerConfig = exports['fish_normalizer']:GetConfig()
    if normalizerConfig and normalizerConfig.Archetypes then
        for key, arch in pairs(normalizerConfig.Archetypes) do
            table.insert(archetypes, {
                key = key,
                label = arch.label,
                icon = arch.icon,
                description = arch.description
            })
        end
    end
    cb(json.encode(archetypes))
end)

RegisterNUICallback('getSubArchetypeList', function(data, cb)
    local subArchetypes = {}
    local normalizerConfig = exports['fish_normalizer']:GetConfig()
    if normalizerConfig and normalizerConfig.SubArchetypes then
        for key, sub in pairs(normalizerConfig.SubArchetypes) do
            table.insert(subArchetypes, {
                key = key,
                label = sub.label,
                icon = sub.icon,
                description = sub.description
            })
        end
    end
    cb(json.encode(subArchetypes))
end)

function IsRemapOpen()
    return isNuiOpen
end
