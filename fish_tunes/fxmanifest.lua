fx_version 'cerulean'
game 'gta5'

name 'fish_tunes'
description 'Vehicle Tuning System - Parts, Levels & HEAT'
author 'Fish Vehicles'
version '2.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/nui.lua',
    'client/dyno.lua',
    'client/drivetrain.lua',
    'client/tires.lua',
    'client/checkcar.lua'
}

server_scripts {
    'server/data.lua',
    'server/degradation.lua',
    'server/mileage.lua',
    'server/tires.lua',
    'server/transmission.lua',
    'server/dyno.lua',
    'server/drivetrain.lua',
    'server/engine_swap.lua',
    'server/crafting.lua',
    'server/analytics.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'fish_normalizer'
}

exports {
    'GetVehicleTunes',
    'GetInstalledParts',
    'GetVehicleHeat',
    'HasIllegalParts',
    'GetVehicleHealthSummary',
    'UpdateVehicleMileage',
    'ApplyDegradation',
    'RepairVehicle',
    'GetHealthStatus',
    'ApplyDynoTuning',
    'ApplyDrivetrainModifiers',
    'ApplyTireModifiers',
    'ApplyEngineSwapModifiers',
    'ClearDrivetrainCache',
    'ForceHandlingRefresh',
    'DegradeTires',
    'GetTireHealth',
    'SetTireHealth',
    'ClearTireCache'
}

server_exports {
    'GetVehicleTunesServer',
    'SaveTunesData',
    'GetVehicleHealthSummary',
    'UpdateVehicleMileage',
    'ApplyDegradation',
    'RepairVehicle',
    'GetHealthStatus'
}
