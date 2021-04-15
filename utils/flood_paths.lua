--- This module performs an undirected breadth-first search to a location
-- which passes a heuristic. This stops early if the depth exceeds a given
-- amount.
local constants = require('utils/constants')

local flood_paths = {}

-- These constants specify the format of the nodes
local IND_VECTOR = 1            -- Actual location vector "loc"
local IND_VECTOR_STR = 2        -- tostring(loc)
local IND_DIR = 3               -- Direction integer at node "dir"
local IND_VNDIR_STR = 4         -- tostring(loc) .. ':' .. tostring(dir)
local IND_CLOSED_IND = 5        -- Index of this node in closed
local IND_PARENT_IND = 6        -- Location in closed array for parent (number)
local IND_ACT_FROM_PARENT = 7   -- Action from parent to here (str)

--- Returns the path to the given node found by walking up the parent.
-- The result is a list of strings where each string is a name of an
-- attribute in turtle that can be performed, in the order that they
-- should be performed to go from start to end
local function unwind(closed, node)
    local result = {}

    while node[IND_PARENT_IND] ~= nil do
        result[#result + 1] = node[IND_ACT_FROM_PARENT]
        node = closed[node[IND_PARENT_IND]]
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

--- Finds the shortest path which takes us to any location + direction
-- combination which passes the end predicate. This is done with an
-- undirected flood search.
--
-- @param world table the keys are tostring locations and the values are true.
-- @param world_empty boolean True if the key/value pairs in world are empty,
-- false if they are filled. i.e., world["0,1,2"] = true and world_empty = true
-- means 0,1,2 is empty. If world["0,1,2"] = true and world_empty=false, then
-- 0,1,2 is filled.
-- @param start vector the start location
-- @param start_dir number the start direction
-- @param end_dir function(loc, dir) -> boolean determines if we have reached
-- a destination
-- @param prevent_back boolean true if back moves are disallowed, false
-- otherwise. Should be true unless you have a good reason to assume moves
-- will never be blocked.
-- @param max_depth number if we reach this depth we stop early. This is
-- the maximum number of moves from the start.
-- @return table|nil either something like {'forward', 'turnLeft', ...} or
-- nil if no path to any destination was found.
function flood_paths.determine_path(
        world, world_empty, start, start_dir, end_pred, prevent_back,
        max_depth)
    if end_pred(start, start_dir) then return {} end

    local start_str = tostring(start)
    local start_vndir = start_str .. ':' .. tostring(start_dir)

    local depth = 1
    local closed = {
        { start, start_str, start_dir, start_vndir, 1, nil, nil }
    }
    local seen_lookup = { [start_vndir] = true }
    local last = { closed[1] }
    local current = {}

    local function handle_neighbor(parent, vec, vecs, dir, action)
        if vecs == nil then vecs = tostring(vec) end

        local vndir_str = vecs .. ':' .. tostring(dir)
        if seen_lookup[vndir_str] then return false end

        if end_pred(vec, dir) then
            if action == 'back' then return false end
            local result = unwind(closed, parent)
            result[#result + 1] = action
            return result
        else
            local world_val = not not world[vecs]
            if world_val ~= world_empty then return false end
        end

        seen_lookup[vndir_str] = true
        local node = {
            vec, vecs, dir, vndir_str, #closed + 1, parent[IND_CLOSED_IND], action
        }
        closed[node[IND_CLOSED_IND]] = node
        current[#current + 1] = node
        return false
    end

    while depth <= max_depth do
        for _, cur in ipairs(last) do
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
        last = current
        current = {}
        depth = depth + 1
    end
end

return flood_paths
