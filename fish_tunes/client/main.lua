-- fish_tunes: Client Main (v2 - Tabbed UI)
local isNuiOpen = false
local currentVehicle = nil
local tunesData = {}

-- Expose tunesData for other client scripts
function GetTunesDataForPlate(plate)
    return tunesData[plate]
end

function GetRawTunesData()
    return tunesData
end

function GetCurrentVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return nil
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

-- ============================================================
-- Open Tunes (single tabbed UI)
-- ============================================================

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

    -- Request full data from server (includes saved dyno, drivetrain, parts, health)
    TriggerServerEvent('fish_tunes:requestAdvancedData', plate)
end

RegisterCommand('tunes', function()
    if isNuiOpen then return end
    OpenTunes()
end, false)

-- ============================================================
-- Open NUI with full data
-- ============================================================

RegisterNetEvent('fish_tunes:openAdvancedNUI')
AddEventHandler('fish_tunes:openAdvancedNUI', function(plate, dynoData, dtData, engines, recipes, healthData, classData)
    local vehicle = GetCurrentVehicle()
    if not vehicle then return end

    currentVehicle = vehicle
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)

    -- Build parts data
    local currentParts = tunesData[plate] and tunesData[plate].parts or {}
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
                selected = (levelKey == currentLevel),
                cost = Config.PartCosts and Config.PartCosts[levelKey] or 0
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

    local tunes = GetVehicleTunes(vehicle)

    local sendData = {
        action = 'openAdvancedTunes',
        vehicleName = displayName,
        plate = plate,
        dyno = dynoData,
        drivetrain = dtData,
        engines = engines or {},
        recipes = recipes or {},
        classData = classData or { currentClass = 'C', score = 0 },
        currentClass = classData and classData.currentClass or 'C',
        -- Parts data
        categories = partsDisplay,
        currentParts = currentParts,
        totalBonuses = tunes and tunes.bonuses or { top_speed = 0, acceleration = 0, handling = 0, braking = 0 },
        currentHeat = tunes and tunes.heat or 0,
        maxHeat = Config.MaxHeat,
        partLevels = Config.PartLevels,
        -- Costs
        partCosts = Config.PartCosts or {},
        drivetrainCost = Config.DrivetrainCost or 5000,
        classSwapCosts = Config.ClassSwapCosts or {},
        -- Diagnostics (transform healthData to flat structure for JS)
        diagnostics = healthData and {
            engine = healthData.engine and healthData.engine.health or 100,
            transmission = healthData.transmission and healthData.transmission.health or 100,
            suspension = healthData.suspension and healthData.suspension.health or 100,
            brakes = healthData.brakes and healthData.brakes.health or 100,
            tires = healthData.tires and healthData.tires.health or 100,
            turbo = healthData.turbo and healthData.turbo.health or 100
        } or nil,
        tireHealth = healthData and healthData.tires and {
            fl = healthData.tires.health or 100,
            fr = healthData.tires.health or 100,
            rl = healthData.tires.health or 100,
            rr = healthData.tires.health or 100
        } or nil
    }

    SetNuiFocus(true, true)
    SendNUIMessage(sendData)
    isNuiOpen = true
end)

-- ============================================================
-- NUI Callbacks
-- ============================================================

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isNuiOpen = false
    currentVehicle = nil
    cb('ok')
end)

RegisterNUICallback('nuiReady', function(data, cb) cb('ok') end)

RegisterNUICallback('applyDynoTune', function(data, cb)
    if not currentVehicle then cb({success = false}); return end
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
    if not currentVehicle then cb({success = false}); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')

    TriggerServerEvent('fish_tunes:convertDrivetrainServer', plate, data.drivetrain)
    cb({success = true})
end)

RegisterNUICallback('installPart', function(data, cb)
    if not currentVehicle then cb({success = false}); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local category = data.category
    local level = data.level

    -- Request server to install (handles cost check)
    TriggerServerEvent('fish_tunes:installPartServer', plate, category, level)
    cb({success = true})
end)

RegisterNUICallback('uninstallPart', function(data, cb)
    if not currentVehicle then cb({success = false}); return end

    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    local category = data.category

    if tunesData[plate] and tunesData[plate].parts then
        tunesData[plate].parts[category] = 'stock'
    end

    local tunes = GetVehicleTunes(currentVehicle)
    TriggerServerEvent('fish_tunes:saveTunes', plate, tunesData[plate])
    TriggerEvent('fish_tunes:performanceUpdated', plate, tunesData[plate])

    cb({
        success = true,
        totalBonuses = tunes and tunes.bonuses or {},
        currentHeat = tunes and tunes.heat or 0
    })
end)

RegisterNUICallback('previewPart', function(data, cb)
    local bonuses = {}
    if Config.PartBonuses[data.category] and Config.PartBonuses[data.category][data.level] then
        bonuses = Config.PartBonuses[data.category][data.level]
    end
    local levelInfo = Config.PartLevels[data.level]
    cb({ bonuses = bonuses, levelInfo = levelInfo })
end)

RegisterNUICallback('craftPart', function(data, cb)
    TriggerServerEvent('fish_tunes:craftPartServer', data.recipeId)
    cb({success = true})
end)

RegisterNUICallback('classSwap', function(data, cb)
    if not currentVehicle then cb({success = false}); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    TriggerServerEvent('fish_tunes:swapClassServer', plate, data.targetClass)
    cb({success = true})
end)

RegisterNUICallback('repairVehicle', function(data, cb)
    if not currentVehicle then cb({success = false}); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    TriggerServerEvent('fish_tunes:repairVehicleServer', plate, data.partType or 'all')
    cb({success = true})
end)

RegisterNUICallback('setTransmissionMode', function(data, cb)
    if not currentVehicle then cb({success = false}); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    TriggerServerEvent('fish_tunes:setTransmissionModeServer', plate, data.mode)
    cb({success = true})
end)

RegisterNUICallback('setGearRatio', function(data, cb)
    if not currentVehicle then cb({success = false}); return end
    local plate = GetVehicleNumberPlateText(currentVehicle):gsub('%s+', '')
    TriggerServerEvent('fish_tunes:setGearRatioServer', plate, data.preset)
    cb({success = true})
end)

-- ============================================================
-- Server Events
-- ============================================================

RegisterNetEvent('fish_tunes:receiveData')
AddEventHandler('fish_tunes:receiveData', function(data)
    if data then tunesData = data end
end)

RegisterNetEvent('fish_tunes:clientNotify')
AddEventHandler('fish_tunes:clientNotify', function(msg)
    ShowNotification(msg)
end)

RegisterNetEvent('fish_tunes:partInstalled')
AddEventHandler('fish_tunes:partInstalled', function(plate, category, level, totalBonuses, heat)
    if tunesData[plate] then
        if not tunesData[plate].parts then tunesData[plate].parts = {} end
        tunesData[plate].parts[category] = level
    end
    -- Update NUI if open
    if isNuiOpen then
        SendNUIMessage({
            action = 'partInstalled',
            category = category,
            level = level,
            totalBonuses = totalBonuses,
            currentHeat = heat
        })
    end
end)

RegisterNetEvent('fish_tunes:classSwapped')
AddEventHandler('fish_tunes:classSwapped', function(plate, newClass, score)
    if isNuiOpen then
        SendNUIMessage({
            action = 'classSwapped',
            newClass = newClass,
            score = score
        })
    end
end)

RegisterNetEvent('fish_tunes:healthData')
AddEventHandler('fish_tunes:healthData', function(healthData)
    if isNuiOpen then
        SendNUIMessage({
            action = 'updateHealth',
            health = healthData
        })
    end
end)

-- ============================================================
-- Initialization
-- ============================================================

Citizen.CreateThread(function()
    TriggerServerEvent('fish_tunes:requestData')
end)

-- HEAT decay
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        for plate, data in pairs(tunesData) do
            if data.parts then
                local heat = 0
                for _, level in pairs(data.parts) do
                    local levelInfo = Config.PartLevels[level]
                    if levelInfo and not levelInfo.legal then
                        heat = heat + levelInfo.heat
                    end
                end
            end
        end
    end
end)

function ShowNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
