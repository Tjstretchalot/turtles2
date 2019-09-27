---
-- This module allows for exhaustively searching the local area for
-- a particular set of ores.  This is intuitively a recursive process;
-- check all 6 directions around the turtle for matching blocks. When
-- one is found, mine it, move to it, repeat the process, then move back.
--
-- In case inventory fills up or there is insufficient fuel, this is
-- handled as an iterative process which can be interrupted. The
-- interruption will undo moves as to return toward to the starting
-- point, and then can be resumed from the starting point.
--
-- This also is recoverable whenever either gps is available. If fuel is
-- consumed, this can be used in some cases instead of the gps. For turns it
-- is ambiguous without the gps unless exploiting the fact that computercraft
-- doesn't yield on turns and hence it's much more likely we completed the move
-- than we did not. This will assume that commands completed where we have
-- exhausted all ways of testing.

local paths = require('utils/paths')
local gps_locate = require('utils/gps_locate')
local constants = require('utils/constants')

local ores = {}

---
-- The context which is stored while mining ores, which can be used to
-- interrupt the process / return to the start.
--
-- Instance Variables
-- filen string the path to the file that is used for recovery. Also uses
-- additional suffixes for filen for recovery.
--
-- empty_tiles table the known traversable tiles nearby. The key
-- for a vector v is tostring(v). The value is always true. All
-- locations which are not in this table should be treated as
-- filled. The coordinates are done treating our original direction
-- as south (+z), which corresponds to 0 in the F3 menu.
--
-- handled table the tiles which we have already handled. The keys are the
-- tostring'd vectors. The values are true.
--
-- cur_rel_loc vector contains the offset from the start
--
-- cur_rel_dir int contains the number of right turns that we have made
-- relative to the starting direction, modulus 4. In other words, we
-- can return to the starting direction by turning left until this is
-- 0 or right until this is 4. We treat the starting direction as
-- south (positive z) regardless of ground truth; it doesn't actually
-- matter as long as we are consistent
--
-- to_inspect table acts as the stack. contains the inspections which
-- have to be done in order to complete this operation. Each element is a
-- vector for the relative location that needs to be checked.
--
-- fuel int|string the amount of fuel remaining, or the string 'unlimited'.
-- this can be used to collapse some possible states if it is not unlimited
--
-- next_action string the action that we are about to perform. This is
-- set, the file is copied to .. '.bak', the action is performed,
-- we touch .. '.post', we delete the original,
-- we serialize to the original, we delete .bak, then we delete .post.
--
-- current_node vector the current node we are trying to inspect. if this is
-- set without the unserialized counterparts, we should check it even if it
-- is empty as we may have restarted after a dig but before a move. if this
-- is set then current_dig should be nil
--
-- current_dig vector the node that we are currently trying to dig. if this
-- is set than current_node should be nil.
--
-- _current_path table this is omitted from serialization/deserialization
-- since it is not required for recovery. contains the path to the current
-- node
--
-- _current_path_ind int the index in _current_path for the next action to take
--
-- @type OreContext
local OreContext = {}

local function _deepcp(x)
    return textutils.unserialize(textutils.serialize(x))
end

--- Initializes a new empty ore context. This should be considered
-- a private constructor.
function OreContext:_init()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end


--- Creates a new ore context, initialized with recursing along all 6 adjacent
-- blocks, which uses the given file for recovery. This will also use other
-- suffixes for filen (use OreContext.clean(filen) to delete all). This
-- requires a clean state.
function OreContext:new(filen)
    local o = OreContext:_init()
    o.filen = filen
    o.empty_tiles = {[tostring(vector.new(0, 0, 0))] = true}
    o.handled = {[tostring(vector.new(0, 0, 0))] = true}
    o.cur_rel_loc = vector.new(0, 0, 0)
    o.cur_rel_dir = 0
    o.fuel = turtle.getFuelLevel()
    o.to_inspect = {}
    for i, v in ipairs(constants.NEIGHBORS) do
        o.to_inspect[i] = vector.new(v.x, v.y, v.z)
        o.handled[tostring(v)] = true
    end
    o.next_action = nil
    o.current_node = nil
    o.current_dig = nil
    o._current_path = nil
    o._current_path_ind = nil
    return o
end

--- Inspects the current node using the given inspect function. This only updates
-- the internal state of the turtle. Afterward, clean and save should be called.
-- After this is done, the hidden variables associated with current_node are
-- cleared, but the current node is left if we should dig it (and cleared
-- otherwise). This means that if current_node is set but not hidden nodes, we
-- should both treat empty as passing the filter and just go straight to
-- digging if it does pass the filter.
-- @param act string either inspect, inspectUp, or inspectDown
-- @param filter function determines if we should mine the block. passed the
-- table result from the inspect function if it is succesful, unused otherwise
function OreContext:_inspect_with(act, filter)
    self._current_path = nil
    self._current_path_ind = nil
    local succ, inf = turtle[act]()
    if not succ then
        self.empty_tiles[tostring(self.current_node)] = true
    elseif filter(inf) then
        self.current_dig = self.current_node
        for i, n in ipairs(constants.NEIGHBORS) do
            local neighbor = self.current_node + n
            local neighbor_s = tostring(neighbor)
            if not self.handled[neighbor_s] then
                self.handled[neighbor_s] = true
                self.to_inspect[#self.to_inspect + 1] = neighbor
            end
        end
    end
    self.current_node = nil
end

--- Creates a deep copy of this ore context.
function OreContext:deep_copy()
    local res = OreContext:_init()
    res.filen = self.filen
    res.empty_tiles = {}
    for k, v in pairs(self.empty_tiles) do
        res.empty_tiles[k] = v
    end
    res.handled = {}
    for k, v in pairs(self.handled) do
        res.handled[k] = v
    end
    res.cur_rel_loc = vector.new(
        self.cur_rel_loc.x, self.cur_rel_loc.y, self.cur_rel_loc.z)
    res.cur_rel_dir = self.cur_rel_dir
    res.fuel = self.fuel
    res.to_inspect = {}
    for k, v in ipairs(self.to_inspect) do
        res.to_inspect[k] = v
    end
    res.next_action = self.next_action
    if self.current_node ~= nil then
        res.current_node = vector.new(
            self.current_node.x, self.current_node.y, self.current_node.z)
    end
    if self.current_dig ~= nil then
        res.current_dig = vector.new(
            self.current_dig.x, self.current_dig.y, self.current_dig.z)
    end
    if self._current_path ~= nil then
        res._current_path = {}
        for i, v in ipairs(self._current_path) do
            res._current_path[i] = v
        end
        res._current_path_ind = self._current_path_ind
    end
    return res
end

--- Creates the ore context that we will be in after completing this move.
-- This is a deep copy. This ignores unserialized values.
-- @return OreContext the next ore context.
function OreContext:_post()
    if self.next_action == nil then
        return self:deep_copy()
    elseif self.next_action == 'turnLeft' then
        local res = self:deep_copy()
        res.next_action = nil
        res.cur_rel_dir = constants.LEFT_DIRS[self.cur_rel_dir]
        return res
    elseif self.next_action == 'turnRight' then
        local res = self:deep_copy()
        res.next_action = nil
        res.cur_rel_dir = constants.RIGHT_DIRS[self.cur_rel_dir]
        return res
    elseif self.next_action == 'forward' then
        local res = self:deep_copy()
        res.next_action = nil
        res.cur_rel_loc = (
            self.cur_rel_loc + constants.DIR_TO_DELTA[self.cur_rel_dir])
        if self.fuel ~= 'unlimited' then
            res.fuel = self.fuel - 1
        end
        return res
    elseif self.next_action == 'up' then
        local res = self:deep_copy()
        res.next_action = nil
        res.cur_rel_loc = self.cur_rel_loc + constants.UP_DIR
        if self.fuel ~= 'unlimited' then
            res.fuel = self.fuel - 1
        end
        return res
    elseif self.next_action == 'down' then
        local res = self:deep_copy()
        res.next_action = nil
        res.cur_rel_loc = self.cur_rel_loc + constants.DOWN_DIR
        if self.fuel ~= 'unlimited' then
            res.fuel = self.fuel - 1
        end
        return res
    elseif self.next_action == 'back' then
        local res = self:deep_copy()
        local back_dir = constants.BACK_DIRS[self.cur_rel_dir]
        local delta = constants.DIR_TO_DELTA[back_dir]
        res.next_action = nil
        res.cur_rel_loc = self.cur_rel_loc + delta
        if self.fuel ~= 'unlimited' then
            res.fuel = self.fuel - 1
        end
        return res
    end
    error('unknown action: ' .. tostring(self.next_action))
end

--- Serializes this ore context to the given file.
-- @param filen string the file to serialize to
function OreContext:_serialize(filen)
    local raw = {
        filen = self.filen,
        empty_tiles = self.empty_tiles,
        handled = self.handled,
        cur_rel_loc = self.cur_rel_loc,
        cur_rel_dir = self.cur_rel_dir,
        fuel = self.fuel,
        to_inspect = self.to_inspect,
        next_action = self.next_action,
        current_node = self.current_node,
        current_dig = self.current_dig
    }
    local serd = textutils.serialize(raw)

    local h = fs.open(filen, 'w')
    h.write(serd)
    h.close()
end

--- Deserializes the ore context in the given file
-- @param filen string the file to deserialize
-- @return success, context Success is false if the file is corrupted or not
-- existing. If success is false, context is nil. Otherwise, success is true
-- and context is an OreContext
function OreContext:_deserialize(filen)
    if not fs.exists(filen) then return false, nil end

    local h = fs.open(filen, 'r')
    local txt = h.readAll()
    h.close()

    local succ, res = pcall(function()
        return textutils.unserialize(txt)
    end)

    if not succ then return false, nil end
    if res == nil then return false, nil end

    local o = OreContext:_init()
    o.filen = res.filen
    o.empty_tiles = res.empty_tiles
    o.handled = res.handled
    o.cur_rel_loc = vector.new(res.cur_rel_loc.x,
                               res.cur_rel_loc.y,
                               res.cur_rel_loc.z)
    o.cur_rel_dir = res.cur_rel_dir
    o.fuel = res.fuel
    o.to_inspect = {}
    for i, v in ipairs(res.to_inspect) do
        o.to_inspect[i] = vector.new(v.x, v.y, v.z)
    end
    o.next_action = res.next_action
    if res.current_node ~= nil then
        o.current_node = vector.new(res.current_node.x,
                                    res.current_node.y,
                                    res.current_node.z)
    end
    if res.current_dig ~= nil then
        o.current_dig = vector.new(res.current_dig.x,
                                   res.current_dig.y,
                                   res.current_dig.z)
    end
    return true, o
end

---
-- Recovers the ore context to within one move. This does not delete any files
-- (use clean_and_save for that). This returns the possible states for the turtle,
-- which requires some external source of ground truth to collapse.
-- The result is a table of OreContext's, which contains the truth. This has at
-- most two elements (pre/post move).
-- @param filen where the recovery state is stored
-- @return table each element is a possible ore context
function OreContext.recover_possible(filen)
    local og_exists = fs.exists(filen)
    local bak_exists = fs.exists(filen .. '.bak')
    local bak2_exists = fs.exists(filen .. '.bak2')
    local post_exists = fs.exists(filen .. '.post')
    local deleting_exists = fs.exists(filen .. '.deleting')

    if deleting_exists then
        -- Crashed while deleting files
        return {OreContext:new(filen)}
    end

    if bak2_exists then
        -- Failed during clean_and_save; if we can recover bak2 that is the
        -- truth, otherwise we can ignore bak2
        local succ, res = OreContext:_deserialize(filen .. '.bak2')
        if succ then return {res} end
    end

    if og_exists and bak_exists and post_exists then
        -- Definitely after the move in bak. The original file may be
        -- corrupted.
        local succ, res = OreContext:_deserialize(filen .. '.bak')
        if not succ then
            error('impossible corruption of bak in true, true, true')
        end

        return {res:_post()}
    elseif og_exists and bak_exists and not post_exists then
        -- If bak is corrupted, then we are before the move
        -- in original. Otherwise, it's ambiguous; we could be before or
        -- after the move in original.
        local succ_og, res_og = OreContext:_deserialize(filen)
        if not succ_og then
            error('impossible corruption of original in true, true, false')
        end

        local succ, res = OreContext:_deserialize(filen .. '.bak')
        if not succ then
            return {res_og}
        end

        -- We are either before or after the action is res_og
        if res_og.next_action == nil then
            error('impossible: true, true, false but next_action nil')
        end

        return {res_og, res_og:_post()}
    elseif og_exists and not bak_exists and post_exists then
        -- We are before the move in og or next_action is nil
        local succ, res = OreContext:_deserialize(filen)
        if not succ then
            error('impossible corruption in true, false, true')
        end
        res.next_action = nil
        return {res}
    elseif not og_exists and bak_exists and post_exists then
        -- We are after the move in bak.
        local succ, res = OreContext:_deserialize(filen)
        if not succ then
            error('impossible corruption in false, true, true')
        end
        return {res}
    elseif og_exists and not bak_exists and not post_exists then
        -- There is no move in original or we corrupted our first save
        local succ, res = OreContext:_deserialize(filen)
        if not succ then
            -- Corrupted initial save
            return {OreContext:new(filen)}
        end
        res.next_action = nil
        return {res}
    elseif not og_exists and bak_exists and not post_exists then
        error('unreachable: false, true, false')
    elseif not og_exists and not bak_exists and post_exists then
        error('unreachable: false, false, true')
    elseif not og_exists and not bak_exists and not post_exists then
        -- We haven't done anything yet, crash was before initial save
        return {OreContext:new(filen)}
    end
end

--- Attempts to recover by using fuel as a source of truth. This will collapse
-- movement possibilities but not turns, and it only works when fuel is not
-- unlimited.
-- @param poss table the possibilities that we are going to attempt to collapse
-- @return table a subset of poss which contains the remaining possibilities
function OreContext.recover_with_fuel(poss)
    local fuel = turtle.getFuelLevel()
    if fuel == 'unlimited' then
        print('Fuel levels unlimited and cannot be used to recover')
        return poss
    end

    print('Attempting to use our fuel level to recover...')

    local new_poss = {}
    for k, v in ipairs(poss) do
        if v.fuel ~= fuel then
            print('Managed to eliminate one possibility with fuel')
        else
            new_poss[#new_poss + 1] = v
        end
    end

    print('After using fuel there are ' .. tostring(#new_poss)
          .. ' possibilities')
    return new_poss
end

--- Attempts to recover by using the GPS as a source of truth. This can
-- collapse turns and moves, but requires a GPS and requires movements. Luckily
-- this doesnt need any prior information to determine the turtles location,
-- so if it crashes while recovering we can still recover next time.
--
-- This keeps moving up/down until it either exhausts all moves or finds an x/z
-- axis which is empty which the turtle can use to determine its direction.
-- If we reach the edge of the gps before this finishes, we return to where we
-- started. If we run out of fuel we error.
--
-- @param poss table the possibilities for when we first crashed
-- @param abs_offset vector the absolute position that should be treated as
-- (0, 0, 0) in the ore context
-- @param dir_offset int the absolute direction that should be treated as 0
-- in the ore context
-- @return table either poss or a table containing just the ground truth
function OreContext.recover_with_gps(poss, abs_offset, dir_offset)
    print('Attempting to use GPS to find viable context..')

    local abs_loc, abs_dir = gps_locate.locate()
    if not abs_loc then
        print('Failed to determine location with gps')
        return poss
    end

    local og_offset = abs_loc - abs_offset
    local og_dir = abs_dir - dir_offset
    if og_dir < 0 then og_dir = og_dir + 4 end

    local res = poss[1]:deep_copy()
    res.cur_rel_loc = og_offset
    res.cur_rel_dir = og_dir
    res.empty_tiles[tostring(og_offset)] = true
    res.next_action = nil

    print('Successfully recovered with GPS')
    return {res}
end

--- Attempts to recover by guessing. I'd say we have better than 50/50 odds
-- @param poss table the possibilities for when we first crashed
-- @return table a single element from poss
function OreContext.recover_with_guess(poss)
    print('Recovering by guessing, sorry if we destroy stuff')
    return {poss[#poss]}
end

--- Cleans the output files such that only filen is stored and we are
-- ready to proceed. This is done in a non-destructive manner, i.e.,
-- we can handle crashing at any time during this process. This assumes
-- that if bak2 already exists we don't need to replace it.
function OreContext:clean_and_save()
    if (fs.exists(self.filen .. '.deleting')
            or not fs.exists(self.filen .. '.bak2')) then
        self:_serialize(self.filen .. '.bak2')
        fs.delete(self.filen .. '.deleting')
    end
    if fs.exists(self.filen) then fs.delete(self.filen) end
    if fs.exists(self.filen .. '.bak') then fs.delete(self.filen .. '.bak') end
    if fs.exists(self.filen .. '.post') then
        fs.delete(self.filen .. '.post')
    end
    self:_serialize(self.filen)
    fs.delete(self.filen .. '.bak2')
end

--- Clears all saved files. This is not recoverable. This operation will
-- never leave the files in a corrupted state.
function OreContext:clean()
    local h = fs.open(self.filen .. '.deleting', 'w')
    h.write('\n')
    h.close()

    fs.delete(self.filen .. '.post')
    fs.delete(self.filen .. '.bak')
    fs.delete(self.filen)
    fs.delete(self.filen .. '.bak2')
    fs.delete(self.filen .. '.deleting')
end

--- Returns the index in queued moves that we should perform next,
-- the path to the spot as a series of attribute names in the turtle
-- module, and the name for the inspect function which should be
-- invoked (inspect, inspectUp, or inspectDown).
--
-- This uses turn-sensitive manhattan distance as the heuristic and breaks ties
-- on the heuristic with an A* search. True ties are broken arbitrarily.
--
-- Returns nil, nil, nil if there is nothing left to inspect.
function OreContext:_determine_next_with_path()
    if #self.to_inspect <= 0 then return nil, nil, nil end

    local best_heur = nil
    local best_arr = nil
    local min_heur = -1
    local best_path = nil
    local best_ind = nil

    -- We loop because it's possible our manhattan heuristic gives us
    -- only nodes we can't actually reach. This is very unlikely, so
    -- this loop will almost never repeat. But if it does, we only consider
    -- nodes with a higher heuristic, until we eventually exhaust all nodes.
    while best_path == nil do
        best_heur = nil
        best_arr = nil

        for i=1, #self.to_inspect do
            local v = self.to_inspect[i]
            local heur = paths.manhattan_consistent(
                self.cur_rel_loc,
                v,
                self.cur_rel_dir,
                nil
            )

            if heur > min_heur and (best_heur == nil or heur < best_heur) then
                best_heur = heur
                best_arr = {i}
            elseif heur == best_heur then
                best_arr[#best_arr + 1] = i
            end
        end
        if best_heur == nil then error('no possible connections!') end
        min_heur = best_heur

        best_path = paths.determine_path(
            self.empty_tiles,
            true,
            self.cur_rel_loc,
            self.cur_rel_dir,
            self.to_inspect[best_arr[1]],
            nil,
            paths.manhattan_consistent
        )
        best_ind = best_arr[1]

        for i=2, #best_arr do
            local path = paths.determine_path(
                self.empty_tiles,
                true,
                self.cur_rel_loc,
                self.cur_rel_dir,
                self.to_inspect[best_arr[i]],
                nil,
                paths.manhattan_consistent
            )
            if path ~= nil and (best_path == nil or #path < #best_path) then
                best_path = path
                best_ind = i
            end
        end

        if best_path ~= nil and #best_path < 1 then
            print('best path between ' .. tostring(self.cur_rel_loc))
            print('facing ' .. constants.DIR_TO_NAME[self.cur_rel_dir])
            print('to ' .. tostring(self.to_inspect[best_arr[best_ind]]))
            print('is empty')
            error()
        end
    end

    -- we are promised last is not back by paths
    local last = best_path[#best_path]
    best_path[#best_path] = nil

    if last == 'forward' then
        last = 'inspect'
    elseif last == 'up' then
        last = 'inspectUp'
    elseif last == 'down' then
        last = 'inspectDown'
    else
        error('weird last move: ' .. tostring(last))
    end

    return best_ind, best_path, last
end

--- Returns the index in either DIG_FN or INSPECT_FN that corresponds to the
-- attribute which operates on the given block, if there is one. Otherwise,
-- sets the current path and path ind to get us so that we can do that to the
-- given node.
-- @param tar vector the block you want to operate on
-- @return int|nil the function index or nil if none work
function OreContext:_get_fn_ind_or_set_path(tar)
    local delta = tar - self.cur_rel_loc
    local delta_s = tostring(delta)
    local ind = constants.DIR_AND_DELTA_TO_FN_IND[self.cur_rel_dir][delta_s]
    if not ind then
        self._current_path_ind = 1
        self._current_path = paths.determine_path(
            self.empty_tiles, true, self.cur_rel_loc, self.cur_rel_dir,
            tar, nil, paths.manhattan_consistent)
        if self._current_path == nil then
            print('tried to go to ' .. tostring(tar))
            print('from ' .. tostring(self.cur_rel_loc))
            print('facing ' .. constants.DIR_TO_NAME[self.cur_rel_dir])
            print('but no path found')
            error()
        end
        self._current_path[#self._current_path] = nil
        if #self._current_path <= 0 then error('delta_s = ' .. delta_s) end
        return nil
    end
    return ind
end

--- Performs the next queued operation. Returns true if there are more queued
-- operations, and returns false otherwise. If the turtle shuts down during
-- this process, it may be recoverable using the recover* functions. If this
-- returns false, then the turtle is at the same place that the ore context
-- was initialized at, facing the same direction.
-- @param filter a function which accepts the table result of a successful
-- inspect and returns true if it should be dug and false otherwise.
-- @return true if there are more queued moves, false otherwise
function OreContext:next(filter)
    if self._current_path ~= nil and self._current_path_ind <= #self._current_path then
        local act = self._current_path[self._current_path_ind]
        self._current_path_ind = self._current_path_ind + 1
        self.next_action = act
        self:clean_and_save()
        self:_serialize(self.filen .. '.bak')
        while not turtle[act]() do
            fs.delete(self.filen .. '.bak')
            if act == 'back' then
                self._current_path[self._current_path_ind] = 'forward'
                table.insert(self._current_path, self._current_path_ind, 'turnLeft')
                table.insert(self._current_path, self._current_path_ind, 'turnLeft')
                table.insert(self._current_path, self._current_path + 3, 'turnLeft')
                table.insert(self._current_path, self._current_path + 3, 'turnLeft')
                return true
            end
            local fn_ind = constants.MOVE_TO_FN_IND[act]
            if fn_ind ~= nil then
                turtle[constants.DIG_FN[fn_ind]]()
            end
            os.sleep(1)
            self:_serialize(self.filen .. '.bak')
        end
        local h = fs.open(self.filen .. '.post', 'w')
        h.write('\n')
        h.close()
        self.next_action = nil
        if act == 'turnLeft' then
            self.cur_rel_dir = constants.LEFT_DIRS[self.cur_rel_dir]
        elseif act == 'turnRight' then
            self.cur_rel_dir = constants.RIGHT_DIRS[self.cur_rel_dir]
        elseif act == 'forward' then
            self.cur_rel_loc = (
                self.cur_rel_loc + constants.DIR_TO_DELTA[self.cur_rel_dir])
        elseif act == 'up' then
            self.cur_rel_loc = self.cur_rel_loc + constants.UP_DIR
        elseif act == 'down' then
            self.cur_rel_loc = self.cur_rel_loc + constants.DOWN_DIR
        elseif act == 'back' then
            self.cur_rel_loc = self.cur_rel_loc + (
                constants.DIR_TO_DELTA[constants.BACK_DIRS[self.cur_rel_dir]]
            )
        else
            error('unknown action: ' .. tostring(act))
        end
        self.fuel = turtle.getFuelLevel()
        self:_serialize(self.filen)
        fs.delete(self.filen .. '.bak')
        fs.delete(self.filen .. '.post')
        return true
    end

    if self.current_dig ~= nil then
        local dig_i = self:_get_fn_ind_or_set_path(self.current_dig)
        if not dig_i then return self:next(filter) end
        if turtle[constants.DETECT_FN[dig_i]]() then
            turtle[constants.DIG_FN[dig_i]]()
        end
        self.empty_tiles[tostring(self.current_dig)] = true
        self.current_dig = nil
        self:clean_and_save()
        return true
    end

    if self.current_node ~= nil then
        local ins_i = self:_get_fn_ind_or_set_path(self.current_node)
        if not ins_i then return self:next(filter) end
        self:_inspect_with(constants.INSPECT_FN[ins_i], filter)
        self:clean_and_save()
        return true
    end

    if #self.to_inspect <= 0 then
        if self.cur_rel_loc:length() ~= 0 or self.cur_rel_dir ~= 0 then
            self._current_path = paths.determine_path(
                self.empty_tiles, true, self.cur_rel_loc, self.cur_rel_dir,
                vector.new(0, 0, 0), 0, paths.manhattan_consistent)
            self._current_path_ind = 1
            return self:next(filter)
        end
        return false
    end

    local ind, path, _ = self:_determine_next_with_path()
    self.current_node = table.remove(self.to_inspect, ind)
    self._current_path = path
    self._current_path_ind = 1
    self:clean_and_save()
    return self:next(filter)
end

ores.OreContext = OreContext
return ores
