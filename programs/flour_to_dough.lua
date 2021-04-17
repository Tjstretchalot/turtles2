--- This program is for the mod "The Veggie Way" which adds flour
-- and dough as an alternative path to bread from wheat which is
-- more efficient. This also works with a similar recipe added by
-- Create with Wheat Dough
--
-- The normal way to get bread is 3 wheat -> 1 bread.
-- The Veggie Way to get bread is 1 wheat -> 1 flour with
-- a Mill, then 1 flour -> 1 dough using a bucket, then
-- 1 dough -> 1 bread. The flour -> dough step is tedious and
-- this automates it using a turtle!
--
-- Setup:

-- - Place the crafty turtle. The remainder of the steps are from someone behind
--   the turtle facing the same direction as the turtle.
-- - Directly in front of the turtle should be a water source block that
--   replenishes itself.
-- - Above the turtle should be the input chest, where you put in flour
-- - To the right of the turtle should be the output chest, where the turtle
--   will put dough.
-- - Put an empty bucket or water bucket in the turtles inventory, anywhere

package.path = '../?.lua;turtles2/?.lua'
local state = require('utils/state')
local startup = require('utils/startup')
local inv = require('utils/inv')
local move_state = require('utils/move_state')
local path_utils = require('utils/path_utils')
local paths = require('utils/paths')
local constants = require('utils/constants')
local home = require('utils/home')

--- Constants
local BUCKET_PRED = inv.new_pred_by_name_lookup({
    ['minecraft:bucket'] = true,
    ['minecraft:water_bucket'] = true
})

local EMPTY_BUCKET_PRED = inv.new_pred_by_name_lookup({
    ['minecraft:bucket'] = true
})

local FILLED_BUCKET_PRED = inv.new_pred_by_name_lookup({
    ['minecraft:water_bucket'] = true
})

local FLOUR_PRED = inv.new_pred_by_name_lookup({
    ['veggie_way:flour'] = true,
    ['minecraft:wheat'] = true,
})

local OUTPUT_PRED = inv.new_pred_by_inv_name_lookup({
    ['minecraft:bucket'] = true,
    ['minecraft:water_bucket'] = true,
    ['veggie_way:flour'] = true,
    ['minecraft:wheat'] = true,
})

local OUTPUT_TARGETS = {
    {BUCKET_PRED, 1},
    {FLOUR_PRED, 64}
}

local FLOUR_CHEST_LOC = vector.new(0, 1, 0)
local DOUGH_CHEST_LOC = vector.new(-1, 0, 0)
local WATER_SOURCE_LOC = vector.new(0, 0, 1)

local WORLD = {
    [tostring(vector.new(0, 0, 0))] = true
}

-- Objectives
local OBJ_IDLE = 'idle'  -- Nothing to do
local OBJ_DEPOSIT = 'deposit'  -- Deposit dough
local OBJ_ACQUIRE = 'acquire'  -- Pickup one flour
local OBJ_CRAFT = 'craft'  -- Craft flour into dough
local OBJ_FILL_BUCKET = 'fill_bucket'  -- Fill the bucket

-- Actions
local ACT_SET_OBJECTIVE = 'set_objective'

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

local function try_craft_veggie_way(store, mem)
    local firstTwoEmptySlots = {}
    for _, i in ipairs(constants.CRAFTING_SLOTS) do
        if turtle.getItemCount(i) == 0 then
            table.insert(firstTwoEmptySlots, i)
            if #firstTwoEmptySlots == 2 then break end
        end
    end

    if #firstTwoEmptySlots ~= 2 then
        idle(store, mem)
        return
    end

    if not inv.select_by_pred(FLOUR_PRED) then
        idle(store, mem)
        return
    end
    if not constants.CRAFTING_SLOT_LOOKUP[turtle.getSelectedSlot()] then
        turtle.transferTo(firstTwoEmptySlots[1])
    end

    if not inv.select_by_pred(FILLED_BUCKET_PRED) then
        idle(store, mem)
        return
    end
    if not constants.CRAFTING_SLOT_LOOKUP[turtle.getSelectedSlot()] then
        turtle.transferTo(firstTwoEmptySlots[2])
    end

    if not turtle.craft() then
        idle(store, mem)
        return
    end

    clear_mem(mem)
    store:dispatch(set_objective(OBJ_FILL_BUCKET, nil))
end

local function try_craft_create(store, mem)
    if not inv.select_by_pred(FILLED_BUCKET_PRED) then
        idle(store, mem)
        return
    end
    turtle.transferTo(2)

    local succ, data = inv.select_by_pred(FLOUR_PRED)

    if not succ or data.count < 3 then
        idle(store, mem)
        return
    end

    local selected = turtle.getSelectedSlot()
    if selected ~= 5 then turtle.transferTo(5, 1) end
    if selected ~= 6 then turtle.transferTo(6, 1) end
    if selected ~= 7 then turtle.transferTo(7, 1) end

    if selected ~= 5 and selected ~= 6 and selected ~= 7 then
        turtle.transferTo(5)
    end

    if not turtle.craft() then
        idle(store, mem)
        return
    end

    inv.combine_stacks()

    clear_mem(mem)
    store:dispatch(set_objective(OBJ_FILL_BUCKET, nil))
end


local OBJECTIVE_TICKERS = {
    [OBJ_IDLE] = function(store, mem)
        local _, outputs = inv.count_by_pred(OUTPUT_PRED)
        if outputs > 0 then
            store:dispatch(set_objective(OBJ_DEPOSIT, nil))
            return
        end

        local _, buckets = inv.count_by_pred(BUCKET_PRED)
        if buckets > 1 then
            store:dispatch(set_objective(OBJ_DEPOSIT, nil))
            return
        end

        local _, flour = inv.count_by_pred(FLOUR_PRED)
        if flour > 64 then
            store:dispatch(set_objective(OBJ_DEPOSIT, nil))
            return
        end

        local empty_inventory_slots = inv.count_empty()
        if empty_inventory_slots < 14 then
            inv.combine_stacks()
            os.sleep(1)
            return
        end

        local _, empty_buckets = inv.count_by_pred(EMPTY_BUCKET_PRED)
        if empty_buckets > 0 then
            store:dispatch(set_objective(OBJ_FILL_BUCKET))
            return
        end

        -- we must have a filled bucket
        if flour > 0 then
            store:dispatch(set_objective(OBJ_CRAFT))
            return
        end

        store:dispatch(set_objective(OBJ_ACQUIRE))
    end,
    [OBJ_DEPOSIT] = function(store, mem)
        if mem.current_path == nil then
            set_path(store, mem, DOUGH_CHEST_LOC)
        end

        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local drop_fn = constants.DROP_FN[fn_ind]
            inv.consume_excess(OUTPUT_TARGETS, turtle[drop_fn])

            -- Typically faster to jump straight to craft here, and it
            -- will recover if we're wrong
            clear_mem(mem)
            store:dispatch(set_objective(OBJ_CRAFT))
        end
    end,
    [OBJ_ACQUIRE] = function(store, mem)
        if mem.current_path == nil then
            set_path(store, mem, FLOUR_CHEST_LOC)
        end

        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local suck_fn = constants.SUCK_FN[fn_ind]
            if not turtle[suck_fn]() then
                os.sleep(5)
            end
            idle(store, mem)
        end
    end,
    [OBJ_CRAFT] = function(store, mem)
        local succ, data = inv.select_by_pred(FLOUR_PRED)
        if not succ then
            idle(store, mem)
            return
        end

        if data.name == 'veggie_way:flour' then
            try_craft_veggie_way(store, mem)
        else
            try_craft_create(store, mem)
        end
    end,
    [OBJ_FILL_BUCKET] = function(store, mem)
        if mem.current_path == nil then
            set_path(store, mem, WATER_SOURCE_LOC)
        end

        if not tick_path(store, mem) then
            local fn_ind = constants.MOVE_TO_FN_IND[
                mem.current_path[#mem.current_path]]
            local place_fn = constants.PLACE_FN[fn_ind]

            if not inv.select_by_pred(EMPTY_BUCKET_PRED) then
                idle(store, mem)
                return
            end

            turtle.place()
            clear_mem(mem)

            -- Typically faster to jump straight to deposit here,
            -- and it'll recover if we're wrong
            store:dispatch(set_objective(OBJ_DEPOSIT, nil))
        end
    end
}

local function tick(store, mem)
    OBJECTIVE_TICKERS[store.raw.flour_to_dough.objective](store, mem)
end

local function main()
    startup.inject('programs/flour_to_dough')
    home.loc()


    local r, a, d, i = state.combine(
        {
            move_state=move_state.reducer,
            flour_to_dough=cust_reducer,
        },
        {
            move_state=move_state.actionator,
            flour_to_dough=cust_actionator,
        },
        {
            move_state=move_state.discriminators,
            flour_to_dough=cust_discriminators,
        },
        {
            move_state=move_state.init,
            flour_to_dough=cust_init,
        }
    )

    local store = state.Store:recover('flour_to_dough_store', r, a, d, i)
    store:dispatch(move_state.update_fuel())
    store:clean_and_save()


    local mem = {}
    while true do
        tick(store, mem)
    end
end

main()
