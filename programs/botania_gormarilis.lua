--- This turtle is intended as a simple way to automate the gourmaryllis flower from botania
--- Setup:
---   Place the turtle facing the food chest
---   Place two gourmaryllis, on the left and right side of the turtle
---   Make sure the turtle has at least 2 fuel
package.path = '../?.lua;turtles2/?.lua'

local state = require('utils/state')
local startup = require('utils/startup')
local inv = require('utils/inv')
local move_state = require('utils/move_state')
local path_utils = require('utils/path_utils')
local paths = require('utils/paths')
local constants = require('utils/constants')
local home = require('utils/home')

--- Objectives
local OBJ_IDLE = 'idle'
local OBJ_ACQUIRE_FOOD = 'acquire'
local OBJ_DROP_FOOD = 'drop'

-- Actions
local ACT_SET_OBJECTIVE = 'set_objective'

-- Locations
local WORLD = {
    [tostring(vector.new(0, 0, 0))] = true
}
local FOOD_CHEST_LOC = vector.new(0, 0, 1)
local FLOWER_LOCS = {vector.new(1, 0, 0), vector.new(-1, 0, 0)}
local FOOD_ITEMS = {
    inv.new_pred_by_name_lookup({
        ['minecraft:bread'] = true,
    }),
    inv.new_pred_by_name_lookup({
        ['minecraft:baked_potato'] = true,
    }),
    inv.new_pred_by_name_lookup({
        ['minecraft:carrot'] = true,
    }),
    inv.new_pred_by_name('minecraft:mushroom_stew')
}

local function set_objective(obj, ctx)
    return {
        type = ACT_SET_OBJECTIVE,
        objective = obj,
        context = ctx
    }
end

local function cust_init()
    local raw = {}
    raw.objective = 'idle'
    raw.context = nil
    raw.last_food_index_by_plant_index = {}
    raw.next_feed_index = 1
    return raw
end

local function cust_reducer(raw, action)
    if action.type == ACT_SET_OBJECTIVE then
        raw = state.deep_copy(raw)
        raw.objective = state.deep_copy(action.objective)
        raw.context = state.deep_copy(action.context)
        return raw
    end
    return raw
end

local cust_actionator = {}
local cust_discriminators = {}



local function set_path(store, mem, rdest)
    return path_utils.set_path(store, mem, rdest, WORLD, true, true)
end

local function tick_path(store, mem)
    return path_utils.tick_path(store, mem, true)
end

local function clear_mem(mem)
    if mem == nil then
        error('mem nil', 2)
    end
    mem.current_path = nil
    mem.current_path_ind = nil
end

local function idle(store, mem)
    store:dispatch(set_objective(OBJ_IDLE, nil))
    clear_mem(mem)
end

local function desired_food_for_plant(store, mem, plant_index)
    -- return some food item that wasnt last eaten
    local last_fed = store.raw.gorm.last_food_index_by_plant_index[plant_index]
    local current_item = last_fed or 1
    for i = 1, #FOOD_ITEMS do
        current_item = (current_item % #FOOD_ITEMS) + 1
        if current_item == last_fed then return nil end
        if inv.select_by_pred(FOOD_ITEMS[current_item]) then
            return current_item
        end
    end
    return nil
end

local OBJECTIVE_TICKERS = {
    [OBJ_IDLE] = function(store, mem)
        if not desired_food_for_plant(store, mem, store.raw.gorm.next_feed_index) then
            store:dispatch(set_objective(OBJ_ACQUIRE_FOOD, nil))
            clear_mem(mem)
            return
        end
        store:dispatch(set_objective(OBJ_DROP_FOOD, nil))
        clear_mem(mem)
    end,
    [OBJ_ACQUIRE_FOOD] = function(store, mem)
        if mem.current_path == nil then set_path(store, mem, FOOD_CHEST_LOC) end
        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local suck_fn = constants.SUCK_FN[fn_ind]
            while true do
                if not turtle[suck_fn]() then
                    textutils.slowPrint('add varied food')
                    os.sleep(30)
                    return
                end
                if desired_food_for_plant(store, mem, store.raw.gorm.next_feed_index) then
                    store:dispatch(set_objective(OBJ_DROP_FOOD, nil))
                    clear_mem(mem)
                    return
                end
            end
        end
    end,
    [OBJ_DROP_FOOD] = function(store, mem)
        local plant_index = store.raw.gorm.next_feed_index
        local food_index = desired_food_for_plant(store, mem, plant_index)
        if not food_index then
            idle(store, mem)
            return
        end
        if mem.current_path == nil then set_path(store, mem, FLOWER_LOCS[plant_index]) end
        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local drop_fn = constants.DROP_FN[fn_ind]
            turtle[drop_fn](1)
            store.raw.gorm.next_feed_index = (plant_index % #FLOWER_LOCS) + 1
            store.raw.gorm.last_food_index_by_plant_index[plant_index] = food_index
            os.sleep(2.5 / #FLOWER_LOCS)
            clear_mem(mem)
        end
    end
}

local function tick(store, mem)
    OBJECTIVE_TICKERS[store.raw.gorm.objective](store, mem)
end

local function main()
    startup.inject('programs/botania_gormarilis')
    home.loc()

    local r, a, d, i = state.combine(
        {
            move_state=move_state.reducer,
            gorm=cust_reducer,
        },
        {
            move_state=move_state.actionator,
            gorm=cust_actionator,
        },
        {
            move_state=move_state.discriminators,
            gorm=cust_discriminators,
        },
        {
            move_state=move_state.init,
            gorm=cust_init,
        }
    )

    local store = state.Store:recover('gorm_store', r, a, d, i)
    store:dispatch(move_state.update_fuel())
    store:clean_and_save()

    local mem = {}
    while true do
        tick(store, mem)
    end
end

main()
