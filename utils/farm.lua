--- This is the backbone for programs which are based on farming wheat,
-- carrots, potatos, etc. Essentially, this takes in a list of chests,
-- growth spots, open terrain (for pathfinding), and the time between checking
-- locations. Each seed type may specify many locations in the order they
-- should be checked.
--
-- Store:
--  {
--      move_state = {...},
--      farm = {
--          objective = string
--          context = table
--          farm_statuses = {[index in farms] = {
--              checked_day=number,
--              checked_time=number
--          }, ... }
--      }
--  }

local inv = require('utils/inv')
local paths = require('utils/paths')
local path_utils = require('utils/path_utils')
local move_state = require('utils/move_state')
local home = require('utils/home')
local constants = require('utils/constants')
local state = require('utils/state')

local farm = {}

--- If we have fewer than this many movements, we only perform the refuel
-- objective.
local REFUEL_AT = 800

--- If we are actively checking a farm, we will interrupt farming and go
-- straight to the fuel chest to refuel if doing so would cause us to
-- fall below the given margin of fuel. I.e., if we are 50 blocks away
-- and the refuel margin is 100, we will interrupt at 150 fuel. This is
-- not even checked if we are above REFUEL_AT
local SUB_REFUEL_MARGIN = 100

--- Rather than calculating entire paths when we are deciding if we should
-- interrupt farming to refuel, we simply multiply manhattan distance by
-- this amount.
local SUB_REFUEL_FACTOR = 1.1

--- There's nothing to do. We should check if there's something to do and if
-- not, wait a bit and try again.
-- context = {}
local OBJ_IDLE = 'idle'

--- We are trying to check on a farm - dig grown blocks and, if necessary,
-- hoe and plant seeds.
-- context = {
--     ind = number, -- the farm to check
--     loc_ind = number, -- the location we are currently at for the farm
--     sub_objective = string, -- the current sub objective we are working on
--     sub_context = table|nil, -- context for sub objective or nil
-- }
local OBJ_CHECK_FARM = 'check_farm'

--- We are trying to ensure we have enough fuel. Go to the fuel chest, use it
-- and refuel. Triggered if we are below the REFUEL_AT constant.
local OBJ_REFUEL = 'refuel'

--- We have some stuff in our inventory. We are depositing it at the
-- appropriate chests, preferring specific chests but falling back to the
-- excess chest if necessary. This iterates over the specific chests, meaning
-- that the context should always be initialized with next_chest=1. This
-- doesn't go to chests unless we have something to deposit, instead updating
-- next_chest appropriately.
-- context = {
--     next_chest = number
-- }
local OBJ_DEPOSIT = 'deposit'

--- We are farming but are dangerously low on fuel and going to the fuel chest
-- before continuing. No context.
local SUB_OBJ_REFUEL = 'sub_refuel'

--- We are farming and have no seeds but needs ome. We are going to the seed
-- chest and grabbing more seeds. No context.
local SUB_OBJ_RESTOCK = 'sub_restock'

--- We are farming but ran out of inventory space. We are depositing stuff
-- at the appropriate chest. Context is {next_chest=number}, always initialized
-- with next_chest=1, just as if by OBJ_DEPOSIT
local SUB_OBJ_DEPOSIT = 'sub_deposit'

--- We are checking the spot determined by loc_ind. No context.
local SUB_OBJ_CHECK = 'sub_check'

-- Act constants. See corresponding functions for descriptions.
local ACT_SET_OBJECTIVE = 'set_objective'
local ACT_SET_SUB_OBJECTIVE = 'set_sub_objective'
local ACT_CHECK_FARM_INCR_LOC_IND = 'check_farm_incr_loc'
local ACT_CHECK_FARM_FINISH = 'check_farm_finish'
local ACT_CHECK_FARM_DEPOSIT_SET_NEXT_CHEST = 'check_farm_deposit_set_next_chest'
local ACT_DEPOSIT_SET_NEXT_CHEST = 'deposit_set_next_chest'

--- Set the current objective we are performing.
-- @param obj string the objective to perform (OBJ_*)
-- @param context table the initial context for the objective
-- @return the action which sets the objective and context
function farm.set_objective(obj, context)
    return {type = ACT_SET_OBJECTIVE, objective = obj, context = context}
end

--- Sets the curernt sub-objective we are performing. This can only be used if
-- we are in a state with sub objectives, i.e., during check farm
-- @param sub_obj string the sub objective to perform (SUB_OBJ_*)
-- @param sub_context table|nil the initial context
-- @return the action which sets the sub objective and sub context
function farm.set_sub_objective(sub_obj, sub_context)
    return {
        type = ACT_SET_SUB_OBJECTIVE,
        sub_objective = sub_obj,
        sub_context = sub_context
    }
end

--- Increments the loc_ind in the check farm objective. Should be called after
-- we have checked and finished dealing with the current location ind and there
-- are still more locations to deal with.
-- @return the action which increments loc_ind
function farm.check_farm_incr_loc_ind()
    return { type = ACT_CHECK_FARM_INCR_LOC_IND }
end

--- Used to finish checking a farm. Updates the farm status for the currently
-- checked farm to the day/time the action was created, then sets the objective
-- to idle.
-- @return the action which finishes a check_farm
function farm.check_farm_finish()
    return { type = ACT_CHECK_FARM_FINISH, day=os.day(), time=os.time() }
end

--- Sets the next chest to deposit at while in the the OBJ_SUB_DEPOSIT sub
-- objective.
-- @param next_chest number the next chest to deposit at
-- @return the action which sets the next chest in the sub objective context
function farm.check_farm_deposit_set_next_chest(next_chest)
    return { type = ACT_CHECK_FARM_DEPOSIT_SET_NEXT_CHEST, next_chest = next_chest }
end

--- Sets the next chest to deposit at in the OBJ_DEPOSIT objective.
-- @param next_chest number the next chset to deposit at
-- @return the action which sets the next chest in the objective context
function farm.deposit_set_next_chest(next_chest)
    return { type = ACT_DEPOSIT_SET_NEXT_CHEST, next_chest = next_chest }
end

--- Initializes the farm context.
function farm.init()
    return {
        objective = OBJ_IDLE,
        context = {},
        farm_statuses = {}
    }
end

--- The reducer, which goes (state, action) -> state
function farm.reducer(raw, action)
    if action.type == ACT_SET_OBJECTIVE then
        local res = state.deep_copy(raw)
        res.objective = action.objective
        res.context = action.context
        return res
    elseif action.type == ACT_SET_SUB_OBJECTIVE then
        local res = state.deep_copy(raw)
        res.context.sub_objective = action.sub_objective
        res.context.sub_context = action.sub_context
        return res
    elseif action.type == ACT_CHECK_FARM_INCR_LOC_IND then
        local res = state.deep_copy(raw)
        res.context.loc_ind = res.context.loc_ind + 1
        return res
    elseif action.type == ACT_CHECK_FARM_FINISH then
        local res = state.deep_copy(raw)
        res.farm_statuses[raw.context.ind] = {
            checked_day = action.day,
            checked_time = action.time
        }
        res.objective = OBJ_IDLE
        res.context = {}
        return res
    elseif action.type == ACT_CHECK_FARM_DEPOSIT_SET_NEXT_CHEST then
        local res = state.deep_copy(raw)
        res.context.sub_context.next_chest = action.next_chest
        return res
    elseif action.type == ACT_DEPOSIT_SET_NEXT_CHEST then
        local res = state.deep_copy(raw)
        res.context.next_chest = action.next_chest
        return res
    end
    return raw
end

farm.actionator = {}
farm.discrimators = {}

--- Finds the day and time when the given farm (by index) was last checked. If
-- the farm was never checked, returns -1, 0
-- @param store state.Store the store of information to use
-- @param ind number the index in farms to check
-- @return checked_day: number, checked_time: number
function farm.get_last_update(store, ind)
    local stat = store.raw.farm.farm_statuses[ind]
    if stat then
        return stat.checked_day, stat.checked_time
    end
    return -1, 0
end

-- Determines if the given farm (by index) needs to be checked.
-- @param store state.Store the store of information to use
-- @param cfg table the config passed to farm.main
-- @param ind number the index in farms to consider
-- @return boolean true if the given farm needs to be checked, false otherwise
function farm.needs_check(store, cfg, ind)
    local checked_day, checked_time = farm.get_last_update(store, ind)

    if checked_day < 0 then return true end

    local cur_day = os.day()
    local cur_time = os.time()

    local delta_days = cur_day - checked_day
    local delta_time = cur_time - checked_time

    local minutes_since = delta_days * 20 + delta_time
    return minutes_since >= cfg.farms[ind].time_between_checks
end

--- Determines if the turtle should be refueled immediately, interrupting its
-- current task.
-- @param store state.Store the persistent data store
-- @param cfg table settings
-- @return boolean true if we should interrupt to refuel, false otherwise
function farm.needs_emergency_refuel(store, cfg)
    local fuel = turtle.getFuelLevel()
    if fuel ~= 'unlimited' and fuel <= REFUEL_AT then
        local turtle_loc = vector.new(
            store.raw.move_state.position.x,
            store.raw.move_state.position.y,
            store.raw.move_state.position.z
        )
        local rloc, rdir = home.make_relative(
            turtle_loc, store.raw.move_state.dir)

        local est_dist = SUB_REFUEL_FACTOR * paths.manhattan(
            rloc, cfg.fuel_chest
        )

        if fuel < SUB_REFUEL_MARGIN + est_dist then
            print('Emergency refueling')
            return true
        end
    end
    return false
end

--- Clears the memory table
function farm.clear_mem(mem)
    mem.current_path = nil
    mem.current_path_ind = nil
end

local function catchall_pred(data) return true end

--- Handles deposit objectives in a generic manner
-- @param store state.Store the persistent store
-- @param cfg table the farm settings
-- @param mem table the transient store
-- @param ctx table contains next_chest=number
-- @param set_next_fn function accepts a chest # and returns an action which
-- will set the next chest to that value. farm.check_farm_deposit_set_next_chest
-- or farm.deposit_set_next_chest typically
-- @return true if we are done depositing, false otherwise
function farm.deposit_stud(store, cfg, mem, ctx, set_next_fn)
    local chest_loc = nil
    local chest_pred = nil
    if ctx.next_chest <= #cfg.specific_chests then
        local spec_chest = cfg.specific_chests[ctx.next_chest]
        chest_loc = spec_chest.loc
        chest_pred = spec_chest.pred
        local _, cnt = inv.count_by_pred(chest_pred)
        if cnt <= 0 then
            farm.clear_mem(mem)
            store:dispatch(set_next_fn(ctx.next_chest + 1))
            return false
        end
    else
        chest_loc = cfg.excess_chest
        chest_pred = catchall_pred
        local _, cnt = inv.count_by_pred(chest_pred)
        if cnt <= 0 then
            return true
        end
    end

    if mem.current_path == nil then
        path_utils.set_path(store, mem, chest_loc, cfg.world, true, true)
    end

    if not path_utils.tick_path(store, mem, true) then
        local chest_dir = mem.current_path[#mem.current_path]
        local fn_ind = constants.MOVE_TO_FN_IND[chest_dir]

        local cons = turtle[constants.DROP_FN[fn_ind]]
        inv.consume_by_pred(chest_pred, cons)
        if ctx.next_chest < #cfg.specific_chests then
            -- ignore success/failure; we will put extra in excess chest
            -- if this chest was full. alternatively there may be many
            -- overlapping chests at various locations
            farm.clear_mem(mem)
            store:dispatch(set_next_fn(ctx.next_chest + 1))
            return false
        end

        local _, cnt = inv.count_by_pred(chest_pred)
        if cnt > 0 then
            textutils.slowPrint('excess chest is full!')
            textutils.slowPrint('empty it and I will try again in 60 seconds')
            os.sleep(60)
            return false
        end

        return true
    end
    return false
end

--- Handles refuel objectives in a generic manner.
-- @param store state.Store the persistent store
-- @param cfg table the farm settings
-- @param mem table the transient store
-- @return true if we are done refueling, false otherwise
function farm.refuel_stud(store, cfg, mem)
    local fuel = turtle.getFuelLevel()
    if fuel == 'unlimited' or fuel > REFUEL_AT then
        return true
    end

    if mem.current_path == nil then
        path_utils.set_path(store, mem, cfg.fuel_chest,
                            cfg.world, true, true)
    end

    if not path_utils.tick_path(store, mem, true) then
        local chest_dir = mem.current_path[#mem.current_path]
        local fn_ind = constants.MOVE_TO_FN_IND[chest_dir]
        if not inv.select_empty() then
            -- this basically requires someone is messing with turtles
            -- inventory or fuel chest contains non-fuel
            print('need inventory to refuel')
            print('throwing something')
            local another_fn_ind = fn_ind + 1
            if another_fn_ind > #constants.DROP_FN then
                another_fn_ind = 1
            end
            turtle[constants.DROP_FN[another_fn_ind]]()
        end

        local succ = turtle[constants.SUCK_FN[fn_ind]]()
        if not succ then
            textutils.slowPrint('out of fuel! there should be a chest')
            textutils.slowPrint('at ' .. tostring(chest_dir))
            textutils.slowPrint('with fuel (typically coal/charcoal)')
            textutils.slowPrint('waiting 30 seconds and retrying')
            os.sleep(30)
            return false
        end

        if not turtle.refuel() then
            textutils.slowPrint('got bad fuel source!')
            textutils.slowPrint('waiting 30 seconds and trying again')
            os.sleep(30)
            return false
        end
    end
    return false
end

farm.CHECK_SUB_TICKERS = {
    [SUB_OBJ_DEPOSIT] = function(store, cfg, mem, ctx)
        if farm.deposit_stud(store, cfg, mem, ctx,
                             farm.check_farm_deposit_set_next_chest) then
            farm.clear_mem(mem)
            store:dispatch(farm.set_sub_objective(SUB_OBJ_RESTOCK, nil))
        end
    end,
    [SUB_OBJ_REFUEL] = function(store, cfg, mem)
        if farm.refuel_stud(store, cfg, mem) then
            farm.clear_mem(mem)
            store:dispatch(move_state.update_fuel())
            store:dispatch(farm.set_sub_objective(SUB_OBJ_CHECK, nil))
        end
    end,
    [SUB_OBJ_RESTOCK] = function(store, cfg, mem)
        local par_ctx = store.raw.farm.context
        local farm_ind = par_ctx.ind
        local farm_info = cfg.farms[farm_ind]
        local seed_info = cfg.seeds[farm_info.seed]

        if not seed_info.has_seed then
            -- happens after deposit
            farm.clear_mem(mem)
            store:dispatch(farm.set_sub_objective(SUB_OBJ_CHECK, nil))
            return
        end

        local _, cnt = inv.count_by_pred(seed_info.pred)
        if cnt > 0 then
            farm.clear_mem(mem)
            store:dispatch(farm.set_sub_objective(SUB_OBJ_CHECK, nil))
            return
        end

        if farm.needs_emergency_refuel(store, cfg) then
            farm.clear_mem(mem)
            store:dispatch(farm.set_sub_objective(SUB_OBJ_REFUEL, nil))
            return
        end

        if inv.count_empty() < 1 then
            farm.clear_mem(mem)
            store:dispatch(farm.set_sub_objective(SUB_OBJ_DEPOSIT, {next_chest=1}))
            return
        end

        if mem.current_path == nil then
            path_utils.set_path(store, mem, seed_info.chest,
                                cfg.world, true, true)
        end

        if not path_utils.tick_path(store, mem, true) then
            local chest_dir = mem.current_path[#mem.current_path]
            local fn_ind = constants.MOVE_TO_FN_IND[chest_dir]

            local succ = turtle[constants.SUCK_FN[fn_ind]]()
            if not succ then
                textutils.slowPrint('failed to get seeds')
                textutils.slowPrint('there should be a chest at ' .. chest_dir)
                textutils.slowPrint('that contains seeds for farm #' .. farm_ind)
                textutils.slowPrint('sleeping 30 seconds and retrying')
                os.sleep(30)
                return
            end
        end
    end,
    [SUB_OBJ_CHECK] = function(store, cfg, mem)
        local par_ctx = store.raw.farm.context
        local farm_ind = par_ctx.ind
        local loc_ind = par_ctx.loc_ind
        local farm_info = cfg.farms[farm_ind]
        local seed_info = cfg.seeds[farm_info.seed]
        local loc = farm_info.locs[loc_ind]

        if mem.current_path == nil then
            -- check fuel
            if farm.needs_emergency_refuel(store, cfg) then
                farm.clear_mem(mem)
                store:dispatch(farm.set_sub_objective(SUB_OBJ_REFUEL, nil))
                return
            end

            -- check deposit
            local num_empty = inv.count_empty()
            if num_empty < 1 then
                inv.combine_stacks()
                num_empty = inv.count_empty()
                if num_empty < 1 then
                    print('Ran out of inventory space, depositing')
                    farm.clear_mem(mem)
                    store:dispatch(farm.set_sub_objective(SUB_OBJ_DEPOSIT, {next_chest=1}))
                    return
                end
            end

            -- check seeds
            if seed_info.has_seed then
                local _, num_seeds = inv.count_by_pred(seed_info.pred)
                if num_seeds <= 0 then
                    print('Restocking seeds')
                    farm.clear_mem(mem)
                    store:dispatch(farm.set_sub_objective(SUB_OBJ_RESTOCK, nil))
                    return
                end
            end

            -- set loc
            if not path_utils.set_path(store, mem, loc, cfg.world, true, true) then
                textutils.slowPrint('having trouble finding a path')
                os.sleep(30)
                return
            end
        end

        if not path_utils.tick_path(store, mem, true) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            farm.clear_mem(mem)

            local succ, data = turtle[constants.INSPECT_FN[fn_ind]]()
            if not succ or seed_info.checker(data) then
                local dig_fn = turtle[constants.DIG_FN[fn_ind]]
                if succ then
                    turtle.select(1)
                    dig_fn() -- break
                end

                if seed_info.has_seed then
                    dig_fn() -- hoe
                    local sel_succ, _ = inv.select_by_pred(seed_info.pred)
                    if sel_succ then
                        turtle[constants.PLACE_FN[fn_ind]]()
                    end
                end
            end

            if loc_ind < #farm_info.locs then
                store:dispatch(farm.check_farm_incr_loc_ind())
            else
                store:dispatch(farm.check_farm_finish())
            end
        end
    end
}

farm.TICKERS = {
    [OBJ_CHECK_FARM] = function(store, cfg, mem, ctx)
        farm.CHECK_SUB_TICKERS[ctx.sub_objective](
            store, cfg, mem, ctx.sub_context)
    end,
    [OBJ_DEPOSIT] = function(store, cfg, mem, ctx)
        if farm.deposit_stud(store, cfg, mem, ctx,
                             farm.deposit_set_next_chest) then
            farm.clear_mem(mem)
            store:dispatch(farm.set_objective(OBJ_IDLE, {}))
        end
    end,
    [OBJ_REFUEL] = function(store, cfg, mem)
        if farm.refuel_stud(store, cfg, mem) then
            farm.clear_mem(mem)
            store:dispatch(move_state.update_fuel())
            store:dispatch(farm.set_objective(OBJ_IDLE, {}))
        end
    end,
    [OBJ_IDLE] = function(store, cfg, mem)
        -- check refuel #1
        if farm.needs_emergency_refuel(store, cfg) then
            farm.clear_mem(mem)
            store:dispatch(farm.set_objective(OBJ_REFUEL, {}))
            return
        end

        -- check deposit
        if inv.count_empty() < 16 then
            farm.clear_mem(mem)
            store:dispatch(farm.set_objective(OBJ_DEPOSIT, {next_chest=1}))
            return
        end

        -- check refuel #2
        local fuel = turtle.getFuelLevel()
        if fuel ~= 'unlimited' and fuel < REFUEL_AT then
            farm.clear_mem(mem)
            store:dispatch(farm.set_objective(OBJ_REFUEL, {}))
            return
        end

        -- check for farm
        for i=1, #cfg.farms do
            if farm.needs_check(store, cfg, i) then
                farm.clear_mem(mem)
                store:dispatch(farm.set_objective(OBJ_CHECK_FARM, {
                    ind=i,
                    loc_ind=1,
                    sub_objective=SUB_OBJ_RESTOCK,
                    sub_context=nil
                }))
                return
            end
        end

        -- chill at home
        if mem.current_path ~= nil then
            if not path_utils.tick_path(store, mem, true) then
                farm.clear_mem(mem)
                os.sleep(30)
                return
            end
        end

        local cur_loc = vector.new(
            store.raw.move_state.position.x,
            store.raw.move_state.position.y,
            store.raw.move_state.position.z
        )
        local hloc, hdir = home.loc()

        if (cur_loc.x == hloc.x
                and cur_loc.y == hloc.y
                and cur_loc.z == hloc.z) then
            os.sleep(10)
            return
        end

        path_utils.set_path(store, mem, vector.new(0, 0, 0),
                            cfg.world, true, true)
    end
}

--- Ticks the farm, typically dispatching a single action or sleeping.
-- @param store state.Store the store of persistent data
-- @param cfg table the settings for the current farm
-- @param mem table the store of transient data
function farm.tick(store, cfg, mem)
    local ctx = store.raw.farm.context
    farm.TICKERS[store.raw.farm.objective](store, cfg, mem, ctx)
end

--- This is the main exported function for maintaining one or more farms which
-- act like wheat. Each of the parameters defines the structure around the
-- turtle, and they should all use relative locations. You should use startup
-- to inject your program before calling this function (startup will prevent
-- duplicates)
--
-- @param seeds table array-like where each item is
-- {has_seed=boolean, chest=vector, pred=function, checker=function}. if
-- has_seed is false (pumpkins, melons), pred and chest is ignored. chest is
-- the location of the chest to acquire the seeds. pred is a function which
-- accepts the result of turtle.getItemDetail and the result is true if that
-- corresponds to the seed and false otherwise. checker is a function which
-- accepts the successful result of turtle.inspect() and returns if it should
-- be cut (either ready to harvest or not a seed)
-- @param farms table this is an array-like table where each of the values
-- is a table of the form
-- {seed=int, time_between_checks=number, locs={}}
-- where the seed is the index in seeds. The locs is a list of vectors
-- for where seeds of this type go. The time_between_checks is minutes between
-- checking the farm.
-- @param specific_chests table an array-like table where each element is a
-- table of the form { pred = function, loc = vector } where the predicate is
-- a function which accepts the result of turtle.getItemDetail and returns true
-- if the item belongs in the chest, false otherwise. loc is the location of
-- the chest. More specific chests should be earlier in the list; an excess
-- chest is defined explitly elsewhere
-- @param fuel_chest vector where we can get more fuel
-- @param excess_chest vector where we store items we don't recognize
-- @param world table the keys are tostring'd vectors and the values are true.
-- these are the locations we can freely pass through. Must be enough to
-- connect us to all the seeds & chsts.
function farm.main(seeds, farms, specific_chests, fuel_chest, excess_chest,
                   world)
    local cfg = {
        seeds = seeds,
        farms = farms,
        specific_chests = specific_chests,
        fuel_chest = fuel_chest,
        excess_chest = excess_chest,
        world = world
    }
    local mem = {
        current_path = nil,
        current_path_ind = nil,
    }

    home.loc()

    local r, a, d, i = state.combine(
        {
            move_state=move_state.reducer,
            farm=farm.reducer
        },
        {
            move_state=move_state.actionator,
            farm=farm.actionator
        },
        {
            move_state=move_state.discriminators,
            farm=farm.discriminators
        },
        {
            move_state=move_state.init,
            farm=farm.init
        }
    )

    local store = state.Store:recover('farm_store', r, a, d, i)
    home.loc() -- ensure initialized
    store:dispatch(move_state.update_fuel())
    store:clean_and_save()

    local mem = {}
    while true do
        farm.tick(store, cfg, mem)
    end
end

return farm
