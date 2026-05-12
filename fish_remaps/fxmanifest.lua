fx_version 'cerulean'
game 'gta5'

name 'fish_remaps'
description 'Vehicle Remap System - DNA Inheritance & Stat Tuning'
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
    'GetVehicleRemapData',
    'HasRemap',
    'GetDNAInheritance'
}

server_exports {
    'GetVehicleRemapDataServer',
    'SaveRemapData'
}
