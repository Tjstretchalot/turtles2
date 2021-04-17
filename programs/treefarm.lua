---
-- A tree farm capable of handling standard minecraft trees (except dark oak)
-- and rubber trees.
--
-- Setup:
--   Place a wireless mining turtle somewhere with GPS availability.
--
--   From the perspective of behind the turtle, facing the turtle. Beneath
--   the turtle is the chest that the turtle will deposit wood, which should
--   be empty at the start. To the right of wood chest is a space, then right
--   of that space is the sapling chest.
--
--   If fuel is enabled, right of the sapling chest is a space followed by
--   a chest with burnables in it. Make sure the turtle has some fuel to
--   start (at least 4)
--
--   In front of the turtle is a space, followed by a space, followed by a space
--   below which is the bottom-left dirt. There are 3 spaces in front of the dirt,
--   followed by another piece of dirt. Similarly, 3 spaces right of the bottom-
--   left dirt then dirt. This completes a 3x3 grid of dirt. These are where the
--   saplings will go.
--
--   Then setup a way for dropped saplings from trees planted on these pieces of
--   dirt to be placed in the sapling chest.
--
--   There should be at least 7 empty spaces above the turtle across the entire
--   farm.
--
--   Each tree is checked once per day, starting the day after it is planted.
--
---  cd turtles2/
--   programs/treefarm.lua

local SAPLING_NAMES = {
    ['minecraft:sapling'] = true,
    ['minecraft:birch_sapling'] = true,
    ['IC2:blockRubSapling'] = true
}

local GROWTHS = {
    ['minecraft:log'] = true,
    ['minecraft:birch_log'] = true,
    ['minecraft:birch_leaves'] = true,
    ['minecraft:log2'] = true,
    ['IC2:blockRubWood'] = true,
    ['IC2:blockRubLeaves'] = true,
    ['minecraft:leaves'] = true,
    ['minecraft:leaves2'] = true,
    ['minecraft:vines'] = true
}

local RESTOCK_SAPLINGS_AT = 9
local RESTOCK_SAPLINGS_TO = 18
local REFUEL_AT = 800

local WOOD_CHEST = vector.new(0, -1, 0)
local SAPLING_CHEST = vector.new(-2, -1, 0)
local FUEL_CHEST = vector.new(-4, -1, 0)

local SAPLINGS = {
    vector.new(0, 0, 3),
    vector.new(0, 0, 7),
    vector.new(0, 0, 11),
    vector.new(-4, 0, 3),
    vector.new(-4, 0, 7),
    vector.new(-4, 0, 11),
    vector.new(-8, 0, 3),
    vector.new(-8, 0, 7),
    vector.new(-8, 0, 11)
}

local SAPLINGS_LOOKUP = {}
for k, v in ipairs(SAPLINGS) do
    SAPLINGS_LOOKUP[tostring(v)] = true
end

local WORLD = {} -- contains spaces we can dig
for x = 0, -8, -1 do
    for z = 0, 11, 1 do
        for y = 0, 8, 1 do
            local key = tostring(vector.new(x, y, z))
            WORLD[key] = true
        end
    end
end

-- avoid walking through saplings or above them
for _, loc in ipairs(SAPLINGS) do
    for dy=0, 8, 1 do
        local nvec = vector.new(loc.x, loc.y + dy, loc.z)
        WORLD[tostring(nvec)] = nil
    end
end

--- Custom store:
--
-- {
--    objective: string
--    trees: { 1: { planted_time: number|nil, planted_day: number|nil}, ...}
--    context: table|nil
-- }

package.path = '../?.lua;turtles2/?.lua'
local ores = require('utils/ores')
local home = require('utils/home')
local state = require('utils/state')
local move_state = require('utils/move_state')
local startup = require('utils/startup')
local paths = require('utils/paths')
local constants = require('utils/constants')
local path_utils = require('utils/path_utils')
local inv = require('utils/inv')

-- Objectives
local OBJ_IDLE = 'idle' -- Nothing to do
local OBJ_REFUEL = 'refuel' -- Get fuel from fuel chest
local OBJ_DEPOSIT = 'deposit' -- Deposit materials into wood chest
local OBJ_RESTOCK = 'restock' -- Restock saplings from sapling chest
local OBJ_CHECK_TREE = 'check_tree' -- Check a particular tree
local OBJ_HARVEST = 'harvest' -- Continue to harvest current tree (use ores)

-- Actions
local ACT_SET_OBJECTIVE = 'set_objective'
local ACT_PLANT_TREE = 'plant_tree'
local ACT_HARVEST_TREE = 'harvest_tree'

local function set_objective(obj, ctx)
    return {
        type = ACT_SET_OBJECTIVE,
        objective = obj,
        context = ctx
    }
end

local function plant_tree(ind)
    return {
        type = ACT_PLANT_TREE,
        ind = ind,
        time = os.time(),
        day = os.day()
    }
end

local function harvest_tree(ind)
    return {
        type = ACT_HARVEST_TREE,
        ind = ind,
    }
end

local function cust_init()
    local raw = {}
    raw.objective = 'idle'
    raw.trees = {}
    for k, _ in ipairs(SAPLINGS) do
        raw.trees[k] = {}
    end
    raw.context = nil
    return raw
end

local function cust_reducer(raw, action)
    if action.type == ACT_SET_OBJECTIVE then
        raw = state.deep_copy(raw)
        raw.objective = state.deep_copy(action.objective)
        raw.context = state.deep_copy(action.context)
        return raw
    elseif action.type == ACT_PLANT_TREE then
        raw = state.deep_copy(raw)
        raw.trees[action.ind] = {
            planted_time = action.time,
            planted_day = action.day
        }
        return raw
    elseif action.type == ACT_HARVEST_TREE then
        raw = state.deep_copy(raw)
        raw.trees[action.ind] = {}
        return raw
    end
    return raw
end

-- Handles coupled reducing components. When setting the objective
-- we also clear the ore state. If one occurred without the other,
-- corruption is possible.
local function reduce_wrapper(reducer)
    return function(raw, action)
        local res = reducer(raw, action)
        if action.type == ACT_SET_OBJECTIVE then
            res = state.deep_copy(res)
            res.ores = ores.init()
        end
        return res
    end
end

local cust_actionator = {}
local cust_discriminators = {}

local function ores_filter(data)
    return not not GROWTHS[data.name]
end

local function set_path(store, mem, rdest)
    return path_utils.set_path(store, mem, rdest, WORLD, true, true)
end

local function tick_path(store, mem)
    return path_utils.tick_path(store, mem, true)
end

local select_empty = inv.select_empty

local function select_to_deposit()
    local sapling_cnt = 0

    for i=1, 16 do
        local data = turtle.getItemDetail(i)
        if data then
            if not SAPLING_NAMES[data.name] then
                turtle.select(i)
                return true
            else
                if sapling_cnt > RESTOCK_SAPLINGS_TO then
                    turtle.select(i)
                    return true
                end
                sapling_cnt = sapling_cnt + data.count
            end
        end
    end
    return false
end

local function select_count_saplings()
    local empty = nil
    local sm = 0
    for i=1, 16 do
        local data = turtle.getItemDetail(i)
        if data == nil then
            if empty == nil then empty = i end
        elseif SAPLING_NAMES[data.name] then
            if sm == 0 then
                turtle.select(i)
            end
            sm = sm + data.count
        end
    end
    if sm > 0 then
        return true, sm
    end

    if empty ~= nil then
        turtle.select(empty)
        return true, 0
    end
    return false, 0
end

local count_empty_slots = inv.count_empty

local function clear_mem(mem)
    if mem == nil then
        error('mem nil', 2)
    end
    mem.current_path = nil
    mem.current_path_ind = nil
    mem.ore_ctx = nil
end

local function idle(store, mem)
    store:dispatch(set_objective(OBJ_IDLE, nil))
    clear_mem(mem)
end

local function decide_check_tree(store, mem)
    for ind, inf in ipairs(store.raw.treefarm.trees) do
        if not inf.planted_day or inf.planted_day < os.day() then
            print('Checking tree ' .. tostring(ind))
            clear_mem(mem)
            store:dispatch(set_objective(OBJ_CHECK_TREE, {ind=ind}))
            return true
        end
    end
    return false
end

local OBJECTIVE_TICKERS = {
    [OBJ_REFUEL] = function(store, mem)
        local fuel = turtle.getFuelLevel()
        if fuel == 'unlimited' or fuel > REFUEL_AT then
            store:dispatch(move_state.update_fuel())
            idle(store, mem)
            return
        end

        if mem.current_path == nil then set_path(store, mem, FUEL_CHEST) end
        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local suck_fn = constants.SUCK_FN[fn_ind]
            if not select_empty() then
                textutils.slowPrint('Filled inventory during refuel attempt!')
                textutils.slowPrint('Empty inventory & reboot/wait a minute')
                os.sleep(60)
                return
            end
            if not turtle[suck_fn]() then
                textutils.slowPrint('Nothing to use as fuel available!')
                textutils.slowPrint('Add some fuel to fuel chest and reboot/wait a minute')
                textutils.slowPrint('Fuel chest should be me+' .. mem.current_path[#mem.current_path])
                os.sleep(60)
                return
            end
            if not turtle.refuel() then
                textutils.slowPrint('Got bad fuel from fuel chest!')
                os.sleep(60)
                return
            end
            store:dispatch(move_state.update_fuel())
        end
    end,
    [OBJ_DEPOSIT] = function(store, mem)
        if not select_to_deposit() then
            idle(store, mem)
            return
        end

        if mem.current_path == nil then set_path(store, mem, WOOD_CHEST) end
        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local drop_fn = constants.DROP_FN[fn_ind]
            if not turtle[drop_fn]() then
                textutils.slowPrint('Deposit chest is full! Waiting 30 seconds..')
                os.sleep(30)
                return
            end
        end
    end,
    [OBJ_RESTOCK] = function(store, mem)
        local succ, cnt = select_count_saplings()
        if not succ or cnt >= RESTOCK_SAPLINGS_AT then
            idle(store, mem)
            return
        end

        if mem.current_path == nil then set_path(store, mem, SAPLING_CHEST) end
        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local suck_fn = constants.SUCK_FN[fn_ind]
            if not turtle[suck_fn](RESTOCK_SAPLINGS_TO - cnt) then
                textutils.slowPrint('Sapling chest is empty! Waiting 30 seconds..')
                os.sleep(30)
                return
            end
        end
    end,
    [OBJ_CHECK_TREE] = function(store, mem)
        local ind = store.raw.treefarm.context.ind

        if mem.current_path == nil then
            set_path(store, mem, SAPLINGS[ind])
        end
        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local inspect_fn = constants.INSPECT_FN[fn_ind]
            select_count_saplings()
            local succ, data = turtle[inspect_fn]()
            if succ then
                if SAPLING_NAMES[data.name] then
                    store:dispatch(plant_tree(ind))
                    idle(store, mem)
                    return
                end

                clear_mem(mem)
                store:dispatch(set_objective(OBJ_HARVEST, {ind = ind}))
                return
            end
            local cnt
            succ, cnt = select_count_saplings()
            if not succ then
                idle(store, mem)
                return
            end

            local place_fn = constants.PLACE_FN[fn_ind]
            if not turtle[place_fn]() then
                textutils.slowPrint('Failed to place sapling, likely monster. Waiting..')
                os.sleep(30)
                return
            end

            store:dispatch(plant_tree(ind))
            idle(store, mem)
            return
        end
    end,
    [OBJ_HARVEST] = function(store, mem)
        if not store.raw.ores.initialized then
            store:dispatch(ores.set_start_to_cur(store))
        end

        if mem.ore_ctx == nil then
            mem.ore_ctx = {}
        end

        if not ores.tick(store, mem.ore_ctx, 'ores', ores_filter) then
            local ind = store.raw.treefarm.context.ind
            store:dispatch(harvest_tree(ind)) -- ok to repeat this
            idle(store, mem) -- this uninitializes ores safely
        end
    end,
    [OBJ_IDLE] = function(store, mem)
        local fuel = turtle.getFuelLevel()
        local n_empty = count_empty_slots()

        if fuel == 0 then
            textutils.slowPrint('Turtle ran out of fuel. '
                  .. ' Terminate the program (Ctrl+T), '
                  .. ' refuel (help refuel), then reboot (Ctrl+R)')
            os.sleep(60)
            return
        end

        if n_empty == 0 then
            print('Depositing items...')
            store:dispatch(set_objective(OBJ_DEPOSIT, nil))
            return
        end

        if fuel < REFUEL_AT then
            print('Refueling...')
            store:dispatch(set_objective(OBJ_REFUEL, nil))
            return
        end

        if n_empty < 4 then
            print('Depositing items...')
            store:dispatch(set_objective(OBJ_DEPOSIT, nil))
            return
        end

        local succ, cnt = select_count_saplings()
        if not succ or cnt < RESTOCK_SAPLINGS_AT then
            print('Restocking saplings...')
            store:dispatch(set_objective(OBJ_RESTOCK, nil))
            return
        end

        if decide_check_tree(store, mem) then return end

        if select_to_deposit() then
            print('Depositing items...')
            store:dispatch(set_objective(OBJ_DEPOSIT, nil))
            return
        end

        os.sleep(10)
    end
}
local function tick(store, mem)
    OBJECTIVE_TICKERS[store.raw.treefarm.objective](store, mem)
end

local function main()
    startup.inject('programs/treefarm.lua')

    local r, a, d, i = state.combine(
        {
            move_state=move_state.reducer,
            ores=ores.reducer,
            treefarm=cust_reducer
        },
        {
            move_state=move_state.actionator,
            ores=ores.actionator,
            treefarm=cust_actionator
        },
        {
            move_state=move_state.discriminators,
            ores=ores.discriminators,
            treefarm=cust_discriminators
        },
        {
            move_state=move_state.init,
            ores=ores.init,
            treefarm=cust_init
        }
    )

    r = reduce_wrapper(r)

    local store = state.Store:recover('treefarm_store', r, a, d, i)
    home.loc() -- ensure initialized
    store:dispatch(move_state.update_fuel())
    store:clean_and_save()

    local mem = {}
    while true do
        tick(store, mem)
    end
end

main()
