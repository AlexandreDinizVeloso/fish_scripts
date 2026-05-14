-- fish_tunes: Vehicle Health Inspection HUD
-- /checkcar - Shows full vehicle health, wear, and degradation status

local isShowingHUD = false
local hudData = nil
local hudExpiry = 0
local HUD_DISPLAY_DURATION = 15000 -- 15 seconds

-- ============================================================
-- Color helpers
-- ============================================================
local function HealthColor(health)
    if health >= 90 then return 102, 187, 106    -- green
    elseif health >= 75 then return 79, 195, 247  -- blue
    elseif health >= 50 then return 255, 213, 79  -- yellow
    elseif health >= 25 then return 255, 136, 0   -- orange
    else return 255, 23, 68 end                    -- red
end

local function StatusEmoji(health)
    if health >= 90 then return "[OK]"
    elseif health >= 75 then return "[--]"
    elseif health >= 50 then return "[!]"
    elseif health >= 25 then return "[!!]"
    else return "[X]" end
end

local function HealthBar(health, width)
    local filled = math.floor((health / 100) * width)
    local bar = ""
    for i = 1, width do
        if i <= filled then
            bar = bar .. "█"
        else
            bar = bar .. "░"
        end
    end
    return bar
end

-- ============================================================
-- Draw text helper
-- ============================================================
local function DrawText2D(x, y, scale, text, r, g, b, a)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a or 255)
    SetTextDropshadow(2, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function DrawRect2D(x, y, w, h, r, g, b, a)
    DrawRect(x + w/2, y + h/2, w, h, r, g, b, a)
end

-- ============================================================
-- Render the HUD
-- ============================================================
local function RenderHUD()
    if not hudData or not isShowingHUD then return end
    
    -- Check expiry
    if GetGameTimer() > hudExpiry then
        isShowingHUD = false
        return
    end

    local baseX = 0.010
    local baseY = 0.15
    local lineH = 0.024
    local panelW = 0.26
    local currentY = baseY

    -- Background panel
    local totalLines = 24
    if hudData.tires then totalLines = totalLines + 1 end
    if hudData.drivetrain and hudData.drivetrain ~= "N/A" then totalLines = totalLines + 1 end
    if hudData.engineType and hudData.engineType ~= "stock" then totalLines = totalLines + 1 end
    local panelH = lineH * totalLines
    DrawRect2D(baseX - 0.003, currentY - 0.005, panelW + 0.006, panelH + 0.01, 20, 20, 30, 220)

    -- Title
    DrawText2D(baseX, currentY, 0.40, "~w~>> ~y~VEHICLE INSPECTION REPORT", 255, 213, 79, 255)
    currentY = currentY + lineH
    DrawText2D(baseX, currentY, 0.28, "~c~" .. (hudData.vehicleName or "Unknown") .. "  |  " .. (hudData.plate or "N/A"), 180, 180, 180, 255)
    currentY = currentY + lineH

    -- Mileage & Drivetrain
    local infoLine = string.format("~c~Mileage: ~w~%s km", FormatNumber(hudData.mileage or 0))
    if hudData.drivetrain and hudData.drivetrain ~= "N/A" then
        infoLine = infoLine .. "  |  DT: ~b~" .. hudData.drivetrain
    end
    if hudData.engineType and hudData.engineType ~= "stock" then
        infoLine = infoLine .. "  |  Engine: ~o~" .. hudData.engineType
    end
    DrawText2D(baseX, currentY, 0.25, infoLine, 180, 180, 180, 255)
    currentY = currentY + lineH

    -- Separator
    DrawRect2D(baseX, currentY, panelW, 0.001, 100, 100, 120, 150)
    currentY = currentY + 0.006

    -- Parts Health Section
    DrawText2D(baseX, currentY, 0.28, "~y~PARTS HEALTH", 255, 213, 79, 255)
    currentY = currentY + lineH

    local parts = {
        { key = "engine",       label = "Engine",       icon = "[E]" },
        { key = "transmission", label = "Transmission", icon = "[T]" },
        { key = "suspension",   label = "Suspension",   icon = "[S]" },
        { key = "brakes",       label = "Brakes",       icon = "[B]" },
        { key = "turbo",        label = "Turbo",        icon = "[*]" },
        { key = "tires",        label = "Tires",        icon = "[W]" },
    }

    for _, part in ipairs(parts) do
        local health = hudData[part.key] or 100
        local r, g, b = HealthColor(health)
        local emoji = StatusEmoji(health)
        local bar = HealthBar(health, 15)
        local line = string.format("  %s %-14s %s ~w~%3d%% %s", part.icon, part.label, emoji, health, bar)
        DrawText2D(baseX, currentY, 0.25, line, r, g, b, 255)
        currentY = currentY + lineH
    end

    -- Per-wheel tire detail
    if hudData.tireWheels then
        local wheelLabel = { "FL", "RL", "FR", "RR" }
        -- Show as separate mini-line with color coding
        local tireVals = "  "
        for i, h in ipairs(hudData.tireWheels) do
            local label = wheelLabel[i] or ("W" .. i)
            if h < 50 then
                tireVals = tireVals .. string.format("~r~%s:%d%%~w~  ", label, h)
            elseif h < 75 then
                tireVals = tireVals .. string.format("~y~%s:%d%%~w~  ", label, h)
            else
                tireVals = tireVals .. string.format("~g~%s:%d%%~w~  ", label, h)
            end
        end
        DrawText2D(baseX, currentY, 0.23, tireVals, 200, 200, 200, 255)
        currentY = currentY + lineH
    end

    -- Separator
    DrawRect2D(baseX, currentY, panelW, 0.001, 100, 100, 120, 150)
    currentY = currentY + 0.006

    -- Installed Parts
    if hudData.parts and next(hudData.parts) then
        DrawText2D(baseX, currentY, 0.28, "~y~INSTALLED PARTS", 255, 213, 79, 255)
        currentY = currentY + lineH
        for category, level in pairs(hudData.parts) do
            local levelInfo = Config.PartLevels[level]
            local label = levelInfo and levelInfo.label or level
            local color = levelInfo and levelInfo.color or "#8B8B8B"
            local legal = levelInfo and levelInfo.legal
            local legalStr = ""
            if not legal then legalStr = " ~r~[ILLEGAL]" end
            local r = tonumber(color:sub(2,3), 16)
            local g = tonumber(color:sub(4,5), 16)
            local b = tonumber(color:sub(6,7), 16)
            DrawText2D(baseX, currentY, 0.24, string.format("  %-16s %s%s", category:upper(), label, legalStr), r, g, b, 255)
            currentY = currentY + lineH
        end
    end

    -- Separator
    DrawRect2D(baseX, currentY, panelW, 0.001, 100, 100, 120, 150)
    currentY = currentY + 0.006

    -- Heat & Dyno
    local heat = hudData.heat or 0
    local heatR, heatG, heatB = 100, 200, 100
    if heat > 60 then heatR, heatG, heatB = 255, 136, 0
    elseif heat > 30 then heatR, heatG, heatB = 255, 213, 79 end
    DrawText2D(baseX, currentY, 0.25, string.format("  HEAT Level: ~w~%d / %d", heat, Config.MaxHeat), heatR, heatG, heatB, 255)
    currentY = currentY + lineH

    if hudData.dyno then
        DrawText2D(baseX, currentY, 0.25, string.format("  ECU: ~b~AFR %.1f~w~ | Timing %+.1f | Boost %d | Drive %.2f",
            hudData.dyno.afr or 13.5, hudData.dyno.timing or 0, hudData.dyno.boost or 0, hudData.dyno.drive or 3.55), 200, 200, 200, 255)
        currentY = currentY + lineH
    end

    -- Overall score
    local overallHealth = hudData.overall or 100
    local or2, og, ob = HealthColor(overallHealth)
    DrawRect2D(baseX, currentY, panelW, 0.001, 100, 100, 120, 150)
    currentY = currentY + 0.006
    DrawText2D(baseX, currentY, 0.30, string.format("  Overall: %s %d%%", StatusEmoji(overallHealth), overallHealth), or2, og, ob, 255)
    currentY = currentY + lineH

    -- Footer
    DrawText2D(baseX, currentY, 0.22, "~c~Press [H] to dismiss  |  Auto-hides in 15s", 140, 140, 140, 200)
end

-- ============================================================
-- Format number with commas
-- ============================================================
function FormatNumber(n)
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- ============================================================
-- Gather all vehicle data and show HUD
-- ============================================================
function CheckCar()
    local vehicle = GetCurrentVehicle()
    if not vehicle then
        ShowNotification('~r~You must be in a vehicle to inspect it.')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)

    -- Gather tunes data (local, via helper)
    local tunes = GetTunesDataForPlate(plate) or {}
    local parts = tunes.parts or {}
    local dyno = tunes.dyno or nil
    local drivetrain = tunes.drivetrain or "N/A"

    -- Calculate heat
    local heat = 0
    for _, level in pairs(parts) do
        local levelInfo = Config.PartLevels[level]
        if levelInfo and not levelInfo.legal then
            heat = heat + levelInfo.heat
        end
    end

    -- Get engine type
    local engineType = "stock"
    if tunes.engine then
        engineType = tunes.engine.type or tunes.engine or "stock"
    end

    -- Get per-wheel tire health from client-side cache
    local tireWheels = nil
    local tiresHealth = 100
    if GetResourceState('fish_tunes') == 'started' then
        local success, result = pcall(function()
            return exports.fish_tunes:GetTireHealth(vehicle)
        end)
        if success and result then
            tireWheels = {}
            local total = 0
            local count = 0
            for i, h in pairs(result) do
                table.insert(tireWheels, math.floor(h))
                total = total + h
                count = count + 1
            end
            if count > 0 then tiresHealth = math.floor(total / count) end
        end
    end

    -- Request server health data
    TriggerServerEvent('fish_tunes:requestCheckCar', plate)

    -- Build initial HUD data (will be enriched when server responds)
    hudData = {
        vehicleName = displayName,
        plate = plate,
        mileage = 0,
        drivetrain = drivetrain,
        engineType = engineType,
        parts = parts,
        heat = heat,
        dyno = dyno,
        engine = 100,
        transmission = 100,
        suspension = 100,
        brakes = 100,
        turbo = 100,
        tires = tiresHealth,
        tireWheels = tireWheels,
        overall = 100
    }

    isShowingHUD = true
    hudExpiry = GetGameTimer() + HUD_DISPLAY_DURATION

    -- Start render thread
    Citizen.CreateThread(function()
        while isShowingHUD do
            RenderHUD()
            
            -- Dismiss with H key
            if IsControlJustPressed(0, 74) then -- H key
                isShowingHUD = false
            end
            
            Citizen.Wait(0)
        end
    end)
end

-- ============================================================
-- Receive server health data
-- ============================================================
RegisterNetEvent('fish_tunes:receiveCheckCar')
AddEventHandler('fish_tunes:receiveCheckCar', function(healthData)
    if not hudData then return end

    if healthData then
        hudData.engine = healthData.engine and healthData.engine.health or 100
        hudData.transmission = healthData.transmission and healthData.transmission.health or 100
        hudData.suspension = healthData.suspension and healthData.suspension.health or 100
        hudData.brakes = healthData.brakes and healthData.brakes.health or 100
        hudData.turbo = healthData.turbo and healthData.turbo.health or 100
        
        -- Only override tire health if server has it and we don't have per-wheel data
        if not hudData.tireWheels then
            hudData.tires = healthData.tires and healthData.tires.health or 100
        end
        
        hudData.mileage = healthData.overall and healthData.overall.mileage or 0
        hudData.overall = healthData.overall and healthData.overall.health or 100
    end

    -- Keep HUD visible
    isShowingHUD = true
    hudExpiry = GetGameTimer() + HUD_DISPLAY_DURATION
end)

-- ============================================================
-- Register command
-- ============================================================
RegisterCommand('checkcar', function()
    if isShowingHUD then
        isShowingHUD = false
        return
    end
    CheckCar()
end, false)

-- Also register /cc as shorthand
RegisterCommand('cc', function()
    if isShowingHUD then
        isShowingHUD = false
        return
    end
    CheckCar()
end, false)
