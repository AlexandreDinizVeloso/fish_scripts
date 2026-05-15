fx_version 'cerulean'
game 'gta5'

name 'fish_hub'
description 'Fish Hub — Community, Marketplace, Chat & HEAT'
author 'Fish Vehicles'
version '2.0.0'

dependencies {
    'oxmysql',
    'qbx_core',
    'fish_normalizer',
    'fish_tunes',
    'fish_remaps'
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

server_exports {
    'GetHubListings'
}
