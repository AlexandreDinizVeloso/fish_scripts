Config = {}

-- Chip system
Config.ChipTypes = {
    v1 = {
        label = 'V1 - Legal Access',
        description = 'Grants access to the legal marketplace and community chat.',
        color = '#00d4ff',
        access = { 'marketplace_legal', 'chat' }
    },
    v2 = {
        label = 'V2 - Illegal Access',
        description = 'Grants access to the illegal marketplace, services, and underground channels.',
        color = '#ff3344',
        access = { 'marketplace_legal', 'marketplace_illegal', 'services', 'chat', 'chat_underground' }
    }
}

Config.MaxChipsPerTablet = 2

-- Chat
Config.ChatMaxMessages = 100

-- Marketplace
Config.MarketplaceMaxListings = 50
Config.ListingDuration = 604800 -- 7 days in seconds

-- Services
Config.ServiceTypes = {
    part_installation = {
        label = 'Part Installation',
        description = 'Professional installation of vehicle parts by certified mechanics.',
        icon = '🔧',
        requiresV2 = false
    },
    remap_service = {
        label = 'ECU Remap',
        description = 'Custom ECU tuning and performance remapping.',
        icon = '⚡',
        requiresV2 = true
    },
    part_delivery = {
        label = 'Part Delivery',
        description = 'Discreet delivery of parts to your location.',
        icon = '📦',
        requiresV2 = true
    }
}

-- HEAT system
Config.HEATRankingMax = 50

-- Chat channels
Config.ChatChannels = {
    general = {
        label = 'General',
        icon = '💬',
        requiresV2 = false
    },
    marketplace = {
        label = 'Marketplace',
        icon = '🏪',
        requiresV2 = false
    },
    underground = {
        label = 'Underground',
        icon = '🔒',
        requiresV2 = true
    }
}
