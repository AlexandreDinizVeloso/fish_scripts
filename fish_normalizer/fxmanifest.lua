fx_version 'cerulean'
game 'gta5'

name 'fish_normalizer'
description 'Vehicle Normalization System — Ranking & Archetype Assignment'
author 'Fish Vehicles'
version '2.0.0'

dependencies {
    'oxmysql',
    'qbx_core'
}

shared_scripts {
    'config.lua',
    'shared/handling.lua',
    'shared/lut_generator.lua' -- Pré-computação O(1) no heap compartilhado client+server
}

-- DB module: server-only
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/database.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/performance.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js'
}

exports {
    'GetVehicleRank',
    'GetVehicleArchetype',
    'GetVehicleScore',
    'GetVehicleData',
    'GetArchetypeModifier',
    'BuildHandlingProfile',
    'ApplyHandlingToVehicle',
    'GetBaseHandling',
    'GetRankFromScore',
    'ApplySubArchetypeBonuses',
    'GetActivePerformanceData'
}

server_exports {
    'GetVehicleRankServer',
    'GetVehicleDataServer',
    'SaveVehicleData',
    'GetAllNormalizedVehicles',
    'PushVehicleState'
}
