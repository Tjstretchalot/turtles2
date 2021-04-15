--- Some glue and utility functions that make working with paths a bit
-- easier.
local constants = require('utils/constants')
local paths = require('utils/paths')
local move_state = require('utils/move_state')
local home = require('utils/home')

local path_utils = {}


--- In a redux style system with transient memory, this sets the current
-- memory path (stored in mem.current_path) to one that goes to the given
-- destination (given in coordinates relative to home). If it fails to find
-- a path, it prints some debug information before returning.
--
-- @param store state.Store the redux-style store, containing at least the
-- move_state context which corresponds to move_state.
-- @param mem table an arbitrary table which we use to store variables which
-- can be recovered at any moment without meaningful loss
-- @param rdest vector the target destination we want to reach.
-- @param world table the keys should be tostring'd vectors and the values are
-- @param prevent_back boolean|nil if a boolean, determines if we should ask
-- paths not to use any back movements (so that we can dig obstructions
-- easily). if nil, defaults to true. Should be true unless you have a good
-- reason to believe you need back movements regularly.
--
-- @returns success boolean if true, mem.current_path is a list of moves (i.e.,
-- forward, up, down, back, turnLeft, turnRight) in the order they should be
-- made to end at the given destination. Furthermore, if true,
-- mem.current_path_ind is set to 1. Otherwise, if this returns false, then
-- mem.current_path and mem.current_path_ind are set to nil
function path_utils.set_path(store, mem, rdest, world, world_empty, prevent_back)
    if prevent_back == nil then prevent_back = true end
    local rstart, rdir = home.make_relative(
        vector.new(store.raw.move_state.position.x,
                   store.raw.move_state.position.y,
                   store.raw.move_state.position.z),
        store.raw.move_state.dir)
    mem.current_path = paths.determine_path(
        world,
        world_empty,
        rstart,
        rdir,
        rdest,
        nil,
        paths.manhattan_consistent,
        true -- prevent back to avoid getting stuck in leaves
    )
    if mem.current_path == nil then
        textutils.slowPrint('failed to find a path')
        textutils.slowPrint('rdest=' .. tostring(rdest))
        textutils.slowPrint('rstart=' .. tostring(rstart))
        textutils.slowPrint('failed to find a path between '
                            .. textutils.serialize(rstart)
                            .. ' and '
                            .. textutils.serialize(rdest))
        mem.current_path_ind = nil
        return false
    end
    mem.current_path_ind = 1
    return true
end

--- Continues moving along the path that was set with set_path. This will not
-- perform the final move, since typically you want to inspect/dig/etc for that
-- move.
-- @param store state.Store the store that can be used to dispatch move_state
-- actions for movement
-- @param mem table the transient memory which contains the current path
-- @param allow_dig boolean|nil true if we should dig unexpected obstructions,
-- false if we should just sleep. To prevent corruptions, the path must
-- have no back movements.
-- @param include_last boolean|nil true if we should perform the last move,
-- false or nil otherwise
-- @return true if theres more to do before last move, false otherwise
function path_utils.tick_path(store, mem, allow_dig, include_last)
    if allow_dig == nil then allow_dig = true end
    if include_last == nil then include_last = false end

    if mem.current_path == nil then
        error('tick_path with no path', 2)
    end

    if mem.current_path_ind > #mem.current_path then
        return false
    end

    if not include_last and mem.current_path_ind == #mem.current_path then
        return false
    end

    local nxt = mem.current_path[mem.current_path_ind]
    local fn_ind = constants.MOVE_TO_FN_IND[nxt]
    if fn_ind and turtle[constants.DETECT_FN[fn_ind]]() then
        if not allow_dig then
            textutils.slowPrint('Unexpected obstruction!')
            textutils.slowPrint('Sleeping a bit and trying again')
            os.sleep(30)
            return true
        elseif not turtle[constants.DIG_FN[fn_ind]]() then
            textutils.slowPrint('Failed to dig obstruction..')
            textutils.slowPrint('Sleeping a bit and trying again')
            os.sleep(30)
            return true
        end
    end

    nxt = move_state.FROM_TURTLE_ATTR[nxt]

    local act = move_state[nxt]()
    store:dispatch(act)
    mem.current_path_ind = mem.current_path_ind + 1

    if include_last then
        return mem.current_path_ind <= #mem.current_path
    end

    return mem.current_path_ind < #mem.current_path
end

return path_utils
