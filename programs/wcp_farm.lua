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


package.path = '../?.lua;turtles2/?.lua'
local farm_presets = require('utils/farm_presets')
local farm = require('utils/farm')
local startup = require('utils/startup')
local inv = require('utils/inv')

local function main()
    startup.inject('programs/wcp_farm.lua')

    local preset = farm_presets.SIMPLE

    farm.main(
        { -- seeds
            { -- wheat
                has_seed = true,
                chest = vector.new(-2, -1, 0),
                pred = inv.new_pred_by_name('minecraft:wheat_seeds'),
                checker = function(data)
                    return (
                        data.name ~= 'minecraft:wheat'
                        or data.metadata >= 7)
                end
            },
            { -- carrot
                has_seed = true,
                chest = vector.new(2, -1, -2),
                pred = inv.new_pred_by_name('minecraft:carrot'),
                checker = function(data)
                    return (
                        data.name ~= 'minecraft:carrots'
                        or data.metadata >= 7)
                end
            },
            { -- potato
                has_seed = true,
                chest = vector.new(-2, -1, -2),
                pred = inv.new_pred_by_name('minecraft:potato'),
                checker = function(data)
                    return (
                        data.name ~= 'minecraft:potatoes'
                        or data.metadata >= 7)
                end
            }
        },
        { -- farms
            { -- 9x9 wheat
                seed = 1,
                time_between_checks = 30, -- minutes
                locs = farm_presets.offset_values(preset.farm, vector.new(0, 0, 1))
            },
            { -- 9x9 carrots
                seed = 2,
                time_between_checks = 30, -- minutes
                locs = farm_presets.offset_values(preset.farm, vector.new(0, 4, 1))
            },
            { -- 9x9 potatoes
                seed = 3,
                time_between_checks = 30, -- minutes
                locs = farm_presets.offset_values(preset.farm, vector.new(0, 8, 1))
            }
        },
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
        farm_presets.union( -- world
            {
                farm_presets.world_rect( -- wheat
                    vector.new(-4, 0, 2),
                    vector.new(4, 0, 10)),
                farm_presets.world_rect( -- carrots
                    vector.new(-4, 4, 2),
                    vector.new(4, 4, 10)),
                farm_presets.world_rect( -- potatoes
                    vector.new(-4, 8, 2),
                    vector.new(4, 8, 10)),
                farm_presets.world_rect( -- chests
                    vector.new(-2, 0, -2),
                    vector.new(2, 0, 0)
                ),
                farm_presets.world_rect( -- connection
                    vector.new(0, 0, 0),
                    vector.new(0, 8, 0)
                ),
                { -- extra connecting blocks
                    [tostring(vector.new(0, 0, 1))] = true,
                    [tostring(vector.new(0, 4, 1))] = true,
                    [tostring(vector.new(0, 8, 1))] = true
                }
            }
        )
    )
end

main()
