--- This is a very simple 9x9 wheat farm. Note that the turtle mostly idles as
-- there are many fewer seeds than the turtles capacity. This is meant to be
-- as easy introduction to using programs based on utils/farm
--
-- Setup works as follows:
--     See the README to download the repository to a disk.
--     Place turtle.
--     Beneath turtle, place a chest. This is the fuel chest. Put some coal
--     or charcoal in it.
--     Left of the fuel chest, skip a block then place a chest. The turtle
--     will deposit wheat and excess seeds here.
--     Right of the fuel chest, skip a block then place a chest. Put at least
--     80 seeds here.
--     In front and down of the fuel chest there should be a 4 consecutive dirt
--     blocks, then a water block, then 4 consecutive dirt blocks. Then, 4
--     columns of
--     9 dirt blocks on either side of the water. (making a 9x9 farm)
--     Light the place. Above all pieces of dirt, above all chests, and above
--     the water block there should be 2 empty spaces for the turtle to move.
--     Copy repository to the turtle (see README)
--     Give the turtle some initial fuel:
--       Place fuel (i.e. coal) in first slot
--       Enter the command "refuel all" in the turtle. The turtle fuel level
--       should be at least 10 to ensure initialization succeeds
--     RECOMMENDED: Setup GPS: http://www.computercraft.info/wiki/Gps_(program)
--       This is detected and used automatically for recovery if available
--     Run the program:
--       cd turtles2/
--       programs/wheat.lua
--     Ensure fuel chest is regularly refilled and wheat chest emptied

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