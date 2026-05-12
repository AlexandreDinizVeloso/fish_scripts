-- fish_tunes: Client NUI Handler
RegisterNUICallback('nuiReady', function(data, cb) cb('ok') end)

RegisterNUICallback('calculateTotals', function(data, cb)
    local parts = data.parts or {}
    local totalBonuses = { top_speed = 0, acceleration = 0, handling = 0, braking = 0 }
    local totalHeat = 0
    local totalInstability = 0

    for category, level in pairs(parts) do
        local bonuses = Config.PartBonuses[category] and Config.PartBonuses[category][level]
        if bonuses then
            for stat, val in pairs(bonuses) do
                if stat == 'instability' then
                    totalInstability = totalInstability + val
                elseif stat ~= 'durability_loss' and totalBonuses[stat] then
                    totalBonuses[stat] = totalBonuses[stat] + val
                end
            end
        end
        local levelInfo = Config.PartLevels[level]
        if levelInfo and not levelInfo.legal then
            totalHeat = totalHeat + levelInfo.heat
        end
    end

    cb(json.encode({
        bonuses = totalBonuses,
        heat = math.min(Config.MaxHeat, totalHeat),
        instability = totalInstability
    }))
end)

function IsTunesOpen()
    return isNuiOpen
end
