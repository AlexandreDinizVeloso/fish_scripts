fx_version 'cerulean'
game 'gta5'

name 'fish_telemetry'
description 'FISH Telemetry — Vehicle performance recording, multi-version analysis & G-force'
author 'Fish Vehicles'
version '2.0.0'

dependencies {
    'fish_normalizer'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

-- Server is minimal: just provides data endpoint if needed
-- server_scripts { 'server/main.lua' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js'
}

exports {
    'IsRecording'
}
