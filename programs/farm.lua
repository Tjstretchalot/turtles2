--- Vertical 9x9 farms. Note that this will not automatically plant melon
-- or pumpkin layers. They should be planted in alternating columns (i.e,
-- in the same direction and location as the turtle starts, 3 to the right
-- is the first column, then 2 left is the next column, etc).
--
-- Farm layout:
--     Below the turtle is the fuel chest.
--     Look in the same direction as the turtle
--     Two blocks left of the fuel chest is the wheat chest.
--     Two blocks right of the fuel chest is the wheat seeds chest.
--     Two blocks behind fuel chest is the excess chest.
--     Two blocks left of excess chest is the carrot chest
--     Two blocks right of excess chest is the potato chest
--     Two blocks behind the excess chest is the beetroot seeds chest
--     Two blocks left of the beetroot seeds chest is the melon chest
--     Two blocks right of the beetroot seeds chest is the pumpkin chest
--     Two blocks right of the pumpkin chest is the beetroot chest
--     In front of the fuel chest is a torch.
--     1 in front, then 1 below, the torch is the bottom center
--     of a 9x9 tilled farm, lit the same was as programs/wheat. the
--     empty space in the farm (counting seeds as empty) is 3 tall,
--     the ceiling forms a 9x9 for another farm.
--     Same deal, 3 empty height, above it another farm. This may be
--     repeated any number of times.
--     The turtle moves between farms by going up/down above the fuel chest
--
-- This will generate "farm.config", which will have the following configuration
-- options (textutils.serialize style):
-- - layers [array(string)] (default {"wheat","carrot","potato"}). Describes the
--   type of farm for each layer, starting from the bottom of the farm and moving
--   upward. Valid values are:
--   + wheat
--   + carrot
--   + potato
--   + pumpkin : Plant Manually (see top)
--   + melon   : Plant Manually (see top)
--   + beetroot


package.path = '../?.lua;turtles2/?.lua'
local farm_presets = require('utils/farm_presets')
local farm = require('utils/farm')
local startup = require('utils/startup')
local inv = require('utils/inv')
local state = require('utils/state')

local FARM_TYPE_TO_SEED_INDEX = {
    wheat = 1,
    carrot = 2,
    potato = 3,
    pumpkin = 4,
    melon = 5,
    beetroot = 6
}

local DEFAULT_SETTINGS = {
    layers = { 'wheat', 'carrot', 'potato' }
}

local function load_settings()
    local filename = 'farm.config'
    local settings = state.deep_copy(DEFAULT_SETTINGS)

    local need_initialize = not fs.exists(filename)
    if not need_initialize then
        local h = fs.open(filename, 'r')
        local txt = h.readAll()
        h.close()

        local file_settings = textutils.unserialize(txt)
        for key, _ in pairs(DEFAULT_SETTINGS) do
            local val = file_settings[key]
            if val ~= nil then
                settings[key] = val
            end
        end
    end

    local h = fs.open(filename, 'w')
    h.write(textutils.serialize(settings))
    h.close()

    if need_initialize then
        textutils.slowPrint('initialized config to farm.config')
        error('check config')
        return
    end

    return settings
end

local function init_seeds(preset, settings)
    local function init_wheat()
        return {
            has_seed = true,
            chest = vector.new(-2, -1, 0),
            pred = inv.new_pred_by_name('minecraft:wheat_seeds'),
            checker = function(data)
                return (
                    data.name ~= 'minecraft:wheat'
                    or data.state.age >= 7)
            end
        }
    end

    local function init_carrots()
        return {
            has_seed = true,
            chest = vector.new(2, -1, -2),
            pred = inv.new_pred_by_name('minecraft:carrot'),
            checker = function(data)
                return (
                    data.name ~= 'minecraft:carrots'
                    or data.state.age >= 7)
            end
        }
    end

    local function init_potatoes()
        return {
            has_seed = true,
            chest = vector.new(-2, -1, -2),
            pred = inv.new_pred_by_name('minecraft:potato'),
            checker = function(data)
                return (
                    data.name ~= 'minecraft:potatoes'
                    or data.state.age >= 7)
            end
        }
    end

    local function init_pumpkin()
        return {
            has_seed = false,
            checker = function(data)
                return true
            end
        }
    end

    local function init_melon()
        return init_pumpkin()
    end

    local function init_beetroot()
        return {
            has_seed = true,
            chest = vector.new(0, -1, -4),
            pred = inv.new_pred_by_name('minecraft:beetroot_seeds'),
            checker = function(data)
                return (
                    data.name ~= 'minecraft:beetroots'
                    or data.state.age >= 3)
            end
        }
    end

    return {
        init_wheat(),
        init_carrots(),
        init_potatoes(),
        init_pumpkin(),
        init_melon(),
        init_beetroot(),
    }
end

local function init_farms(preset, settings)
    local function init_farm(seed, layer)
        return {
            seed = seed,
            time_between_checks = 30,
            locs = farm_presets.offset_values(preset.farm, vector.new(0, 4 * layer, 1))
        }
    end

    local res = {}
    for layer_index, farm_type in ipairs(settings.layers) do
        local seed_index = FARM_TYPE_TO_SEED_INDEX[farm_type]
        if not seed_index then
            textutils.slowPrint(string.format('invalid farm type: %s', farm_type))
            error('invalid farm type')
        end

        table.insert(res, init_farm(seed_index, layer_index))
    end
    return res
end

local function init_world(preset, settings)
    local arr = {}
    for layer=1, #settings.layers do
        local y = (layer-1) * 4
        table.insert(arr, farm_presets.world_rect(
            vector.new(-4, y, 2),
            vector.new(4, y, 10)
        ))
        table.insert(arr, {
            [tostring(vector.new(0, y, 1))] = true,
        })
    end
    table.insert(
        arr, farm_presets.world_rect( -- chests
            vector.new(-2, 0, -4),
            vector.new(2, 0, 0)
        )
    )
    table.insert(
        arr,
        farm_presets.world_rect( -- connection
            vector.new(0, 0, 0),
            vector.new(0, (#settings.layers - 1) * 4, 0)
        )
    )

    return farm_presets.union(arr)
end

local function main()
    startup.inject('programs/farm.lua')

    local preset = farm_presets.SIMPLE
    local settings = load_settings()

    farm.main(
        init_seeds(preset, settings),
        init_farms(preset, settings),
        { -- specific chests
            { -- seeds
                pred = inv.new_pred_by_name('minecraft:wheat_seeds'),
                loc = vector.new(-2, -1, 0)
            },
            { -- wheat
                pred = inv.new_pred_by_name('minecraft:wheat'),
                loc = vector.new(2, -1, 0)
            },
            { -- carrot
                pred = inv.new_pred_by_name('minecraft:carrot'),
                loc = vector.new(2, -1, -2)
            },
            { -- potato
                pred = inv.new_pred_by_name('minecraft:potato'),
                loc = vector.new(-2, -1, -2)
            }
        },
        vector.new(0, -1, 0), -- fuel chest
        vector.new(0, -1, -2), -- excess chest
        init_world(preset, settings)
    )
end

main()
