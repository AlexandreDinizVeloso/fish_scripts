-- fish_normalizer: Client NUI Handler
-- Handles NUI messages and state management

local nuiReady = false

-- Listen for NUI ready state
RegisterNUICallback('nuiReady', function(data, cb)
    nuiReady = true
    cb('ok')
end)

-- Listen for archetype preview (hover)
RegisterNUICallback('previewArchetype', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local archetype = data.archetype
    local stats = GetVehiclePerformanceStats(currentVehicle)
    local baseScore = CalculateBaseScore(stats)
    local finalScore, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, archetype)

    local rank = GetRankFromScore(finalScore)

    cb(json.encode({
        score = finalScore,
        rank = rank,
        stats = modifiedStats or stats.normalized
    }))
end)

-- Listen for sub-archetype preview
RegisterNUICallback('previewSubArchetype', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local archetype = data.archetype or 'esportivo'
    local subArchetype = data.subArchetype
    local stats = GetVehiclePerformanceStats(currentVehicle)
    local baseScore = CalculateBaseScore(stats)
    local finalScore, modifiedStats = ApplyArchetypeModifiers(baseScore, stats, archetype)
    finalScore = ApplySubArchetypeBonuses(finalScore, subArchetype)

    local rank = GetRankFromScore(finalScore)

    cb(json.encode({
        score = finalScore,
        rank = rank,
        stats = modifiedStats or stats.normalized
    }))
end)

-- Get rank color helper
function GetRankColor(score)
    for _, rank in ipairs(Config.Ranks) do
        if score >= rank.min and score <= rank.max then
            return rank.color
        end
    end
    return '#8B8B8B'
end

-- Export for other resources to check NUI state
function IsNormalizerOpen()
    return isNuiOpen
end
