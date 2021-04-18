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

--- A 9x9 setup like SIMPLE, except only does alternating columns
-- starting at the edges. This is intended for melon/pumpkin style
-- farms.  Use "has_seed = false" and an always-true checker, and
-- have the seeds planted manually.
farm_presets.MELON_LIKE = {
    fuel_chest = farm_presets.SIMPLE.fuel_chest,
    excess_chest = farm_presets.SIMPLE.excess_chest,
    world = { -- we fill in 9x9 below programatically
        [tostring(vector.new(0, 0, 0))] = true,
        [tostring(vector.new(-2, 0, 0))] = true,
        [tostring(vector.new(2, 0, 0))] = true
    },
    farm = {}
}

local function _loc(x, z, dig_here)
    farm_presets.MELON_LIKE.world[tostring(vector.new(x, 0, z))] = true

    if dig_here then
        farm_presets.MELON_LIKE.farm[
            #farm_presets.MELON_LIKE.farm + 1] = vector.new(x, -1, z)
    end
end

-- the order for the farm part is important
for x=-4, 0, 4 do
    for z=1, 9, 1 do
        _loc(x, z, true)
        _loc(x + 1, z, false)
    end
    for z=9, 1, -1 do
        _loc(x + 2, z, true)
        _loc(x + 3, z, false)
    end
end
for z=1, 9, 1 do
    _loc(4, z, true)
end

--- Creates a rectangular prism world which has the given vectors
-- hollowed out
function farm_presets.world_rect(min_corner, max_corner)
    local res = {}
    for x=min_corner.x, max_corner.x do
        for y=min_corner.y, max_corner.y do
            for z=min_corner.z, max_corner.z do
                res[tostring(vector.new(x, y, z))] = true
            end
        end
    end
    return res
end

--- Returns a table with every vector in locs but offset the given
-- amount.
-- @param locs table array-like with each element as a vector
-- @param offset vector the amount to offset elements by
-- @return table array-like like locs with values offset
function farm_presets.offset_values(locs, offset)
    local res = {}
    for k, v in ipairs(locs) do
        res[k] = v + offset
    end
    return res
end

local function next_num(str, ind)
    local end_ind = ind
    while end_ind < #str and string.sub(str, end_ind + 1, end_ind + 1) ~= ',' do
        end_ind = end_ind + 1
    end
    return end_ind, tonumber(string.sub(str, ind, end_ind))
end

local function vecstr_to_vec(str)
    local ind, x = next_num(str, 1)
    local y
    ind, y = next_num(str, ind + 2)
    local z
    ind, z = next_num(str, ind + 2)
    return vector.new(x, y, z)
end

--- Returns a table where every key is offset by the given amount.
-- @param world table keys are tostring(vector) and values are true
-- @param offset vector the amount to offset the keys by
-- @return table a copy of world with keys offset
function farm_presets.offset_keys(world, offset)
    local res = {}
    for k, v in pairs(world) do
        local kvec = vecstr_to_vec(k)
        res[tostring(kvec + offset)] = true
    end
    return res
end

--- Unions two worlds.
-- @param worlds table a table of tables for worlds
-- @return table a new table with all the keys from both
function farm_presets.union(worlds)
    local res = {}
    for _, world in ipairs(worlds) do
        for k, v in pairs(world) do
            res[k] = v
        end
    end
    return res
end

return farm_presets
