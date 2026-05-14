Config = {}

-- Chip system
Config.ChipTypes = {
    v1 = {
        label = 'V1 - Legal Access',
        description = 'Grants access to marketplace contact, services, and chat.',
        color = '#00d4ff'
    },
    v2 = {
        label = 'V2 - Illegal Access',
        description = 'Grants access to illegal listings, underground channels, and all services.',
        color = '#ff3344'
    }
}

Config.MaxChipsPerTablet = 2

-- Chat
Config.ChatMaxMessages = 200

-- Marketplace
Config.MarketplaceMaxListings = 50
Config.ListingDuration = 604800 -- 7 days in seconds

-- Services
Config.ServiceTypes = {
    part_installation = {
        label = 'Part Installation',
        description = 'Professional installation of vehicle parts by certified mechanics.',
        icon = '🔧',
        requiresV1 = false
    },
    remap_service = {
        label = 'Remap Maker',
        description = 'Custom ECU tuning and performance remapping.',
        icon = '⚡',
        requiresV1 = true
    },
    part_delivery = {
        label = 'Part Delivery',
        description = 'Discreet delivery of parts to your location.',
        icon = '📦',
        requiresV1 = true
    }
}

-- HEAT system
Config.HEATRankingMax = 5
