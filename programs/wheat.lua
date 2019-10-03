--- This is a very simple 9x9 wheat farm. See utils/farm_presets#SIMPLE for how
-- to set it up.

dofile('turtles2/utils/require.lua')
local farm_presets = require('utils/farm_presets')
local farm = require('utils/farm')
local startup = require('utils/startup')
local inv = require('utils/inv')

local function main()
    startup.inject('programs/wheat.lua')

    local preset = farm_presets.SIMPLE

    farm.main(
        { -- seeds
            { -- wheat
                has_seed = true,
                chest = preset.seed_chest,
                pred = inv.new_pred_by_name('minecraft:wheat_seeds'),
                checker = function(data)
                    return (
                        data.name ~= 'minecraft:wheat'
                        or data.metadata >= 7)
                end
            }
        },
        { -- farms
            { -- 9x9 wheat
                seed = 1,
                time_between_checks = 30, -- minutes
                locs = preset.farm
            }
        },
        { -- specific chests
            { -- seeds
                pred = inv.new_pred_by_name('minecraft:wheat_seeds'),
                loc = preset.seed_chest
            }
        },
        preset.fuel_chest,
        preset.excess_chest,
        preset.world
    )
end

main()