-- fish_tunes: Client Main
local isNuiOpen = false
local currentVehicle = nil
local tunesData = {}

function GetCurrentVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return nil
end

function HasMechanicJob()
    -- Qbox framework integration
    local playerData = exports.qbx_core:GetPlayerData()
    if playerData and playerData.job then
        return playerData.job.name == 'mechanic' or playerData.job.name == 'tuner'
    end
    return false
end

function GetInstalledParts(vehicle)
    if not DoesEntityExist(vehicle) then return {} end
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    return tunesData[plate] or {}
end

function GetVehicleTunes(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local data = tunesData[plate]
    if not data then return nil end

    local totalBonuses = { top_speed = 0, acceleration = 0, handling = 0, braking = 0 }
    local totalHeat = 0
    local totalInstability = 0

    for category, level in pairs(data.parts or {}) do
        local bonuses = Config.PartBonuses[category] and Config.PartBonuses[category][level]
        if bonuses then
            for stat, val in pairs(bonuses) do
                if stat == 'instability' then
                    totalInstability = totalInstability + val
                elseif stat == 'durability_loss' then
                    -- handled separately
                elseif totalBonuses[stat] then
                    totalBonuses[stat] = totalBonuses[stat] + val
                end
            end
        end

        local levelInfo = Config.PartLevels[level]
        if levelInfo and not levelInfo.legal then
            totalHeat = totalHeat + levelInfo.heat
        end
    end

    return {
        parts = data.parts,
        bonuses = totalBonuses,
        heat = totalHeat, 
        instability = totalInstability
    }
end

function GetVehicleHeat(vehicle)
    local tunes = GetVehicleTunes(vehicle)
    return tunes and tunes.heat or 0
end

function HasIllegalParts(vehicle)
    local parts = GetInstalledParts(vehicle)
    if not parts.parts then return false end
    for _, level in pairs(parts.parts) do
        if level == 'l4' or level == 'l5' then return true end
    end
    return false
end

function OpenTunes()
    local vehicle = GetCurrentVehicle()
    if not vehicle then
        ShowNotification('~r~You must be in a vehicle to use the tuning system.')
        return
    end

    currentVehicle = vehicle
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)

    local currentParts = {}
    if tunesData[plate] and tunesData[plate].parts then
        currentParts = tunesData[plate].parts
    end

    -- Build parts data with bonuses
    local partsDisplay = {}
    for _, cat in ipairs(Config.PartCategories) do
        local currentLevel = currentParts[cat.key] or 'stock'
        local bonuses = Config.PartBonuses[cat.key] or {}
        local levelsDisplay = {}

        for levelKey, levelInfo in pairs(Config.PartLevels) do
            local bonus = bonuses[levelKey] or {}
            table.insert(levelsDisplay, {
                key = levelKey,
                label = levelInfo.label,
                icon = levelInfo.icon,
                color = levelInfo.color,
                legal = levelInfo.legal,
                heat = levelInfo.heat,
                bonuses = bonus,
                selected = (levelKey == currentLevel)
            })
        end

        table.insert(partsDisplay, {
            key = cat.key,
            label = cat.label,
            icon = cat.icon,
            description = cat.description,
            currentLevel = currentLevel,
            levels = levelsDisplay
        })
    end

    -- Calculate current totals
    local tunes = GetVehicleTunes(vehicle)

    local sendData = {
        action = 'openTunes',
        vehicleName = displayName,
        plate = plate,
        categories = partsDisplay,
        currentParts = currentParts,
        totalBonuses = tunes and tunes.bonuses or { top_speed = 0, acceleration = 0, handling = 0, braking = 0 },
        currentHeat = tunes and tunes.heat or 0,
        maxHeat = Config.MaxHeat,
        partLevels = Config.PartLevels
    }

    SetNuiFocus(true, true)
    SendNUIMessage(sendData)
    isNuiOpen = true
end

RegisterCommand('tunes', function()
    if isNuiOpen then return end
    OpenTunes()
end, false)

function OpenAdvancedTunes()
    local vehicle = GetCurrentVehicle()
    if not vehicle then
        ShowNotification('~r~You must be in a vehicle to use the advanced tuning system.')
        return
    end
    
    if not HasMechanicJob() then
        ShowNotification('~r~Only authorized mechanics can access advanced tuning.')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    TriggerServerEvent('fish_tunes:requestAdvancedData', plate)
end

RegisterNetEvent('fish_tunes:openAdvancedNUI')
AddEventHandler('fish_tunes:openAdvancedNUI', function(plate, dynoData, dtData, engines, recipes)
    local vehicle = GetCurrentVehicle()
    if not vehicle then return end
    
    currentVehicle = vehicle
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)

    local sendData = {
        action = 'openAdvancedTunes',
        vehicleName = displayName,
        plate = plate,
        dyno = dynoData,
        drivetrain = dtData,
        engines = engines,
        recipes = recipes
    }

    SetNuiFocus(true, true)
    SendNUIMessage(sendData)
    isNuiOpen = true
end)

RegisterCommand('advtunes', function()
    if isNuiOpen then return end
    OpenAdvancedTunes()
end, false)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isNuiOpen = false
    currentVehicle = nil
    cb('ok')
end)

RegisterNUICallback('nuiReadyAdvanced', function(data, cb)
    cb('ok')
end)

RegisterNUICallback('applyDynoTune', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    
    if not tunesData[plate] then tunesData[plate] = {} end
    tunesData[plate].dyno = {
        afr = data.afr,
        timing = data.timing,
        boost = data.boost,
        drive = data.drive
    }
    
    TriggerServerEvent('fish_tunes:saveTunes', plate, tunesData[plate])
    exports.fish_tunes:ApplyDynoTuning(currentVehicle, tunesData[plate].dyno)
    
    ShowNotification('~g~ECU Flash applied successfully.')
    cb({success = true})
end)

RegisterNUICallback('convertDrivetrain', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    
    if not tunesData[plate] then tunesData[plate] = {} end
    tunesData[plate].drivetrain = data.drivetrain
    
    TriggerServerEvent('fish_tunes:saveTunes', plate, tunesData[plate])
    exports.fish_tunes:ApplyDrivetrainModifiers(currentVehicle, data.drivetrain)
    
    ShowNotification('~g~Drivetrain converted to ' .. data.drivetrain)
    cb({success = true})
end)

RegisterNUICallback('swapEngine', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    
    TriggerServerEvent('fish_tunes:swapEngineServer', plate, data.engineType, data.cost)
    cb({success = true})
end)

RegisterNUICallback('setTransmissionMode', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    
    TriggerServerEvent('fish_tunes:setTransmissionModeServer', plate, data.mode)
    cb({success = true})
end)

RegisterNUICallback('setGearRatio', function(data, cb)
    if not currentVehicle then cb('error'); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    
    TriggerServerEvent('fish_tunes:setGearRatioServer', plate, data.preset)
    cb({success = true})
end)

RegisterNUICallback('craftPart', function(data, cb)
    TriggerServerEvent('fish_tunes:craftPartServer', data.recipeId)
    cb({success = true})
end)

RegisterNUICallback('installPart', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local category = data.category
    local level = data.level

    if not tunesData[plate] then
        tunesData[plate] = { parts = {} }
    end
    if not tunesData[plate].parts then
        tunesData[plate].parts = {}
    end

    tunesData[plate].parts[category] = level

    -- Recalculate
    local tunes = GetVehicleTunes(currentVehicle)

    TriggerServerEvent('fish_tunes:saveTunes', plate, tunesData[plate])

    cb({
        success = true,
        totalBonuses = tunes and tunes.bonuses or {},
        currentHeat = tunes and tunes.heat or 0,
        instability = tunes and tunes.instability or 0
    })
end)

RegisterNUICallback('uninstallPart', function(data, cb)
    if not currentVehicle then cb('error'); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local category = data.category

    if tunesData[plate] and tunesData[plate].parts then
        tunesData[plate].parts[category] = 'stock'
    end

    local tunes = GetVehicleTunes(currentVehicle)

    TriggerServerEvent('fish_tunes:saveTunes', plate, tunesData[plate])

    cb({
        success = true,
        totalBonuses = tunes and tunes.bonuses or {},
        currentHeat = tunes and tunes.heat or 0
    })
end)

RegisterNUICallback('previewPart', function(data, cb)
    local category = data.category
    local level = data.level
    local bonuses = {}

    if Config.PartBonuses[category] and Config.PartBonuses[category][level] then
        bonuses = Config.PartBonuses[category][level]
    end

    local levelInfo = Config.PartLevels[level]

    cb({
        bonuses = bonuses,
        levelInfo = levelInfo
    })
end)

RegisterNetEvent('fish_tunes:receiveData')
AddEventHandler('fish_tunes:receiveData', function(data)
    if data then 
        tunesData = data 
        
        -- Reapply physics if currently in a vehicle
        local vehicle = GetCurrentVehicle()
        if vehicle then
            local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
            if tunesData[plate] then
                if tunesData[plate].dyno then
                    exports.fish_tunes:ApplyDynoTuning(vehicle, tunesData[plate].dyno)
                end
                if tunesData[plate].drivetrain then
                    exports.fish_tunes:ApplyDrivetrainModifiers(vehicle, tunesData[plate].drivetrain)
                end
            end
        end
    end
end)

RegisterNetEvent('fish_tunes:clientNotify')
AddEventHandler('fish_tunes:clientNotify', function(msg)
    ShowNotification(msg)
end)

RegisterNetEvent('fish_tunes:clientEngineSwapped')
AddEventHandler('fish_tunes:clientEngineSwapped', function(plate, engineData)
    local vehicle = GetCurrentVehicle()
    if vehicle and GetVehicleNumberPlateText(vehicle):gsub('%s+', '') == plate then
        exports.fish_tunes:ApplyEngineSwapModifiers(vehicle, engineData)
    end
end)

Citizen.CreateThread(function()
    TriggerServerEvent('fish_tunes:requestData')
end)

-- HEAT decay thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- every minute
        for plate, data in pairs(tunesData) do
            if data.parts then
                local heat = 0
                for _, level in pairs(data.parts) do
                    local levelInfo = Config.PartLevels[level]
                    if levelInfo and not levelInfo.legal then
                        heat = heat + levelInfo.heat
                    end
                end
                -- Heat doesn't decay from parts, only from gameplay events
            end
        end
    end
end)

function ShowNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
