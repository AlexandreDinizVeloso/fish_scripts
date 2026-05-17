-- ============================================================
-- fish_normalizer: Shared Database Module (oxmysql)
-- Sets a global FishDB table accessible by all server scripts.
-- Loaded BEFORE server/main.lua via fxmanifest order.
-- ============================================================

FishDB = {}
local DB = FishDB  -- local alias for this file's functions


-- ============================================================
-- Schema Migration
-- ============================================================

function DB.CreateTables()
    -- Core vehicle normalized data
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fish_vehicle_data` (
            `plate`                 VARCHAR(20) NOT NULL,
            `owner_identifier`      VARCHAR(100) DEFAULT NULL,
            `archetype`             VARCHAR(50) DEFAULT 'esportivo',
            `sub_archetype`         VARCHAR(50) DEFAULT NULL,
            `original_archetype`    VARCHAR(50) DEFAULT NULL,
            `score`                 INT DEFAULT 0,
            `rank`                  VARCHAR(5) DEFAULT 'C',
            `normalized`            TINYINT(1) DEFAULT 0,
            `engine_health`         FLOAT DEFAULT 100,
            `transmission_health`   FLOAT DEFAULT 100,
            `suspension_health`     FLOAT DEFAULT 100,
            `brakes_health`         FLOAT DEFAULT 100,
            `tires_health`          FLOAT DEFAULT 100,
            `turbo_health`          FLOAT DEFAULT 100,
            `mileage`               FLOAT DEFAULT 0,
            `total_driven_distance` FLOAT DEFAULT 0,
            `harsh_acceleration_events` INT DEFAULT 0,
            `overspeed_events`      INT DEFAULT 0,
            `rough_handling_events` INT DEFAULT 0,
            `tuning_efficiency`     FLOAT DEFAULT 100,
            `drivetrain_type`       VARCHAR(10) DEFAULT 'FWD',
            `transmission_mode`     VARCHAR(20) DEFAULT 'auto',
            `class_swapped`         TINYINT(1) DEFAULT 0,
            `created_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Remap / ECU / DNA data
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fish_vehicle_remaps` (
            `plate`                 VARCHAR(20) NOT NULL,
            `owner_identifier`      VARCHAR(100) DEFAULT NULL,
            `original_archetype`    VARCHAR(50) DEFAULT NULL,
            `current_archetype`     VARCHAR(50) DEFAULT NULL,
            `sub_archetype`         VARCHAR(50) DEFAULT NULL,
            `stat_adjustments`      JSON DEFAULT NULL,
            `final_stats`           JSON DEFAULT NULL,
            `dyno`                  JSON DEFAULT NULL,
            `gear_preset`           VARCHAR(20) DEFAULT 'stock',
            `trans_mode`            VARCHAR(20) DEFAULT 'auto',
            `stage`                 INT DEFAULT 0,
            `total_cost`            INT DEFAULT 0,
            `updated_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Tuning / parts / HEAT
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fish_vehicle_tunes` (
            `plate`                 VARCHAR(20) NOT NULL,
            `owner_identifier`      VARCHAR(100) DEFAULT NULL,
            `parts`                 JSON DEFAULT NULL,
            `drivetrain`            VARCHAR(10) DEFAULT 'FWD',
            `heat`                  INT DEFAULT 0,
            `heat_last_decay`       BIGINT DEFAULT 0,
            `updated_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Hub marketplace listings
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fish_hub_listings` (
            `id`                    INT AUTO_INCREMENT PRIMARY KEY,
            `seller_identifier`     VARCHAR(100) NOT NULL,
            `seller_name`           VARCHAR(100) DEFAULT 'Unknown',
            `type`                  ENUM('part','service','request') DEFAULT 'part',
            `category`              VARCHAR(50) DEFAULT NULL,
            `level`                 VARCHAR(10) DEFAULT NULL,
            `price`                 BIGINT DEFAULT 0,
            `description`           TEXT DEFAULT NULL,
            `is_illegal`            TINYINT(1) DEFAULT 0,
            `expires_at`            TIMESTAMP NULL DEFAULT NULL,
            `created_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_illegal` (`is_illegal`),
            INDEX `idx_expires` (`expires_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Ensure price column is BIGINT for existing tables
    pcall(function()
        MySQL.query.await('ALTER TABLE `fish_hub_listings` MODIFY COLUMN `price` BIGINT DEFAULT 0;')
    end)

    -- Ensure final_stats column exists in fish_vehicle_remaps
    pcall(function()
        MySQL.query.await('ALTER TABLE `fish_vehicle_remaps` ADD COLUMN `final_stats` JSON DEFAULT NULL;')
    end)

    -- Hub chat messages (global + private DMs)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fish_hub_messages` (
            `id`                    INT AUTO_INCREMENT PRIMARY KEY,
            `channel`               VARCHAR(100) DEFAULT 'global',
            `sender_identifier`     VARCHAR(100) NOT NULL,
            `sender_name`           VARCHAR(100) DEFAULT 'Unknown',
            `message`               TEXT NOT NULL,
            `sent_at`               TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_channel` (`channel`),
            INDEX `idx_sent_at` (`sent_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    print('[fish_db] All tables verified/created.')
end

-- ============================================================
-- fish_vehicle_data CRUD
-- ============================================================

function DB.GetVehicle(plate)
    if not plate or plate == '' then return nil end
    local result = MySQL.query.await('SELECT * FROM fish_vehicle_data WHERE plate = ?', {plate})
    if result and result[1] then
        local row = result[1]
        -- Deserialize any JSON fields if needed
        return row
    end
    return nil
end

function DB.SaveVehicle(plate, data, ownerIdentifier)
    if not plate or not data then return false end
    MySQL.query.await([[
        INSERT INTO fish_vehicle_data
            (plate, owner_identifier, archetype, sub_archetype, original_archetype,
             score, rank, normalized,
             engine_health, transmission_health, suspension_health,
             brakes_health, tires_health, turbo_health, mileage,
             total_driven_distance, harsh_acceleration_events,
             overspeed_events, rough_handling_events,
             tuning_efficiency, drivetrain_type, transmission_mode, class_swapped)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE
            owner_identifier = VALUES(owner_identifier),
            archetype = VALUES(archetype),
            sub_archetype = VALUES(sub_archetype),
            original_archetype = VALUES(original_archetype),
            score = VALUES(score),
            rank = VALUES(rank),
            normalized = VALUES(normalized),
            engine_health = VALUES(engine_health),
            transmission_health = VALUES(transmission_health),
            suspension_health = VALUES(suspension_health),
            brakes_health = VALUES(brakes_health),
            tires_health = VALUES(tires_health),
            turbo_health = VALUES(turbo_health),
            mileage = VALUES(mileage),
            total_driven_distance = VALUES(total_driven_distance),
            harsh_acceleration_events = VALUES(harsh_acceleration_events),
            overspeed_events = VALUES(overspeed_events),
            rough_handling_events = VALUES(rough_handling_events),
            tuning_efficiency = VALUES(tuning_efficiency),
            drivetrain_type = VALUES(drivetrain_type),
            transmission_mode = VALUES(transmission_mode),
            class_swapped = VALUES(class_swapped),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        plate,
        ownerIdentifier or data.owner_identifier or nil,
        data.archetype or 'esportivo',
        data.sub_archetype or nil,
        data.original_archetype or data.archetype or nil,
        data.score or 0,
        data.rank or 'C',
        data.normalized and 1 or 0,
        data.engine_health or 100,
        data.transmission_health or 100,
        data.suspension_health or 100,
        data.brakes_health or 100,
        data.tires_health or 100,
        data.turbo_health or 100,
        data.mileage or 0,
        data.total_driven_distance or 0,
        data.harsh_acceleration_events or 0,
        data.overspeed_events or 0,
        data.rough_handling_events or 0,
        data.tuning_efficiency or 100,
        data.drivetrain_type or 'FWD',
        data.transmission_mode or 'auto',
        data.class_swapped and 1 or 0
    })
    return true
end

function DB.GetVehiclesByOwner(ownerIdentifier)
    if not ownerIdentifier then return {} end
    local result = MySQL.query.await('SELECT * FROM fish_vehicle_data WHERE owner_identifier = ?', {ownerIdentifier})
    local map = {}
    if result then
        for _, row in ipairs(result) do
            map[row.plate] = row
        end
    end
    return map
end

function DB.GetAllVehicles()
    local result = MySQL.query.await('SELECT * FROM fish_vehicle_data', {})
    local map = {}
    if result then
        for _, row in ipairs(result) do
            map[row.plate] = row
        end
    end
    return map
end

-- ============================================================
-- fish_vehicle_remaps CRUD
-- ============================================================

function DB.GetRemap(plate)
    if not plate then return nil end
    local result = MySQL.query.await('SELECT * FROM fish_vehicle_remaps WHERE plate = ?', {plate})
    if result and result[1] then
        local row = result[1]
        if row.stat_adjustments and type(row.stat_adjustments) == 'string' then
            row.stat_adjustments = json.decode(row.stat_adjustments) or {}
        end
        if row.final_stats and type(row.final_stats) == 'string' then
            row.final_stats = json.decode(row.final_stats) or {}
        end
        if row.dyno and type(row.dyno) == 'string' then
            row.dyno = json.decode(row.dyno) or {}
        end
        return row
    end
    return nil
end

function DB.SaveRemap(plate, data, ownerIdentifier)
    if not plate or not data then return false end
    MySQL.query.await([[
        INSERT INTO fish_vehicle_remaps
            (plate, owner_identifier, original_archetype, current_archetype,
             sub_archetype, stat_adjustments, final_stats, dyno, gear_preset,
             trans_mode, stage, total_cost)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE
            owner_identifier = VALUES(owner_identifier),
            original_archetype = VALUES(original_archetype),
            current_archetype = VALUES(current_archetype),
            sub_archetype = VALUES(sub_archetype),
            stat_adjustments = VALUES(stat_adjustments),
            final_stats = VALUES(final_stats),
            dyno = VALUES(dyno),
            gear_preset = VALUES(gear_preset),
            trans_mode = VALUES(trans_mode),
            stage = VALUES(stage),
            total_cost = VALUES(total_cost),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        plate,
        ownerIdentifier or nil,
        data.original_archetype or nil,
        data.current_archetype or nil,
        data.sub_archetype or nil,
        json.encode(data.stat_adjustments or {}),
        json.encode(data.final_stats or data.finalStats or {}),
        json.encode(data.dyno or {}),
        data.gear_preset or 'stock',
        data.trans_mode or 'auto',
        data.stage or 0,
        data.total_cost or 0
    })
    return true
end

-- ============================================================
-- fish_vehicle_tunes CRUD
-- ============================================================

function DB.GetTunes(plate)
    if not plate then return nil end
    local result = MySQL.query.await('SELECT * FROM fish_vehicle_tunes WHERE plate = ?', {plate})
    if result and result[1] then
        local row = result[1]
        if row.parts and type(row.parts) == 'string' then
            row.parts = json.decode(row.parts) or {}
        end
        return row
    end
    return nil
end

function DB.SaveTunes(plate, data, ownerIdentifier)
    if not plate or not data then return false end
    MySQL.query.await([[
        INSERT INTO fish_vehicle_tunes
            (plate, owner_identifier, parts, drivetrain, heat, heat_last_decay)
        VALUES (?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE
            owner_identifier = VALUES(owner_identifier),
            parts = VALUES(parts),
            drivetrain = VALUES(drivetrain),
            heat = VALUES(heat),
            heat_last_decay = VALUES(heat_last_decay),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        plate,
        ownerIdentifier or nil,
        json.encode(data.parts or {}),
        data.drivetrain or 'FWD',
        data.heat or 0,
        data.heat_last_decay or os.time()
    })
    return true
end

-- ============================================================
-- Hub Listings CRUD
-- ============================================================

function DB.GetListings(isIllegal)
    local result = MySQL.query.await([[
        SELECT * FROM fish_hub_listings
        WHERE is_illegal = ? AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY created_at DESC
        LIMIT 50
    ]], {isIllegal and 1 or 0})
    return result or {}
end

function DB.CreateListing(data)
    local id = MySQL.insert.await([[
        INSERT INTO fish_hub_listings
            (seller_identifier, seller_name, type, category, level,
             price, description, is_illegal, expires_at)
        VALUES (?,?,?,?,?,?,?,?,DATE_ADD(NOW(), INTERVAL 7 DAY))
    ]], {
        data.seller_identifier,
        data.seller_name or 'Unknown',
        data.type or 'part',
        data.category or nil,
        data.level or nil,
        data.price or 0,
        data.description or '',
        data.is_illegal and 1 or 0
    })
    return id
end

function DB.DeleteListing(id, sellerIdentifier)
    MySQL.query.await('DELETE FROM fish_hub_listings WHERE id = ? AND seller_identifier = ?', {id, sellerIdentifier})
end

function DB.CleanExpiredListings()
    local affected = MySQL.query.await('DELETE FROM fish_hub_listings WHERE expires_at IS NOT NULL AND expires_at <= NOW()', {})
    if affected and affected.affectedRows and affected.affectedRows > 0 then
        print('[fish_hub] Cleaned ' .. affected.affectedRows .. ' expired listings.')
    end
end

-- ============================================================
-- Hub Messages CRUD
-- ============================================================

function DB.GetMessages(channel, limit)
    limit = limit or 50
    local result = MySQL.query.await([[
        SELECT * FROM fish_hub_messages
        WHERE channel = ?
        ORDER BY sent_at DESC
        LIMIT ?
    ]], {channel, limit})
    if result then
        -- Reverse to chronological order
        local reversed = {}
        for i = #result, 1, -1 do
            table.insert(reversed, result[i])
        end
        return reversed
    end
    return {}
end

function DB.SendMessage(channel, senderIdentifier, senderName, message)
    local id = MySQL.insert.await([[
        INSERT INTO fish_hub_messages (channel, sender_identifier, sender_name, message)
        VALUES (?,?,?,?)
    ]], {channel, senderIdentifier, senderName, message})
    return id
end

function DB.CleanOldMessages()
    -- Delete global/public messages older than 7 days
    local r1 = MySQL.query.await([[
        DELETE FROM fish_hub_messages
        WHERE channel NOT LIKE 'dm:%' AND sent_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]], {})
    -- Delete DMs older than 7 days too (user requested weekly cleanup)
    local r2 = MySQL.query.await([[
        DELETE FROM fish_hub_messages
        WHERE channel LIKE 'dm:%' AND sent_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]], {})
    local total = ((r1 and r1.affectedRows) or 0) + ((r2 and r2.affectedRows) or 0)
    if total > 0 then
        print('[fish_hub] Weekly cleanup: deleted ' .. total .. ' old messages.')
    end
end

-- FishDB is now a global — no return needed.
-- All server scripts in this resource (and dependents) access it directly.
