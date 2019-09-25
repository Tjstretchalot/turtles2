--- Capable of determine absolute direction using a GPS if a movement on the
-- x/z plane is found.
local constants = require('utils/constants')

local gps_locate = {}

--- Determines if we have enough fuel to perform the given number of movements.
-- @param moves number the amount of moves that you want to make
-- @return true if can make that many moves, false otherwise.
local function check_have_fuel(moves)
    local fuel = turtle.getFuelLevel()
    if fuel == 'unlimited' then return true end
    return fuel >= moves
end

--- Removes and returns the number in y which is closest in absolute value
-- to cur_y. Assumes the ys are integers and breaks ties arbitrarily.
-- @param ys table the table of ys to choose from
-- @param cur_y number the y value you want to be closest to
-- @return number the removed value from ys
local function pop_closest(ys, cur_y)
    if #ys <= 0 then error('pop_closest on empty list') end

    local best_dist = math.abs(ys[1] - cur_y)
    local best_ind = 1
    if best_dist == 0 then
        return table.remove(ys, 1)
    end

    for i=2, #ys do
        local dist = math.abs(ys[i] - cur_y)
        if dist < best_dist then
            if dist == 0 then
                return table.remove(ys, i)
            end

            best_dist = dist
            best_ind = i
        end
    end

    return table.remove(ys, best_ind)
end

--- Aggressively moves the given number of units in the y-direction.
-- This fails only if detectUp/detectDown verifies that the given move is
-- not possible. This process will not handle crashing very well, but thats
-- ok since we can presumably recover with a gps locate again. This immediately
-- fails if we leave gps range.
-- @param delta_y number the integer desired change in y
-- @return boolean,number if we succeeded and the actual change in y
local function move_updown(delta_y)
    if delta_y == 0 then return true, 0 end

    local move_fn
    local detect_fn
    local sign

    if delta_y < 0 then
        move_fn = turtle.down
        detect_fn = turtle.detectDown
        sign = -1
    else
        move_fn = turtle.up
        detect_fn = turtle.detectUp
        sign = 1
    end

    local mvs = 0
    while mvs < math.abs(delta_y) do
        if detect_fn() then
            return false, mvs * sign
        end

        while not move_fn() do
            os.sleep(1)
        end
        mvs = mvs + 1

        local x, y, z = gps.locate()
        if not x then
            return false, mvs * sign
        end
    end
    return true, mvs * sign
end

--- Checks the 4 tiles in the x/z plane to see if any of them are empty. If it
-- finds one, the first result is true, otherwise it will be false.
-- @param rel_dir the current relative direction
-- @return boolean, number success, the new relative direction
local function check_for_adjacent_xz(rel_dir)
    if not turtle.detect() then return true, rel_dir end

    for i=1, 3 do
        while not turtle.turnRight() do
            -- this implies event queue is full, waiting will definitely work
            os.sleep(1)
        end
        rel_dir = constants.RIGHT_DIRS[rel_dir]
        if not turtle.detect() then return true, rel_dir end
    end
    return false, rel_dir
end

--- Finds the absolute location and directon if possible to do so, otherwise
-- returns nil, nil. This works by searching for a movement on the x/z
-- direction through an exhaustive y search, ensuring that there is enough
-- fuel to return to the start. This ends where it started.
-- @return vector, number the location and direction we are at.
function gps_locate.locate()
    local x, y, z = gps.locate()
    if not x then return nil, nil end

    local open_ys = {0}
    local cur_y = 0
    local cur_rel_dir = 0
    local found_xz = false

    while #open_ys > 0 do
        local to_check = pop_closest(open_ys, cur_y)
        local fuel_to_check = math.abs(cur_y - to_check)
        local fuel_to_home = math.abs(to_check)
        if not check_have_fuel(fuel_to_check + fuel_to_home + 2) then
            break
        end

        local succ, del_y = move_updown(to_check - cur_y)
        cur_y = cur_y + del_y
        if not succ then break end

        succ, cur_rel_dir = check_for_adjacent_xz(cur_rel_dir)
        if succ then
            found_xz = true
            break
        end
    end

    if found_xz then
        x, y, z = gps.locate()
        if x then
            while not turtle.forward() do os.sleep(1) end
            local nx, ny, nz = gps.locate()
            while not turtle.back() do os.sleep(1) end
            if nx then
                local dx = nx - x
                local dz = nz - z
                local ds = tostring(dx) .. ',' .. tostring(dz)
                local dir = constants.DELTA_TO_DIR[ds]
                if dir then
                    local succ, del_y = move_updown(-cur_y)
                    while cur_rel_dir ~= 0 do
                        while not turtle.turnRight() do os.sleep(1) end
                        cur_rel_dir = constants.RIGHT_DIRS[cur_rel_dir]
                        dir = constants.RIGHT_DIRS[dir]
                    end
                    return vector.new(x, y + del_y, z), dir
                end
            end
        end
    end

    local succ, del_y = move_updown(-cur_y)
    cur_y = cur_y + del_y
    if cur_y ~= 0 then error('failed to return to start') end

    while cur_rel_dir ~= 0 do
        while not turtle.turnRight() do os.sleep(1) end
        cur_rel_dir = constants.RIGHT_DIRS[cur_rel_dir]
    end
    return nil, nil
end

return gps_locate
