--- Wheat carrot potato farm, 3 vertical 9x9s.
-- Farm layout:
--     Below the turtle is the fuel chest.
--     Look in the same direction as the turtle
--     Two blocks left of the fuel chest is the wheat chest.
--     Two blocks right of the fuel chest is the wheat seeds chest.
--     Two blocks behind fuel chest is the excess chest.
--     Two blocks left of excess chest is the carrot chest
--     Two blocks right of excess chest is the potato chest
--     In front of the fuel chest is a torch.
--     1 in front, then 1 below, the torch is the bottom center
--     of a 9x9 wheat farm, lit the same was as programs/wheat. the
--     empty space in the farm (counting seeds as empty) is 3 tall,
--     the ceiling forms a 9x9 for the carrot farm.
--     Same deal, 3 empty height (including seed) for carrot farm, above it is
--     the potato farm
--     The turtle moves between farms by going up/down above the fuel chest
--
-- This will generate "farm.config", which will have the following configuration
-- options (textutils.serialize style):
-- - count [number] (default 1): Must be a positive integer. If higher than one,
--   then this assumes theres that many wheat, carrot, and potato farms. FOr example,
--   if count is 2, then there are 6 9x9 farms (wheat, carrot, potato, wheat, carrot,
--   potato). Does not change the chest layout.


package.path = '../?.lua;turtles2/?.lua'
local farm_presets = require('utils/farm_presets')
local farm = require('utils/farm')
local startup = require('utils/startup')
local inv = require('utils/inv')
local state = require('utils/state')

local DEFAULT_SETTINGS = {
    count = 1,
}

local function load_settings()
    local filename = 'farm.config'
    local settings = state.deep_copy(DEFAULT_SETTINGS)

    if fs.exists(filename) then
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

    return {
        init_wheat(),
        init_carrots(),
        init_potatoes()
    }
end

local function init_farms(preset, settings)
    local function init_farm(seed, layer)
        return {
            seed = seed,
            time_between_checks = 30,
            farm_presets.offset_values(preset.farm, vector.new(0, 4 * layer, 1))
        }
    end

    local nseeds = 3
    local res = {}
    for i = 1, settings.count do
        for j = 1, nseeds do
            res.append(init_farm(j, (i - 1) * nseeds + j - 1))
        end
    end
    return res
end

local function init_world(preset, settings)
    local arr = {}
    for layer=1, settings.count * 3 do
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
            vector.new(-2, 0, -2),
            vector.new(2, 0, 0)
        )
    )
    table.insert(
        arr,
        farm_presets.world_rect( -- connection
            vector.new(0, 0, 0),
            vector.new(0, ((settings.count * 3) - 1) * 4, 0)
        )
    )

    return farm_presets.union(arr)
end

local function main()
    startup.inject('programs/wcp_farm.lua')

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
