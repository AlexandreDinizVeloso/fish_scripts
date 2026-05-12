fx_version 'cerulean'
game 'gta5'

name 'fish_telemetry'
description 'FISH Telemetry - Vehicle performance recording and analysis system'
author 'FISH Development'
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
    'html/script.js'
}

exports {
    'GetTelemetryData',
    'IsRecording'
}
