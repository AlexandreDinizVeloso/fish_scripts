fx_version 'cerulean'
game 'gta5'

name 'fish_tunes'
description 'Vehicle Tuning System — Parts, Levels & HEAT'
author 'Fish Vehicles'
version '2.0.0'

dependencies {
    'oxmysql',
    'qbx_core',
    'fish_normalizer'
}

shared_scripts {
    'config.lua'
}

-- Client-side tuning logic
client_scripts {
    'client/main.lua',
    'client/dyno.lua',
    'client/drivetrain.lua',
    'client/tires.lua',
    'client/checkcar.lua',
    'client/engine_swap.lua'
}

-- Server: only our new consolidated main.lua
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

exports {
    'GetVehicleTunes',
    'GetInstalledParts',
    'GetVehicleHeat',
    'HasIllegalParts',
    'ApplyDynoTuning',
    'ApplyDrivetrainModifiers',
    'ApplyTireModifiers',
    'ClearDrivetrainCache',
    'ForceHandlingRefresh',
    'DegradeTires',
    'GetTireHealth',
    'SetTireHealth'
}

server_exports {
    'GetVehicleTunesServer',
    'GetHeatLevel',
    'GetHeatLeaderboard',
    'AddHeat'
}
