--- This module uses a redux-style store to handle exhaustively searching
-- neighboring tiles for resources. This process proceeds roughly as follows:
-- The 6 adjacent tiles are interesting.
-- For every interesting tile:
--   Check if it is *really* interesting (i.e., inspect passes some filter)
--   If it is, add all 6 adjacent tiles to the interesting list.
--
-- The stored state is as follows:
-- {
--   initialized = boolean
--      This starts as false. If this is true, that means we actually have
--      stored the 6 adjacent tiles already.
--   start = {x=number, y=number, z=number}
--      Where we began this process, and thus where we should end.
--      This is relative to home.
--   start_dir = number
--      Direction we started at, relative to home direction.
--   world_empty = table
--      The keys are tostring'd vectors, the values are "true"
--      These are tiles that we know are empty because we mined them already.
--      We will freely dig these tiles if there are obstructions, as they are
--      assumed to come from physics-enabled blocks or some other similar
--      phenomenon.
--
--      These values are relatively positioned to home.
--   interesting = table
--      This contains all the interesting tiles which we have not yet checked.
--
--      These values are relatively positioned to home.
--   current_dig = {x=number, y=number, z=number}|nil
--      If this is a location, it means we just inspected a location and
--      determined we should dig it, but haven't dug it yet.
--
--      This location is relatively positioned to home.
-- }

local paths = require('utils/paths')
local path_utils = require('utils/path_utils')
local constants = require('utils/constants')
local move_state = require('utils/move_state')
local state = require('utils/state')
local home = require('utils/home')

local ores = {}

--- Initializes the interesting locations to the 6 adjacent tiles
-- and marks the current location as empty.
ores.ACT_SET_START = 'ores_set_start'

--- Sets the result of the current inspection to either passing the
-- filter or not passing the filter. This removes the value from
-- the interesting table. If it passed the filter, it is set as
-- the current dig target and the 6 adjacent tiles are marked as
-- interesting.
ores.ACT_SET_INSPECT = 'ores_set_inspect'

--- Called when we successfully mined the block at current_dig. Adds
-- it to the world_empty table and clears current_dig.
ores.ACT_SET_DUG = 'ores_set_dug'

--- Uninitializes the ore context, clearing its store
ores.ACT_CLEAR = 'ores_clear'

--- Initializes the ores context to reflect that the given location
-- is empty and the 6 adjacent tiles are interesting.
-- @param start vector or vector-like table. Should be relative to home.
-- @param start_dir number the direction we started in
-- @return table the corresponding action
function ores.set_start(start, start_dir)
    return {
        type = ores.ACT_SET_START,
        start = {x = start.x, y = start.y, z = start.z},
        start_dir = start_dir
    }
end

--- A convenience function that uses the move_state in the store
-- to create teh action which sets the start to the current pos
-- and dir.
-- @param store the store which includes store.raw.move_state
-- @return the set_start action for the start is the current loc
function ores.set_start_to_cur(store)
    local abs_locv = vector.new(
        store.raw.move_state.position.x,
        store.raw.move_state.position.y,
        store.raw.move_state.position.z
    )
    local abs_dir = store.raw.move_state.dir
    local rel_locv, rel_dir = home.make_relative(abs_locv, abs_dir)
    return ores.set_start(rel_locv, rel_dir)
end

--- This action corresponds to updating the state to reflect that we have
-- looked at the given location.
-- @param loc_ind number the index in interesting that we checked
-- @param passed boolean if we passed the filter
-- @return table the corresponding action
function ores.set_inspect(loc_ind, passed)
    return {
        type = ores.ACT_SET_INSPECT,
        loc_ind = loc_ind,
        passed = passed
    }
end

--- This action corresponds to updating the state to reflect that we have dug
-- the current dig target.
-- @return table the corresponding action
function ores.set_dug()
    return { type = ores.ACT_SET_DUG }
end

--- This action corresponds to clearing the ores store and marking it uninitd
-- @return table the corresponding action
function ores.clear()
    return { type = ores.ACT_CLEAR }
end

--- Initializes the state that we need to exhaustively search a location.
-- This state will not include the filter we are searching on - that is
-- assumed to either be constant or stored elsewhere.
function ores.init()
    return {
        initialized = false,
        start = nil,
        start_dir = nil,
        world_empty = {},
        interesting = {},
        current_dig = nil
    }
end

--- The reducer for ores; (state, action) => state
function ores.reducer(raw, action)
    if action.type == ores.ACT_SET_START then
        local res = state.deep_copy(raw)
        res.initialized = true
        res.start = {x = action.start.x, y = action.start.y, z = action.start.z}
        res.start_dir = action.start_dir
        res.world_empty[
            tostring(vector.new(
                action.start.x, action.start.y, action.start.z))] = true
        for _, del in ipairs(constants.NEIGHBORS) do
            res.interesting[#res.interesting + 1] = vector.new(
                action.start.x + del.x,
                action.start.y + del.y,
                action.start.z + del.z
            )
        end
        return res
    elseif action.type == ores.ACT_SET_INSPECT then
        local res = state.deep_copy(raw)
        local loc = table.remove(res.interesting, action.loc_ind)
        if action.passed then
            res.current_dig = loc
            for _, del in ipairs(constants.NEIGHBORS) do
                local nhb = vector.new(
                    loc.x + del.x,
                    loc.y + del.y,
                    loc.z + del.z
                )
                if not res.world_empty[tostring(nhb)] then
                    res.interesting[#res.interesting + 1] = {
                        x = nhb.x, y = nhb.y, z = nhb.z }
                end
            end
        end
        return res
    elseif action.type == ores.ACT_SET_DUG then
        local res = state.deep_copy(raw)
        local loc = vector.new(
            res.current_dig.x, res.current_dig.y, res.current_dig.z)
        res.world_empty[tostring(loc)] = true
        res.current_dig = nil
        return res
    elseif action.type == ores.ACT_CLEAR then
        return ores.init()
    end
    return raw
end

-- The actionator for ores. Digging is the only one that could go here, but
-- it's just as easy to do so with an inspect-check in the main loop
ores.actionator = {}
-- The discriminators for ores. No states are ambiguous
ores.discriminators = {}

local function set_path(store, mem, data, rel_loc, rel_dir)
    path_utils.set_path(store, mem, rel_loc, data.world_empty, true, true)
end

local function select_next_target(store, mem, data)
    local abs_start = vector.new(
        store.raw.move_state.position.x,
        store.raw.move_state.position.y,
        store.raw.move_state.position.z)
    local abs_dir = store.raw.move_state.dir

    local rel_start, rel_dir = home.make_relative(abs_start, abs_dir)

    -- The true solution requires solving the traveling salesman problem.
    -- We will just greedily choose the next move as the shortest one.
    local best_arr = nil
    local best_dist = nil

    for i, loc in ipairs(data.interesting) do
        local locv = vector.new(loc.x, loc.y, loc.z)
        local manh = paths.manhattan(rel_start, locv)
        if best_dist == nil or manh < best_dist then
            best_arr = {i}
            best_dist = manh
            if best_dist <= 1 then break end
        elseif manh == best_dist then
            best_arr[#best_arr + 1] = i
        end
    end

    local best_path = nil
    local best_ind = nil

    for i, loc_ind in ipairs(best_arr) do
        local loc = data.interesting[loc_ind]
        local locv = vector.new(loc.x, loc.y, loc.z)
        local path = paths.determine_path(
            data.world_empty, true, rel_start, rel_dir,
            locv, nil, paths.manhattan, true
        )
        if best_path == nil or #path < #best_path then
            best_path = path
            best_ind = loc_ind
            if #best_path <= 1 then break end
        end
    end

    return best_ind, best_path
end

local function clear_mem(mem)
    mem.current_path = nil
    mem.current_path_ind = nil
    mem.current_loc_ind = nil
end

--- Continues performing what is necessary to complete the ores situation.
-- Returns true if there is more to do, false otherwise.
-- @param store state.Store the top-level store which we are using
-- @param mem table a transient memory store we can use. Can be cleared at any
-- time, but cannot be arbitrarily altered
-- @param key string the key within store.raw that gets to our raw state.
-- @param filter function accepts the result from a successful inspect and returns
-- true if it should be dug and false otherwise
function ores.tick(store, mem, key, filter)
    local data = store.raw[key]

    local on_home_trip = data.current_dig == nil and #data.interesting == 0
    if on_home_trip then
        if mem.current_path ~= nil then
            return path_utils.tick_path(store, mem, true, true)
        end

        local abs_pos = store.raw.move_state.position
        local abs_dir = store.raw.move_state.dir

        local abs_posv = vector.new(abs_pos.x, abs_pos.y, abs_pos.z)
        local rel_posv, rel_dir = home.make_relative(abs_posv, abs_dir)

        if (rel_posv.x ~= data.start.x
                or rel_posv.y ~= data.start.y
                or rel_posv.z ~= data.start.z
                or rel_dir ~= data.start_dir) then
            clear_mem(mem)

            mem.current_path = paths.determine_path(
                data.world_empty,
                true,
                rel_posv,
                rel_dir,
                vector.new(data.start.x, data.start.y, data.start.z),
                data.start_dir,
                paths.manhattan_consistent,
                true
            )
            mem.current_path_ind = 1
            return path_utils.tick_path(store, mem, true, true)
        end

        return false
    end

    if mem.current_path == nil then
        if data.current_dig ~= nil then
            set_path(store, mem, data, data.current_dig)
            path_utils.tick_path(store, mem, true)
            return true
        end

        local loc_ind, path = select_next_target(store, mem, data)
        mem.current_path = path
        mem.current_path_ind = 1
        mem.current_loc_ind = loc_ind
        path_utils.tick_path(store, mem, true)
        return true
    end

    if not path_utils.tick_path(store, mem, true) then
        local fn_ind = constants.MOVE_TO_FN_IND[
            mem.current_path[#mem.current_path]]

        if data.current_dig ~= nil then
            if (not turtle[constants.DETECT_FN[fn_ind]]()
                    or turtle[constants.DIG_FN[fn_ind]]()) then
                store:dispatch(ores.set_dug())
                clear_mem(mem)
            else
                textutils.slowPrint('failed to dig!')
                os.sleep(3)
            end

            return true
        end

        local loc_ind = mem.current_loc_ind
        local succ, insp_data = turtle[constants.INSPECT_FN[fn_ind]]()
        local passed = succ and filter(insp_data)
        clear_mem(mem)
        store:dispatch(ores.set_inspect(loc_ind, passed))
        return true
    end

    return true
end

return ores
