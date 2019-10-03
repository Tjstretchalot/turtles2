--- Contains some presets for working with farm based programs.

local farm_presets = {}

--- A 9x9 setup. Turtle starts above a fuel chest. Left of the fuel
-- chest is a space, followed by the excess chest. Right of the fuel
-- chest is a space, followed by a seeds chest. Below the fuel chest
-- and one forward (in dir of turtle) is the bottom-center block of
-- the 9x9; there are 4 dirt to the left/right, 3 dirt in front, water,
-- then 4 more dirt (filling a 9x9 with 1 water block.) Should be lit
-- around the edges and with one block 2 above the water block that
-- has torches on all edges. Turtle assumes the layer above the seeds
-- is pathable as well as above each chest.
farm_presets.SIMPLE = {
    fuel_chest = vector.new(0, -1, 0),
    seed_chest = vector.new(-2, -1, 0),
    excess_chest = vector.new(2, -1, 0),
    world = { -- we fill in 9x9 below programatically
        [tostring(vector.new(0, 0, 0))] = true,
        [tostring(vector.new(-2, 0, 0))] = true,
        [tostring(vector.new(2, 0, 0))] = true
    },
    farm = {} -- we fill in below programatically
}

local function _loc(x, z)
    farm_presets.SIMPLE.world[tostring(vector.new(x, 0, z))] = true
    farm_presets.SIMPLE.farm[
        #farm_presets.SIMPLE.farm + 1] = vector.new(x, -1, z)
end

-- the order for the farm part is important
for x=-4, 2, 2 do
    for z=1, 9, 1 do
        _loc(x, z)
    end
    for z=9, 1, -1 do
        _loc(x + 1, z)
    end
end
for z=1, 9, 1 do
    _loc(4, z)
end

return farm_presets