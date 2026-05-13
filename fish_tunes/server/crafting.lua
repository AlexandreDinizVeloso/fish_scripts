-- fish_tunes: Part Crafting Module
-- Allows players to craft vehicle parts with quality variance

PartCrafting = {}
local Config = {}

-- Crafting recipes
PartCrafting.Recipes = {
    racing_pistons = {
        label = 'Racing Pistons',
        description = 'High-performance forged pistons',
        category = 'engine',
        difficulty = 85,
        base_quality = 85,
        crafting_time = 300,  -- 5 minutes
        materials = {
            titanium = 5,
            steel = 10,
            rare_alloy = 2
        },
        output_stats = {
            acceleration = 20,
            top_speed = 15,
            engine_health_bonus = 5
        },
        success_rate_base = 75,
        cost = 5000
    },
    
    turbo_kit = {
        label = 'Performance Turbo Kit',
        description = 'Custom-built turbocharger system',
        category = 'turbo',
        difficulty = 90,
        base_quality = 80,
        crafting_time = 480,  -- 8 minutes
        materials = {
            aluminum = 8,
            steel = 15,
            precision_bearing = 4,
            seals = 10
        },
        output_stats = {
            acceleration = 40,
            top_speed = 25,
            turbo_health_bonus = 10
        },
        success_rate_base = 65,
        cost = 15000
    },
    
    suspension_kit = {
        label = 'Performance Suspension',
        description = 'Adjustable coilover suspension system',
        category = 'suspension',
        difficulty = 70,
        base_quality = 82,
        crafting_time = 240,  -- 4 minutes
        materials = {
            steel = 20,
            aluminum = 10,
            oil = 5,
            springs = 4
        },
        output_stats = {
            handling = 30,
            braking = 15,
            suspension_health_bonus = 8
        },
        success_rate_base = 80,
        cost = 8000
    },
    
    racing_brakes = {
        label = 'Racing Brake System',
        description = 'High-performance brake pads and rotors',
        category = 'brakes',
        difficulty = 75,
        base_quality = 88,
        crafting_time = 200,  -- 3.3 minutes
        materials = {
            steel = 12,
            ceramic = 8,
            brake_fluid = 5
        },
        output_stats = {
            braking = 35,
            handling = 10,
            brakes_health_bonus = 10
        },
        success_rate_base = 85,
        cost = 6000
    },
    
    weight_reduction = {
        label = 'Carbon Fiber Body Kit',
        description = 'Lightweight carbon fiber panels',
        category = 'weight',
        difficulty = 88,
        base_quality = 90,
        crafting_time = 360,  -- 6 minutes
        materials = {
            carbon_fiber = 15,
            epoxy_resin = 8,
            aluminum = 5
        },
        output_stats = {
            acceleration = 15,
            handling = 20,
            top_speed = 10
        },
        success_rate_base = 70,
        cost = 12000
    },
    
    ecu_tuning = {
        label = 'ECU Tuning Software',
        description = 'Custom engine management software',
        category = 'ecu',
        difficulty = 95,
        base_quality = 92,
        crafting_time = 120,  -- 2 minutes
        materials = {
            computer_chip = 2,
            rare_earth = 3,
            gold_plating = 1
        },
        output_stats = {
            acceleration = 25,
            top_speed = 20,
            power_gain = 10
        },
        success_rate_base = 60,
        cost = 10000
    },
    
    drift_tires = {
        label = 'Drift-Spec Tires',
        description = 'Low-grip tires optimized for drifting',
        category = 'tires',
        difficulty = 60,
        base_quality = 75,
        crafting_time = 180,
        materials = {
            rubber_compound = 20,
            silica = 10,
            reinforcement = 5
        },
        output_stats = {
            handling = 15,
            tires_health_bonus = 5
        },
        success_rate_base = 88,
        cost = 3000
    }
}

-- Initialize crafting module
function PartCrafting.Init(config)
    Config = config
end

-- Get recipe by name
function PartCrafting.GetRecipe(recipeName)
    return PartCrafting.Recipes[recipeName]
end

-- Get all available recipes
function PartCrafting.GetAllRecipes()
    local recipes = {}
    for name, recipe in pairs(PartCrafting.Recipes) do
        table.insert(recipes, {
            id = name,
            label = recipe.label,
            description = recipe.description,
            category = recipe.category,
            difficulty = recipe.difficulty,
            crafting_time = recipe.crafting_time,
            cost = recipe.cost
        })
    end
    
    table.sort(recipes, function(a, b) return a.difficulty < b.difficulty end)
    return recipes
end

-- Check if player has required materials
function PartCrafting.HasMaterials(playerInventory, materials)
    for material, required in pairs(materials) do
        if not playerInventory[material] or playerInventory[material] < required then
            return false, material, required
        end
    end
    return true
end

-- Calculate crafting success rate
function PartCrafting.CalculateSuccessRate(recipeName, playerSkill, qualityModifier)
    local recipe = PartCrafting.GetRecipe(recipeName)
    if not recipe then return 0 end
    
    -- Base success rate from recipe
    local baseRate = recipe.success_rate_base
    
    -- Player skill affects success (0-100)
    local skillBonus = (playerSkill or 50) * 0.3  -- Up to 30% bonus
    
    -- Quality modifier affects success
    local qualityPenalty = (100 - (qualityModifier or 50)) * 0.1  -- Up to 50% penalty
    
    local successRate = baseRate + skillBonus - qualityPenalty
    
    return math.max(20, math.min(100, successRate))
end

-- Calculate crafted part quality
function PartCrafting.CalculatePartQuality(recipeName, playerSkill, craftingQuality)
    local recipe = PartCrafting.GetRecipe(recipeName)
    if not recipe then return 50 end
    
    -- Base quality from recipe
    local quality = recipe.base_quality
    
    -- Player skill improves quality
    local skillBonus = (playerSkill or 50) * 0.2  -- Up to 20% bonus
    
    -- Crafting environment quality
    if craftingQuality then
        local qualityBonus = (craftingQuality / 100) * 10
        quality = quality + qualityBonus
    end
    
    -- Add some randomness (±10%)
    local variation = math.random(-10, 10)
    quality = quality + variation
    
    return math.max(40, math.min(100, quality))
end

-- Perform crafting
function PartCrafting.CraftPart(recipeName, playerSkill, craftingEnvironment)
    local recipe = PartCrafting.GetRecipe(recipeName)
    if not recipe then
        return false, 'Recipe not found'
    end
    
    -- Calculate success
    local successRate = PartCrafting.CalculateSuccessRate(
        recipeName,
        playerSkill,
        craftingEnvironment or 50
    )
    
    local random = math.random(0, 100)
    local success = random <= successRate
    
    if not success then
        return false, 'Crafting failed - materials wasted'
    end
    
    -- Calculate quality
    local quality = PartCrafting.CalculatePartQuality(
        recipeName,
        playerSkill,
        craftingEnvironment
    )
    
    -- Create crafted part data
    local craftedPart = {
        recipe = recipeName,
        label = recipe.label,
        quality = quality,
        stats = PartCrafting.CalculatePartStats(recipe, quality),
        crafted_at = os.time(),
        crafted_by_skill = playerSkill,
        durability = 100
    }
    
    return true, craftedPart, quality
end

-- Calculate actual part stats based on quality
function PartCrafting.CalculatePartStats(recipe, quality)
    local stats = {}
    
    if recipe.output_stats then
        local qualityMultiplier = quality / 100
        for stat, value in pairs(recipe.output_stats) do
            stats[stat] = math.floor(value * qualityMultiplier)
        end
    end
    
    return stats
end

-- Get crafting cost
function PartCrafting.GetCraftingCost(recipeName)
    local recipe = PartCrafting.GetRecipe(recipeName)
    if not recipe then return 0 end
    
    return recipe.cost
end

-- Get material cost
function PartCrafting.GetMaterialsCost(recipeName)
    local recipe = PartCrafting.GetRecipe(recipeName)
    if not recipe then return 0 end
    
    -- Cost per material unit (can be customized)
    local materialCosts = {
        titanium = 500,
        steel = 100,
        rare_alloy = 1000,
        aluminum = 150,
        precision_bearing = 800,
        seals = 50,
        oil = 100,
        springs = 200,
        ceramic = 300,
        brake_fluid = 80,
        carbon_fiber = 2000,
        epoxy_resin = 400,
        computer_chip = 5000,
        rare_earth = 2000,
        gold_plating = 1500,
        rubber_compound = 100,
        silica = 50,
        reinforcement = 200
    }
    
    local totalCost = 0
    for material, quantity in pairs(recipe.materials) do
        totalCost = totalCost + ((materialCosts[material] or 100) * quantity)
    end
    
    return totalCost
end

-- Get time to craft
function PartCrafting.GetCraftingTime(recipeName)
    local recipe = PartCrafting.GetRecipe(recipeName)
    if not recipe then return 0 end
    
    return recipe.crafting_time
end

-- Get recipe requirements
function PartCrafting.GetRecipeRequirements(recipeName)
    local recipe = PartCrafting.GetRecipe(recipeName)
    if not recipe then return nil end
    
    return {
        recipe = recipeName,
        label = recipe.label,
        difficulty = recipe.difficulty,
        crafting_time = recipe.crafting_time,
        materials = recipe.materials,
        success_rate = recipe.success_rate_base,
        cost = recipe.cost,
        material_cost = PartCrafting.GetMaterialsCost(recipeName)
    }
end

-- Get recipes by category
function PartCrafting.GetRecipesByCategory(category)
    local recipes = {}
    for name, recipe in pairs(PartCrafting.Recipes) do
        if recipe.category == category then
            table.insert(recipes, {
                id = name,
                label = recipe.label,
                description = recipe.description,
                difficulty = recipe.difficulty,
                base_quality = recipe.base_quality
            })
        end
    end
    
    return recipes
end

-- Apply crafted part to vehicle
function PartCrafting.InstallCraftedPart(vehicleData, craftedPart)
    if not vehicleData.installed_parts then
        vehicleData.installed_parts = {}
    end
    
    local category = PartCrafting.GetRecipe(craftedPart.recipe).category
    
    if not vehicleData.installed_parts[category] then
        vehicleData.installed_parts[category] = {}
    end
    
    table.insert(vehicleData.installed_parts[category], {
        label = craftedPart.label,
        quality = craftedPart.quality,
        stats = craftedPart.stats,
        installed_at = os.time(),
        durability = craftedPart.durability
    })
    
    return true
end

-- Get crafting difficulty explanation
function PartCrafting.GetDifficultyExplanation(difficulty)
    if difficulty < 40 then
        return 'Easy - Beginner friendly'
    elseif difficulty < 60 then
        return 'Moderate - Some experience needed'
    elseif difficulty < 80 then
        return 'Advanced - Experienced craftsmen'
    else
        return 'Expert - Master craftsmen only'
    end
end

-- Estimate crafting resources needed
function PartCrafting.EstimateCraftingCost(recipeName)
    local recipe = PartCrafting.GetRecipe(recipeName)
    if not recipe then return nil end
    
    local materialCost = PartCrafting.GetMaterialsCost(recipeName)
    local craftingCost = recipe.cost
    
    return {
        materials_cost = materialCost,
        crafting_cost = craftingCost,
        total_cost = materialCost + craftingCost,
        crafting_time = recipe.crafting_time,
        required_skill = recipe.difficulty
    }
end

return PartCrafting
