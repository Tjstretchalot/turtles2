--- This module allows for a single redux-style store of state which can be
-- persisted through restarts. In addition to reducers, oeprations which
-- effect the external state of the turtle (global location and direction,
-- other blocks) require unidirectional actionators and discriminators.
-- An actionator simply performs the action that causes the external state
-- to match the state that we will be in after the reducer. In the case we
-- restart and are not sure if we completed the action or not, we will run
-- through the discriminators. If the discriminators fail to determine if the
-- action was completed, then the store is corrupted and an error is thrown.
--
-- Listeners don't work as well and aren't as helpful as in redux because we
-- dont anticipate UI components and we wouldn't be able to recover listeners
-- (we could only do as good as ensuring it ran at least once and not more than
-- twice)
--
-- The data flow is as follows
--
-- 1. store:dispatch(action)
--   describes either what were about to do (if an actionator is attached)
--   or what we just did (if no actionator is attached)
-- 2. If there is an actionator for this action, then:
--      Indexed files: filen, .actionating, .post, .list, .list.latest
--                     * indicates corruption guarrantees this line
--                                                     1,4
--      Store action in filen .. '.actionating'        1,2*,4
--      Run actionator                                 1,2,4
--      Touch filen .. '.post'                         1,2,3,4
--      Write new action list to .. '.list.latest'     1,2,3,4,5*
--      Delete .. '.list'                              1,2,3,5
--      Delete '.post'                                 1,2,5
--      Copy .. '.list.latest' to .. '.list'           1,2,4*,5
--      Delete '.actionating'                          1,4,5
--      Delete .. '.list.latest'                       1,4
--      If the list is too long, clean and save
-- 3. Call the reducer to update state
-- 4. Store new state in a fail-safe way

local state = {}

--- An application using this style of state management should have a single
-- shared Store. Throughout the state, when actions are used as keys we mean
-- the action type.
--
-- Instance Variables
-- filen string where we store the state. we will suffix this file for other
-- temporary files / working space.
--
-- reducer function (state, action) => state used to determine the new state
-- after an action. Should not modify the arguments
--
-- actionators table (action -> function(action)) performs the action which
-- modifies the external state of the world
--
-- discriminators table (action -> table[function]) the functions which are
-- capable of determining if we are before/after an action. The functions
-- should accept action, a list of possible states and a boolean, and return
-- a new list of possible states. If the boolean is true, it's possible that
-- the real state is not in the list of possible states, and is typically
-- called 'corrupted'. Once a discriminator narrows the list to 1 element, we
-- have successfully recovered.
--
-- raw table the actual underlying store
--
-- _list table contains actions which we have stored to the .list instead of
-- replacing the current store.
local Store = {}

local function _touch(filen)
    local h = fs.open(filen, 'w')
    h.write('\n')
    h.close()
end


--- Constructs an uninitialized store. Should be treated as a
-- private constructor.
function Store:_init()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

--- Initializes an empty store with the given reducer an actionators. This does
-- not save - call clean_and_save for that.
-- @param filen string the path to the root file that we will store information
-- in. We will suffix this file for working space
-- @param reducer function (state, action) => state without modifying arguments
-- @param actionators table (action -> function). We use this method rather
-- than the reducer because we do a lot of I/O for actionators that can be
-- skipped if they are a no-op. We pass the actionator the action to perform.
-- @param discriminators table (action -> table[function]). Each discriminator
-- function accepts an action and list of possible Stores and returns a new
-- list of possible stores. Discriminators should attempt to only return a
-- subset of  the passed states, but this is not enforced and not always
-- possible. A third boolean argument may also be passed - corrupted - which is
-- true if we are recovering from a previous discriminator and may have been
-- corrupted. Some discriminators can recover even from corruption if they have
-- an external source of ground truth (i.e., gps)
-- @param init_raw the initial raw store; may be a function in which case it
-- is invoked, otherwise should be a table.
function Store:new(filen, reducer, actionators, discriminators, init_raw)
    local o = Store:_init()
    o.filen = filen
    o.reducer = reducer
    o.actionators = actionators
    o.discriminators = discriminators
    if type(init_raw) == 'table' then
        o.raw = init_raw
    else
        o.raw = init_raw()
    end
    o._list = {}
    return o
end

--- Serializes a single action to the given file.
function Store:_serialize_action(filen, act)
    local serd = textutils.serialize(act)
    local h = fs.open(filen, 'w')
    h.write(serd)
    h.close()
end

--- Serializes the store to the given file. This only stores 'raw'
-- @param filen string where to save
function Store:_serialize(filen)
    local serd = textutils.serialize(self.raw)
    local h = fs.open(filen, 'w')
    h.write(serd)
    h.close()
end


--- Serializes the action list to the given file.
-- @param filen string where to save the _list
function Store:_serialize_list(filen)
    local serd = textutils.serialize(self._list)
    local h = fs.open(filen, 'w')
    h.write(serd)
    h.close()
end

--- Deserializes the action stored in the given file
-- @param filen the file the action is stored in
-- @return nil if the file is corrupted, otherwise the action
function Store:_deserialize_action(filen)
    if not fs.exists(filen) then return nil end
    local h = fs.open(filen, 'r')
    local txt = h.readAll()
    h.close()
    return textutils.unserialize(txt)
end

--- Deserializes the store in the given file with the arguments that were
-- passed to construct it.
-- @param real_filen string where to load the store from
-- @param filen string same as new
-- @param reducer same as new
-- @param actionators same as new
-- @param discriminators same as new
-- @return Store the store that was saved or nil if its corrupted
function Store:_deserialize(real_filen, filen, reducer, actionators,
                            discriminators)
    if not fs.exists(real_filen) then return nil end

    local h = fs.open(real_filen, 'r')
    local txt = h.readAll()
    h.close()

    local raw = textutils.unserialize(txt)
    if raw == nil then return nil end

    return Store:new(filen, reducer, actionators, discriminators, raw)
end

--- Deserializes the action list stored in the given file
-- @param filen string same as passed to _serialize_list
-- @return the stored action list or nil if its corrupted
function Store:_deserialize_list(filen)
    if not fs.exists(filen) then return nil end

    local h = fs.open(filen, 'r')
    local txt = h.readAll()
    h.close()

    return textutils.unserialize(txt)
end

--- Deserializes the store which is stored in the given file with the given
-- list file. This applies the queued actions in the list to the raw store
-- in the real file.
-- @param real_filen where the outdated store is
-- @param list_filen where the list to update the store is
-- @param filen same as new
-- @param reducer same as new
-- @param actionators same as new
-- @param discriminators same as new
-- @return the store or nil if one of the files is corrupted
function Store:_deserialize_with_list(real_filen, list_filen, filen, reducer,
                                      actionators, discriminators)
    local store = Store:_deserialize(
        real_filen, filen, reducer, actionators, discriminators)
    if store == nil then return nil end

    local _list = Store:_deserialize_list(list_filen)
    if _list == nil then return nil end

    for _, act in ipairs(_list) do
        store.raw = reducer(store.raw, act)
    end
    store._list = _list
    return store
end

--- Cleans the directory and saves the store. This will empty the written
-- action list, ensuring future actions are as fast as possible (until the
-- list starts to fill up again). This assumes that if .. '.bak2' exists
-- then it contains this store.
function Store:clean_and_save()
    if not fs.exists(self.filen .. '.bak2') then
        self:_serialize(self.filen .. '.bak2')
    end

    fs.delete(self.filen)
    fs.delete(self.filen .. '.actionating')
    fs.delete(self.filen .. '.post')
    fs.delete(self.filen .. '.list')
    fs.delete(self.filen .. '.list.latest')
    fs.delete(self.filen .. '.list.recovery')
    fs.delete(self.filen .. '.discriminating')
    fs.copy(self.filen .. '.bak2', self.filen)
    fs.delete(self.filen .. '.bak2')

    self._list = {}
    self:_serialize_list(self.filen .. '.list')
end

-- Deletes all store-related files. This prevents recovery
function Store:clean()
    self:clean_and_save()
    fs.delete(self.filen .. '.list')
    fs.delete(self.filen)
end

--- This can be called to save the _list to .list.recovery, delete .list,
-- copy .list.recovery to .list, and then delete .list.recovery. This assumes
-- we do not need to write to .list.recovery if it already exists.
function Store:_update_saved_list()
    if not fs.exists(self.filen .. '.list.recovery') then
        self:_serialize_list(self.filen .. '.list.recovery')
    end
    fs.delete(self.filen .. '.list')
    fs.copy(self.filen .. '.list.recovery', self.filen .. '.list')
    fs.delete(self.filen .. '.list.recovery')
end

--- Recovers the store that was initialized with the given arguments. This may
-- be used for the initial construction of the store as that can be detected.
-- The arguments are the same as to new()
-- @return the store we are in
-- @error if we cannot uniquely determine the store
function Store:recover(filen, reducer, actionators, discriminators, init_raw)
    if fs.exists(filen .. '.bak2') then
        local store = Store:_deserialize(
            filen .. '.bak2', filen, reducer, actionators, discriminators)
        if store then return store end
    end

    if fs.exists(filen) and fs.exists(filen .. '.list.recovery') then
        local store = Store:_deserialize(
            filen, filen, reducer, actionators, discriminators
        )
        if not store then
            error('impossible corruption with .list.recovery')
        end

        local _list = Store:_deserialize_list(filen .. '.list.recovery')
        if _list then
            for _, act in ipairs(_list) do
                store.raw = reducer(store.raw, act)
            end
            store._list = _list
            return store
        end
    end

    local _exists = fs.exists(filen)

    if not _exists then
        return Store:new(
            filen, reducer, actionators, discriminators, init_raw
        )
    end

    local actionator_exists = fs.exists(filen .. '.actionating')
    local post_exists = fs.exists(filen .. '.post')
    local list_exists = fs.exists(filen .. '.list')
    local list_latest_exists = fs.exists(filen .. '.list.latest')

    -- Possible file states, each of which is handled in exactly one statement
    -- (else could be removed without changing effective logic)
    -- 1,2*,4         | 1,2,4            | 1,2,3,4
    -- 1,2,3,4,5*     | 1,2,3,5          | 1,2,5
    -- 1,2,4*,5       | 1,4,5            | 1,4
    if _exists and not actionator_exists and not post_exists and list_exists and not list_latest_exists then
        -- 1,~2,~3,4,~5; matches 1,4 only
        -- standard recovery
        local store = Store:_deserialize_with_list(
            filen, filen .. '.list', filen, reducer, actionators, discriminators
        )
        if not store then error('impossible corruption with 1,4') end
        return store
    elseif _exists and actionator_exists and not post_exists and list_exists and not list_latest_exists then
        -- 1,2,~3,4,~5; matches 1,2*,4 and 1,2,4
        -- corruption or ambiguous pre/post actionator
        local act = Store:_deserialize_action(filen .. '.actionating')
        local before = Store:_deserialize_with_list(
            filen, filen .. '.list', filen, reducer, actionators, discriminators
        )
        if before == nil then error('impossible corrupton of 1,4 with 1,2*,4') end
        if act == nil then return before end

        local corrupted = fs.exists(filen .. '.discriminating')
        if not corrupted then
            _touch(filen .. '.discriminating')
        end

        -- Ambiguous! we could be before or after

        local after = Store:new(filen, reducer, actionators, discriminators, reducer(before.raw, act))
        after._list = before._list
        local poss = {before, after}
        local discrims = discriminators[act.type] or {}
        for dind, discrim in ipairs(discrims) do
            poss = discrim(act, poss, corrupted)
            if poss == nil or #poss == 0 then
                error('discrim ' .. tostring(dind) .. ' returned no poss')
            end
            if #poss == 1 then return poss[1] end
        end
        error('Failed to disambiguate possibilities: before/after '
              .. textutils.serialize(act))
    elseif _exists and actionator_exists and post_exists and list_exists and not list_latest_exists then
        -- 1,2,3,4,~5; matches 1,2,3,4 only
        -- use base + list + actionator
        local store = Store:_deserialize_with_list(
            filen, filen .. '.list', filen, reducer, actionators, discriminators
        )
        if store == nil then
            error('impossible corruption of 1,4 with 1,2,3,4')
        end

        local act = Store:_deserialize_action(filen .. '.actionating')
        if act == nil then
            error('Impossible corruption of 2 with 1,2,3,4')
        end
        store._list[#store._list + 1] = act
        store.raw = reducer(store.raw, act)
        return store
    elseif _exists and (actionator_exists or post_exists) and list_latest_exists then
        -- 1,2|3,4|~4,5; matches 1,2,3,4,5*; 1,2,3,5; 1,2,5; 1,2,4*,5; 1,4,5
        -- use base + list.latest if list.latest is not corrupted, otherwise use
        -- base + list + actionator
        local list_latest = Store:_deserialize_list(filen .. '.list.latest')
        if list_latest == nil then
            local store = Store:_deserialize_with_list(
                filen, filen .. '.list', filen, reducer, actionators, discriminators
            )
            if store == nil then
                error('impossible corruption of 1,4 with 1,2,3,4,5(cor)')
            end

            local act = Store:_deserialize_action(filen .. '.actionating')
            if act == nil then
                error('Impossible corruption of 2 with 1,2,3,4,5(cor)')
            end
            store._list[#store._list + 1] = act
            store.raw = reducer(store.raw, act)
            return store
        end

        local store = Store:_deserialize(
            filen, filen, reducer, actionators, discriminators
        )
        if store == nil then
            error('impossible corruption of 1 with 1,2,3,4,5')
        end
        for _, v in ipairs(list_latest) do
            store.raw = reducer(store.raw, v)
        end
        store._list = list_latest
        return store
    else
        error('strange combination: '
              .. textutils.serialize({_exists, actionator_exists, post_exists,
                                      list_exists, list_latest_exists}))
    end
end

--- Dispatches the given action. This will call the attached actionator if
-- there is one, then update the state of the store. Not really dispatching,
-- but keeps the familiar name from Redux
-- @param action the pure action table to perform. Must have a 'type' key.
function Store:dispatch(action)
    if type(action) ~= 'table' then
        error('actions should be tables, got ' .. tostring(action))
    end

    if type(action.type) ~= 'string' then
        error('action is missing type: ' .. textutils.serialize(action))
    end

    local typ = action.type
    if self.actionators[typ] then
        Store:_serialize_action(self.filen .. '.actionating', action)
        self.actionators[typ](action)
        _touch(self.filen .. '.post')
        self.raw = self.reducer(self.raw, action)
        self._list[#self._list + 1] = action
        self:_serialize_list(self.filen .. '.list.latest')
        fs.delete(self.filen .. '.list')
        fs.delete(self.filen .. '.post')
        fs.copy(self.filen .. '.list.latest', self.filen .. '.list')
        fs.delete(self.filen .. '.actionating')
        fs.delete(self.filen .. '.list.latest')
    else
        self.raw = self.reducer(self.raw, action)
        self._list[#self._list + 1] = action
        self:_update_saved_list()
    end

    if #self._list > 1 and fs.getSize(self.filen .. '.list') > 4096 * 1028 then
        self:clean_and_save()
    end
end

state.Store = Store

--- Combines the given table of reducers into a single reducer which
-- uses the keys in the table as the keys in the global state space.
-- @param table a table where the keys are strings and the values
-- are reducer functions
-- @return function a single function which combines all the given
-- reducers.
function state.combine_reducers(reducers)
    local function result(raw, act)
        if raw == nil or act == nil then
            error('raw/act is nil', 2)
        end
        local result = {}
        for k, v in pairs(reducers) do
            if raw[k] == nil then
                error('raw[' .. tostring(k) .. '] nil', 2)
            end
            result[k] = v(raw[k], act)
        end
        return result
    end
    return result
end

--- Acts similiarly to combine_reducers except for actionators.
-- @param actionators table the keys are ignored, values are tables which
-- are actionators (map action types to functions). If there are multiple
-- actionators with the same keys, an error is raised.
-- @return table the keys are action types and the values are functions,
-- combining all of the given actionators.
function state.combine_actionators(actionators)
    local result = {}
    for _, actionator in pairs(actionators) do
        for act_type, fn in pairs(actionator) do
            if result[act_type] ~= nil then
                error('multiple actionators with act type ' .. act_type)
            end
            result[act_type] = fn
        end
    end
    return result
end

local function wrap_discrim(discrim, key)
    local function result(act, poss, corrupted)
        return discrim(act, poss, corrupted, key)
    end
    return result
end
--- Acts similarly to combine_reducers except for discriminators.
-- @param discriminator table the keys are like combine_reducers, the values
-- are tables which map action types to a table of functions which can
-- disambiguate possible states. To make this possible, we pass the key to
-- the discriminator funcitons.
-- @return table a single discriminator table with every discriminator
-- included
function state.combine_discriminators(discriminators)
    local result = {}
    for dkey, discriminator in pairs(discriminators) do
        for k, v in pairs(discriminator) do
            if result[k] == nil then
                result[k] = {}
            end
            local arr = result[k]
            for i, fn in ipairs(v) do
                arr[#arr + 1] = wrap_discrim(fn, dkey)
            end
        end
    end
    return result
end

--- Acts similiarly to combine_inits except for initialization tables or
-- functions.
-- @param inits table the keys the same as for combine_reducers, the values
-- are tables or functions which return tables when passed no arguments.
-- @return function a function which acts as the combination of all the init
-- functions/tables
function state.combine_inits(inits)
    local function result()
        local tbl = {}
        for k, v in pairs(inits) do
            if type(v) == 'table' then
                tbl[k] = v
            else
                tbl[k] = v()
            end
        end
        return tbl
    end
    return result
end

--- Combines all the reducers, actionators, and discriminators and returns
-- them in the same order. This is equivalent to calling the individual
-- combine function on each element.
-- Usage: r, a, d, i = state.combine(r, a, d, i)
function state.combine(reducers, actionators, discriminators, inits)
    reducers = state.combine_reducers(reducers)
    actionators = state.combine_actionators(actionators)
    discriminators = state.combine_discriminators(discriminators)
    inits = state.combine_inits(inits)
    return reducers, actionators, discriminators, inits
end

--- Deep copies the given raw state recursively.
-- @param st table the raw state
-- @return table a deep copy
function state.deep_copy(st)
    if type(st) ~= 'table' then return st end

    local res = {}
    for k, v in pairs(st) do
        res[k] = state.deep_copy(v)
    end
    return res
end

--- This uses a guessing strategy for discriminating possible states, which
-- will always give a single unique guess. This simply guesses the move
-- completed.
-- @param poss the possibilities to discriminate between
-- @return the post possibility
function state.discriminate_with_guess(act, poss, corrupted)
    return {poss[#poss]}
end

return state
