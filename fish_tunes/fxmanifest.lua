fx_version 'cerulean'
game 'gta5'

name 'fish_tunes'
description 'Vehicle Tuning System - Parts, Levels & HEAT'
author 'Fish Vehicles'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/nui.lua'
}

server_scripts {
    'server/main.lua',
    'server/data.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*'
}

dependencies {
    'fish_normalizer'
}

exports {
    'GetVehicleTunes',
    'GetInstalledParts',
    'GetVehicleHeat',
    'HasIllegalParts'
}

server_exports {
    'GetVehicleTunesServer',
    'SaveTunesData'
}
