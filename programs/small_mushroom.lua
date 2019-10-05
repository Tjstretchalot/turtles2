--- A small mushroom farm that supports any mix of red and brown mushrooms.
-- Farm structure:
--   Place the turtle. From now on, everything is from the turtles perspective.
--   Right of the turtle is the fuel chest.
--   2 behind the fuel chest is the excess chest
--   2 above the fuel chest is the brown mushroom chest
--   2 above the excess chest is the red mushroom chest
--   5 blocks in front of the turtle are empty hallway spaces (2 tall)
--   In front of the last hallway space is the 10th from the left / 9th from
--   the right block of an 18x18 space, divided into 36 3x3 segments with a
--   mushroom at the center of each segment.
--   The place must be lit at light level 12 or below - i.e., 2 high ceilings, and
--   torches are recessed into the ceiling.

dofile('turtles2/utils/require.lua')
local farm_presets = require('utils/farm_presets')
local farm = require('utils/farm')
local startup = require('utils/startup')
local inv = require('utils/inv')

local function main()
    startup.inject('programs/small_mushroom.lua')

    local locs = {}
    local min_loc = vector.new(-8, 0, 6)
    for dx=0, 17, 1 do
        local start_z
        local end_z
        local del_z
        local x_even = (dx - math.floor(dx / 2) * 2) == 0
        local x_center = (dx - math.floor(dx / 3) * 3) == 1
        if x_even then
            start_z = 0
            end_z = 17
            del_z = 1
        else
            start_z = 17
            end_z = 0
            del_z = -1
        end

        for dz=start_z, end_z, del_z do
            local z_center = (dz - math.floor(dz / 3) * 3) == 1
            if (not x_center) or (not z_center) then
                locs[#locs + 1] = vector.new(min_loc.x + dx, 0, min_loc.z + dz)
            end
        end
    end

    farm.main(
        { -- seeds
            { -- mushrooms
                has_seed = false,
                checker = function(data)
                    return true
                end
            },
        },
        { -- farms
            { -- 18x18 mushrooms
                seed = 1,
                time_between_checks = 60, -- minutes
                locs = locs
            },
        },
        { -- specific chests
            { -- red mushroom
                pred = inv.new_pred_by_name('minecraft:red_mushroom'),
                loc = vector.new(-1, 2, -2)
            },
            { -- brown mushroom
                pred = inv.new_pred_by_name('minecraft:brown_mushroom'),
                loc = vector.new(-1, 2, 0)
            },
        },
        vector.new(-1, 0, 0), -- fuel chest
        vector.new(-1, 0, -2), -- excess chest
        farm_presets.union( -- world
            {
                farm_presets.world_rect( -- farm
                    vector.new(-8, 1, 6),
                    vector.new(9, 1, 23)),
                farm_presets.world_rect( -- hallway
                    vector.new(0, 0, -2),
                    vector.new(1, 1, 5)
                ),
                { -- left of mushroom chests
                    [tostring(vector.new(0, 2, 0))] = true,
                    [tostring(vector.new(0, 2, -2))] = true
                }
            }
        )
    )
end

main()