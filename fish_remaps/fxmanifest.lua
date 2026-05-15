fx_version 'cerulean'
game 'gta5'

name 'fish_remaps'
description 'Vehicle Remap System — DNA Inheritance & ECU Tuning'
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

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/nui.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

exports {
    'GetVehicleRemapData'
}

server_exports {
    'GetVehicleRemapDataServer'
}
