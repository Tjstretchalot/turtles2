---
-- This module allows for finding paths. It assumes that either the world is
-- mostly passable or mostly impassable for the type of storage for the 3d
-- grid.
local PQue = require('utils/pque')
local constants = require('utils/constants')

local paths = {}

--- Calculates the manhattan distance between two vectors. This is an
-- admissable heuristic, but is only consistent if turns cost nothing.
-- This is not a direction-sensitive heuristic.
-- @param v1 the first vector
-- @param v2 the second vector
-- @return the 1-norm of the difference
function paths.manhattan(v1, v2)
    local delta = v2 - v1
    return math.abs(delta.x) + math.abs(delta.y) + math.abs(delta.z)
end


--- Calculates the sign (0, 1, or -1) of the given number.
-- @param x number
-- @return number either 0, 1, or -1 which can be multiplied by x
-- to get a nonnegative number with the same absolute value.
local function sign(x)
    if x == 0 then return 0 end
    if x < 0 then return -1 end
    return 1
end

--- Determines if two vectors are equal
-- @param v1 the first vector
-- @param v2 the second vector
-- @return true if the components are the same, false otherwise
local function vec_eq(v1, v2)
    return v1.x == v2.x and v1.y == v2.y and v1.z == v2.z
end

--- Calculates the manhattan distance between two vectors and accounts for
-- time spent turning (treating it as a cost of 1). This is both admissable
-- and consistent, which will ensure optimal paths are found without heap
-- modification.
-- @param v1 the first vector
-- @param v2 the second vector
-- @param d1 the direction we start facing, in right turns from
-- @param d2 either nil or the direction we end facing
function paths.manhattan_consistent(v1, v2, d1, d2)
    local delta = v2 - v1
    local result = math.abs(delta.x) + math.abs(delta.y) + math.abs(delta.z)

    if delta.x ~= 0 and delta.z ~= 0 then
        -- We can always perform one of these directions without turning.
        -- We will have to turn for the other direction.
        result = result + 1

        -- However, we must end turned 1 from our start, so we may have to
        -- turn again. That is, if we care about our final direction
        -- (d2 ~= nil), we will have to turn if it's not a single turn from
        -- our current direction.
        if d2 ~= nil and constants.TURN_DISTANCES[d1][d2] ~= 1 then
            result = result + 1
        end
        -- If we are moving in both the x and z directions, we will always
        -- be able to do so going forward without additional moves, so there
        -- is no logic for d2 == nil
    elseif delta.x ~= 0 or delta.z ~= 0 then
        -- Possibilities:
        --   We are facing in the direction we want to move. Only need minimum
        --   turns to face in final direction.
        --
        --   We are facing an adjacent direction to where we want to move. Need
        --   exactly one turn to start which can put us at either forward/back
        --   movement. If the preferred direction is forward/backward this takes
        --   one turn, if it's adjacent this takes two turns
        --
        --   We are facing the opposite direction we want to move. If we have a
        --   final direction, we only need the minimum turns to face in that
        --   direction. Otherwise, we need to face forward.

        local key = tostring(sign(delta.x)) .. ',' .. tostring(sign(delta.z))
        local forward_dir = constants.DELTA_TO_DIR[key]
        local backward_dir = constants.BACK_DIRS[forward_dir]

        if d1 == forward_dir then
            if d2 ~= nil then
                result = result + constants.TURN_DISTANCES[d1][d2] -- adjust at end
            end
        elseif d1 == backward_dir then
            if d2 == nil then
                result = result + 2 -- face forward
            else
                result = result + constants.TURN_DISTANCES[d1][d2] -- adjust at end
            end
        else
            result = result + 1 -- turn forward/away
            if d2 ~= nil and constants.TURN_DISTANCES[d1][d2] ~= 1 then
                result = result + 1 -- adjust at end
            end
        end
    elseif d2 ~= nil then
        -- No movement in x/z means we only need to turn if a final
        -- direction is specified
        result = result + constants.TURN_DISTANCES[d1][d2]
    end
    return result
end

--- Calculates the euclidean distance between two vectors. This is an
-- admissable heuristic but is typically going to be slow and expand
-- nodes very aggressively.
-- This is not a direction-sensitive heuristic
-- @param v1 the first vector
-- @Param v2 the second vector
-- @return the 2-norm of the difference
function paths.euclidean(v1, v2)
    return (v2 - v1):length()
end

--- Uses the given base heuristic to create a new heuristic which is a static
-- weighting of the given heuristic, i.e, the resulting heuristic is a multiple
-- of the given heuristic. eps=1 gives just base_heur, and eps>1 corresponds to
-- allowing paths whose net cost is eps times the optimal cost. eps < 1 for
-- admissable heuristics results in pure-dijikstras.
function paths.static_weighted(base_heur, eps)
    local function heuristic(v1, v2, d1, d2)
        return base_heur(v1, v2, d1, d2) * eps
    end
    return heuristic
end


-- The indices for the elements in the open queue
local IND_VECTOR = 1            -- The location of the node
local IND_VECTOR_STR = 2        -- Location of tostring(v)
local IND_DIR = 3               -- Number right-turns from start
local IND_VNDIR_STR = 4         -- tostring(v):tostring(dir)
local IND_DIST_FROM_START = 5   -- Dist from start through parent
local IND_HEUR_TO_END = 6       -- Pred dist here to end
local IND_PARENT = 7            -- Current parent (nil for start)
local IND_ACT_FROM_PARENT = 8   -- Action from parent to here (str)

--- Finds a good path to the given move. Performs 3d A* using the
-- given heuristic (e.g., paths.manhattan). This does not check if we found
-- subsequent cheaper paths to a node, meaning that this will only find
-- optimal paths if the heuristic is admissable and consistent.
-- @param world table the keys are vectors (stringified). The values
-- are true. All missing keys are treated as false. These coordinates should
-- come from the assumption that we start acing north.
-- @param world_empty boolean true if the keys for which world[key] is true are
-- empty, false if the keys for which world[key] is true are filled/impassable.
-- @param start vector where the path starts at
-- @param start_dir direction where we are initially facing. This is treated
-- as sotuh (+z)
-- @param end_ vector where the path ends at
-- @param end_dir optional[direction] the final direction, or nil if it does
-- not matter / to ensure the last value in the result table is either
-- forward, up, or down and goes into the end block. Note that if end_dir
-- is not specified, it is guarranteed we do not back into the end block.
-- @param heuristic the heuristic function to use, which must be consistent
-- for optimal paths.
-- @param prevent_back if true, no back moves are made.
-- @return table contains strings where each string is a name of a
-- function in the turtle module to be performed from start to
-- end. Note that the end point is assumed to be empty regardless
-- of world. Returns nil if no path is possible
function paths.determine_path(world, world_empty, start, start_dir, end_,
                              end_dir, heuristic, prevent_back)
    prevent_back = not not prevent_back
    local open = PQue:new()
    local open_contains = {} -- keys are tostring(v) .. ':' .. tostring(reldir)
    local closed = {} -- keys are as above. really we could merge open_contains
    -- and closed, but a little harder to understand

    local start_node = {
        start,            -- VECTOR
        tostring(start),  -- VECTOR_STR
        start_dir,        -- DIR
        '',               -- VNDIR_STR, init below
        0,                -- DIST_FROM_START
        heuristic(start, end_, start_dir, end_dir), -- HEUR_TO_END
        nil,              -- PARENT
        nil,              -- ACT_FROM_PARENT
    }
    start_node[IND_VNDIR_STR] = (
        start_node[IND_VECTOR_STR] .. ':' .. tostring(start_node[IND_DIR]))
    open:insert(start_node, 0)
    open_contains[start_node[IND_VNDIR_STR]] = true

    --- Returns the path to the given node found by walking up the parent.
    -- The result is a list of strings where each string is a name of an
    -- attribute in turtle that can be performed, in the order that they
    -- should be performed to go from start to end
    local function unwind(node)
        local result = {}

        while node[IND_PARENT] ~= nil do
            result[#result + 1] = node[IND_ACT_FROM_PARENT]
            node = node[IND_PARENT]
        end

        -- reverse the list
        local i = 1
        local j = #result
        while i < j do
            local tmp = result[i]
            result[i] = result[j]
            result[j] = tmp
            i = i + 1
            j = j - 1
        end

        return result
    end

    local function handle_neighbor(parent, vec, vecs, dir, action)
        if vecs == nil then
            vecs = tostring(vec)
        end

        if vec_eq(vec, end_) then
            if end_dir == nil and action == 'back' then return false end
            if end_dir == nil or dir == end_dir then
                local result = unwind(parent)
                result[#result + 1] = action
                return result
            end
        else
            local world_val = not not world[vecs]
            if world_val ~= world_empty then return false end
        end

        local vndir_str = vecs .. ':' .. tostring(dir)
        if closed[vndir_str] then return false end
        if open_contains[vndir_str] then return false end

        local node = {
            vec,                                -- VECTOR
            vecs,                               -- VECTOR_STR
            dir,                                -- DIR
            vndir_str,                          -- VNDIR_STR
            parent[IND_DIST_FROM_START] + 1,    -- DIST_FROM_START
            heuristic(vec, end_, dir, end_dir), -- HEUR_TO_END
            parent,                             -- PARENT
            action,                             -- ACT_FROM_PARENT
        }

        open:insert(node, node[IND_DIST_FROM_START] + node[IND_HEUR_TO_END])
        open_contains[vndir_str] = true
        return false
    end

    while open:length() > 0 do
        local cur = open:pop()
        open_contains[cur[IND_VNDIR_STR]] = nil
        closed[cur[IND_VNDIR_STR]] = true

        -- forward
        local res = handle_neighbor(
            cur, cur[IND_VECTOR] + constants.DIR_TO_DELTA[cur[IND_DIR]], nil,
            cur[IND_DIR], 'forward'
        )
        if res then return res end

        -- left turn
        res = handle_neighbor(
            cur, cur[IND_VECTOR], cur[IND_VECTOR_STR],
            constants.LEFT_DIRS[cur[IND_DIR]], 'turnLeft')
        if res then return res end

        -- right turn
        res = handle_neighbor(
            cur, cur[IND_VECTOR], cur[IND_VECTOR_STR],
            constants.RIGHT_DIRS[cur[IND_DIR]], 'turnRight'
        )
        if res then return res end

        -- up
        res = handle_neighbor(
            cur, cur[IND_VECTOR] + constants.UP_DIR, nil, cur[IND_DIR], 'up'
        )
        if res then return res end

        -- down
        res = handle_neighbor(
            cur, cur[IND_VECTOR] + constants.DOWN_DIR, nil, cur[IND_DIR], 'down'
        )
        if res then return res end

        if not prevent_back then
            -- back
            res = handle_neighbor(
                cur, cur[IND_VECTOR] + constants.DIR_TO_DELTA[
                    constants.BACK_DIRS[cur[IND_DIR]]], nil,
                cur[IND_DIR], 'back'
            )
            if res then return res end
        end
    end

    return nil
end

return paths
