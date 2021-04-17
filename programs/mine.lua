--- This program is intended for mining all of the valuable resources from
-- a large area.
--
-- Pre-setup Notes:
--   - If the turtle does not have access to a GPS, it will prompt for the
--   current y coordinate at startup. The turtle can be started at y-values
--   below 128.
--   - The turtle will dig chunk by chunk in a square that has side-lengths
--   of 15 chunks (300 blocks) centered around its home position.
--   - On the x-z plane, the unmined blocks make 3x3 pillars. On the
--     y-plane, we skip 3 values at a time. We strip from layers 7-51
--   - For easiest tracking, the turtle should start at north-east corner
--     of a chunk facing south.
--
-- Setup:
--   - Place the turtle. The rest of the instructions are from someone
--   looking in the same direction as the turtle.
--   - Give some fuel to the turtle initially using the refuel command.
--   - Behind the turtle, place the chest in which the turtle will
--   deposit minerals.
--   - Right of the mineral chest is a space followed by a fuel chest.
--   You can use some mechanism to move coal from the mineral chest
--   to the fuel chest if you desire, although charcoal is just as
--   effective and is renewable (see treefarm!)
--   - Run the program. If no gps is available, answer the prompt for the
--   turtles current y-value.
--   - Progress will only happen while the turtles chunk is loaded.

local RESOURCE_NAMES_LOOKUP = {
    ['Railcraft:ore'] = true,
    ['BigReactors:YelloriteOre'] = true,
    ['appliedenergistics2:tile.OreQuartz'] = true,
    ['appliedenergistics2:tile.OreQuartzCharged'] = true,
    ['BiomesOPlenty:gemOre'] = true,
    ['ImmersiveEngineering:ore'] = true,
    ['TConstruct:ore.berries.two'] = true,
    ['TConstruct:SearedBrick'] = true,
    ['TConstruct:GravelOre'] = true,
    ['Forestry:resources'] = true,
    ['IC2:blockOreCopper'] = true,
    ['ThermalFoundation:Ore'] = true,
    ['IC2:blockOreTin'] = true,
    ['ProjRed:Exploration:projectred.exploration.ore'] = true,
    ['IC2:blockOreLead'] = true,
    ['minecraft:coal_ore'] = true,
    ['denseores:block0'] = true,
    ['minecraft:iron_ore'] = true,
    ['minecraft:gold_ore'] = true,
    ['minecraft:redstone_ore'] = true,
    ['minecraft:diamond_ore'] = true,
    ['minecraft:lapis_ore'] = true,
    ['minecraft:emerald_ore'] = true,
    ['DraconicEvolution:draconiumOre'] = true,
    ['Thaumcraft:blockCustomOre'] = true,
    ['TConstruct:ore.berries.one'] = true,
    ['aobd:oreIridium'] = true,
    ['IC2:blockOreUran'] = true,
    ['minecraft:log'] = true,
    ['minecraft:log2'] = true,
    ['IC2:blockRubWood'] = true,
    ['IC2:blockRubLeaves'] = true,
    ['minecraft:leaves'] = true,
    ['minecraft:leaves2'] = true,
    ['minecraft:vines'] = true,
    ['minecraft:rail'] = true,
    ['minecraft:golden_rail'] = true,
    ['minecraft:iron_bars'] = true,
    ['minecraft:web'] = true,
    ['minecraft:obsidian'] = true,
    ['Botania:mushroom'] = true,
    ['Botania:doubleFlower1'] = true,
    ['Botania:doubleFlower2'] = true,
    ['Botania:blackLotus'] = true,
    ['minecraft:nether_gold_ore'] = true,
    ['minecraft:nether_quartz_ore'] = true,
    ['techreborn:silver_ore'] = true,
    ['techreborn:galena_ore'] = true,
    ['techreborn:tin_ore'] = true,
    ['techreborn:lead_ore'] = true,
    ['techreborn:copper_ore'] = true,
    ['techreborn:bauxite_ore'] = true,
    ['techreborn:peridot_ore'] = true,
    ['techreborn:ruby_ore'] = true,
    ['techreborn:cinnabar_ore'] = true,
    ['techreborn:iridium_ore'] = true,
    ['techreborn:pyrite_ore'] = true,
    ['techreborn:sapphire_ore'] = true,
    ['techreborn:sheldonite_ore'] = true,
    ['techreborn:sodalite_ore'] = true,
    ['techreborn:sphalerite_ore'] = true,
    ['techreborn:tungsten_ore'] = true,
    ['astralsorcery:rock_crystal_ore'] = true,
    ['astralsorcery:starmetal_ore'] = true,
    ['bloodmagic:ironfragment'] = true,
    ['bloodmagic:goldfragment'] = true,
    ['create:zinc_ore'] = true,
    ['create:copper_ore'] = true,
    ['druidcraft:amber_ore'] = true,
    ['druidcraft:moonstone_ore'] = true,
    ['druidcraft:fiery_glass_ore'] = true,
    ['druidcraft:rockroot_ore'] = true,
    ['druidcraft:nether_fiery_glass_ore'] = true,
    ['druidcraft:brightstone_ore'] = true,
    ['forbidden_arcanus:arcane_crystal_ore'] = true,
    ['forbidden_arcanus:xpetrified_ore'] = true,
    ['immersiveengineering:ore_aluminum'] = true,
    ['immersiveengineering:ore_silver'] = true,
    ['immersiveengineering:ore_nickel'] = true,
    ['mekanism:copper_ore'] = true,
    ['mekanism:tin_ore'] = true,
    ['mekanism:osmium_ore'] = true,
    ['mekanism:uranium_ore'] = true,
    ['mekanism:fluorite_ore'] = true,
    ['mekanism:lead_ore'] = true,
    ['mysticalworld:granite_quartz_ore'] = true,
    ['mysticalworld:amethyst_ore'] = true,
    ['mysticalworld:quicksilver_ore'] = true,
    ['powah:uraninite_ore_poor'] = true,
    ['powah:uraninite_ore'] = true,
    ['powah:uraninite_ore_dense'] = true,
    ['quark:biotite_ore'] = true,
}

-- Initially assume an empty column at the home
local INITIAL_WORLD = {}
for y=-128, 0 do
    INITIAL_WORLD[tostring(vector.new(0, y, 0))] = true
end
-- Path to the fuel chest
INITIAL_WORLD[tostring(vector.new(-1, 0, 0))] = true
INITIAL_WORLD[tostring(vector.new(-2, 0, 0))] = true


local CHUNK_ORDER = {
    {x=0, z=0}
}
for radius=1, 7 do
    for x=0, radius do
        CHUNK_ORDER[#CHUNK_ORDER + 1] = {x=x, z=radius}
    end
    for z = radius-1, -radius, -1 do
        CHUNK_ORDER[#CHUNK_ORDER + 1] = {x=radius, z=z}
    end
    for x = radius - 1, -radius, -1 do
        CHUNK_ORDER[#CHUNK_ORDER + 1] = {x=x, z=-radius}
    end
    for z = -radius + 1, radius do
        CHUNK_ORDER[#CHUNK_ORDER + 1] = {x=-radius, z=z}
    end
    for x=-radius + 1, -1 do
        CHUNK_ORDER[#CHUNK_ORDER + 1] = {x=x, z=radius}
    end
end

-- within a chunk, these are the blocks that we will mine. The
-- y-value will vary. This is from the perspective of the NE
-- corner being (0, 0) and facing south. Order is irrelevant.
local WITHIN_CHUNK_BLOCKS = {}
-- rows
for z=0, 16, 4 do
    for x=0, 19 do
        WITHIN_CHUNK_BLOCKS[#WITHIN_CHUNK_BLOCKS + 1] = {x=x, z=z}
    end
end
-- cols
for x=3, 19, 4 do
    for z=0, 19 do
        if z - math.floor(z / 4) * 4 ~= 0 then
            WITHIN_CHUNK_BLOCKS[#WITHIN_CHUNK_BLOCKS + 1] = {x=x, z=z}
        end
    end
end

--- WITHIN_CHUNK_BLOCKS as a lookup - the keys are the tostring'd vectors
-- with y-value set to true.
local WITHIN_CHUNK_LOOKUP = {}
for _, v in ipairs(WITHIN_CHUNK_BLOCKS) do
    WITHIN_CHUNK_LOOKUP[tostring(
        vector.new(v.x, 0, v.z)
    )] = true
end

local Y_ORDER = {}
for y = 7, 51, 4 do
    Y_ORDER[#Y_ORDER + 1] = y
end

--- This factor is multiplied by the manhattan distance to the fuel chest to
-- estimate how much fuel it will take to get there.
local FUEL_MANH_MULT = 2

--- This is the buffer beyond the multiplier for the manhattan distance that
-- we maintain for fuel
local FUEL_BUFFER = 200

--- After refueling we want to have a large amount of fuel to prevent us from
-- literally going from the fuel chest, making the moves, mining one thing,
-- then coming back to refuel. This is the amount we will require before we
-- leave the fuel chest.
local FUEL_MIN_TO_LEAVE = 5000

local MINERAL_CHEST = vector.new(0, 0, -1)
local FUEL_CHEST = vector.new(-2, 0, -1)

local function ores_filter(data)
    return not not RESOURCE_NAMES_LOOKUP[data.name]
end


package.path = '../?.lua;turtles2/?.lua'
local ores = require('utils/ores')
local home = require('utils/home')
local state = require('utils/state')
local move_state = require('utils/move_state')
local startup = require('utils/startup')
local paths = require('utils/paths')
local flood_paths = require('utils/flood_paths')
local constants = require('utils/constants')
local path_utils = require('utils/path_utils')
local inv = require('utils/inv')

--- Custom store structure:
-- world = table
--   keys are tostring'd relative locations, values are true
-- cur_chunk_ind = number
--   the index in CHUNK_ORDER for the chunk we are currently working on
-- cur_layer_ind = number
--   the index in Y_ORDER for the y layer we are currently working on
-- objective = string
--   one of the objective string constants

-- Objectives
local OBJ_GOTO = 'goto' -- Go to a location to mine
local OBJ_REFUEL = 'refuel' -- Get fuel from fuel chest
local OBJ_DEPOSIT = 'deposit' -- Deposit materials into wood chest
local OBJ_ORES = 'ores' -- Continue the current ores run

-- Actions
local ACT_SET_OBJECTIVE = 'set_objective'
local ACT_START_ORES = 'start_ores'
local ACT_FINISH_ORES = 'finish_ores'
local ACT_INCR_LAYER = 'incr_layer'

-- Creates the action which sets the current objective to the given
-- objective. This should not be used for setting the "ores" objective,
-- which should use start_ores / end_ores actions to ensure coupled
-- behavior works as expected.
local function set_objective(obj)
    return {
        type = ACT_SET_OBJECTIVE,
        objective = obj
    }
end

-- Should be invoked when the turtle is at a location that should be scanned
-- for ores. This will set the current objective to 'ores' and initialize the
-- ores portion of the store
local function start_ores(store)
    return {
        type = ACT_START_ORES,
        ores_action = ores.set_start_to_cur(store)
    }
end

--- Should be invoked when the ores module has indicated we have completed
-- mining and have returned to the start.
-- This will:
--  - Add the start location of ores to the 'world' table (mark it as finished)
--  - Uninitialize the ores context
--  - Set the objective to 'goto'
-- @param bool inc_layer true if we should increment the layer index, false
-- otherwise
local function finish_ores()
    return { type = ACT_FINISH_ORES }
end

--- Should be invoked when we have called ores on every block in a layer.
-- This will increment cur_layer_ind. If cur_layer_ind will exceed the number
-- of layers per chunk from this action, it will be reset and the chunk ind
-- will be incremented.
-- @return table the corresponding action
local function increment_layer()
    return { type = ACT_INCR_LAYER }
end

local function cust_init()
    return {
        world = INITIAL_WORLD,
        cur_chunk_ind = 1,
        cur_layer_ind = 1,
        objective = OBJ_DEPOSIT
    }
end

local function cust_reducer(raw, action)
    if action.type == ACT_SET_OBJECTIVE then
        local res = state.shallow_copy(raw)
        res.objective = action.objective
        return res
    elseif action.type == ACT_INCR_LAYER then
        local res = state.shallow_copy(raw)
        if res.cur_layer_ind == #Y_ORDER then
            res.cur_layer_ind = 1
            res.cur_chunk_ind = res.cur_chunk_ind + 1
        else
            res.cur_layer_ind = res.cur_layer_ind + 1
        end
        return res
    end
    return raw
end

local function reduce_wrapper(reducer)
    return function(raw, action)
        if action.type == ACT_START_ORES then
            local res = state.shallow_copy(raw) -- avoid deep copy world
            res.mine = state.shallow_copy(res.mine)
            res.mine.objective = OBJ_ORES
            res.ores = ores.reducer(res.ores, action.ores_action)
            return res
        elseif action.type == ACT_FINISH_ORES then
            local res = state.deep_copy(raw) -- have to deep copy world
            res.mine.world[tostring(
                vector.new(
                    res.ores.start.x,
                    res.ores.start.y,
                    res.ores.start.z)
            )] = true
            res.ores = ores.init()
            res.mine.objective = OBJ_GOTO
            return res
        end

        return reducer(raw, action)
    end
end


local function clear_mem(mem)
    mem.current_path = nil
    mem.current_path_ind = nil
    mem.ore_ctx = nil
end

local function consider_refuel(store, mem)
    local fuel = turtle.getFuelLevel()
    if fuel == 'unlimited' then return false end
    if fuel > FUEL_MIN_TO_LEAVE then return false end

    local rloc, rdir = home.make_relative(
        vector.new(
            store.raw.move_state.position.x,
            store.raw.move_state.position.y,
            store.raw.move_state.position.z),
        store.raw.move_state.dir
    )

    local manh = paths.manhattan(rloc, FUEL_CHEST)
    local req_fuel = FUEL_BUFFER + FUEL_MANH_MULT * manh

    return fuel < req_fuel
end

local function consider_deposit(store, mem)
    return inv.count_empty() <= 0
end

local cust_actionator = {}
local cust_discriminators = {}

local OBJECTIVE_TICKERS = {
    [OBJ_GOTO] = function(store, mem)
        if consider_deposit(store, mem) then
            print('Depositing items...')
            clear_mem(mem)
            store:dispatch(set_objective(OBJ_DEPOSIT))
            return true
        end

        if consider_refuel(store, mem) then
            print('Refueling..')
            clear_mem(mem)
            store:dispatch(set_objective(OBJ_REFUEL))
            return true
        end

        local data = store.raw.mine

        if data.cur_chunk_ind > #CHUNK_ORDER then return false end

        if mem.current_path == nil then
            local rel_loc, rel_dir = home.make_relative(
                vector.new(
                    store.raw.move_state.position.x,
                    store.raw.move_state.position.y,
                    store.raw.move_state.position.z),
                store.raw.move_state.dir
            )
            local hloc, hdir = home.loc()

            local cur_chunk = CHUNK_ORDER[data.cur_chunk_ind]
            local cur_layer = Y_ORDER[data.cur_layer_ind]

            local chunk_offset = vector.new(
                20 * cur_chunk.x,
                cur_layer - hloc.y,
                20 * cur_chunk.z
            )

            local function flood_end_check(loc, dir)
                -- first unvisited location within the chunk we want to mine
                if not not data.world[tostring(loc)] then return false end

                local within_chunk_loc = loc - chunk_offset
                return not not WITHIN_CHUNK_LOOKUP[tostring(within_chunk_loc)]
            end

            -- perform a short undirected search; we use this before a directed
            -- search because most paths will be 1-2 moves, a few at 6 moves,
            -- and then a huge jump to 30-100+ moves
            local path = flood_paths.determine_path(
                data.world, true, rel_loc, rel_dir, flood_end_check, true, 6
            )

            if path == nil then
                print('Performing expensive pathfinding..')
                -- use heuristic only to determine closest then do a directed
                -- search.
                local best_node_loc = nil
                local best_node_heur = nil
                for _, loc in ipairs(WITHIN_CHUNK_BLOCKS) do
                    local locv = chunk_offset + vector.new(loc.x, 0, loc.z)
                    if not data.world[tostring(locv)] then
                        local found_nhbr = false
                        for _, off in ipairs(constants.NEIGHBORS) do
                            if data.world[tostring(locv + off)] then
                                found_nhbr = true
                                break
                            end
                        end
                        if found_nhbr then
                            local heur = paths.manhattan_consistent(rel_loc, locv, rel_dir, nil)
                            if best_node_heur == nil or heur < best_node_heur then
                                best_node_loc = locv
                                best_node_heur = heur
                            end
                        end
                    end
                end

                if best_node_loc == nil then
                    print('finished a layer')
                    clear_mem(mem)
                    store:dispatch(increment_layer())
                    return true
                end

                print('Found best node..')
                path = paths.determine_path(
                    data.world, true, rel_loc, rel_dir, best_node_loc, nil,
                    paths.manhattan_consistent, true
                )
                if path == nil then
                    error('world is not contiguous')
                end
                print('Found path')
            end

            mem.current_path = path
            mem.current_path_ind = 1
        end

        if path_utils.tick_path(store, mem, true, true) then return true end

        clear_mem(mem)
        store:dispatch(start_ores(store))
        return true
    end,
    [OBJ_REFUEL] = function(store, mem)
        store:dispatch(move_state.update_fuel())
        local fuel = turtle.getFuelLevel()
        if fuel == 'unlimited' or fuel >= FUEL_MIN_TO_LEAVE then
            if inv.count_empty() < 16 then
                store:dispatch(set_objective(OBJ_DEPOSIT))
            else
                store:dispatch(set_objective(OBJ_GOTO))
            end
            clear_mem(mem)
            return true
        end

        if mem.current_path == nil then
            if not path_utils.set_path(
                        store, mem, FUEL_CHEST, store.raw.mine.world, true, true) then
                os.sleep(10)
                return true
            end
        end

        if path_utils.tick_path(store, mem, true, false) then return true end

        local fn_ind = constants.MOVE_TO_FN_IND[
            mem.current_path[#mem.current_path]]

        if not inv.select_empty() then
            textutils.slowPrint('throwing item to make space for fuel')
            local new_fn_ind = fn_ind + 1
            if new_fn_ind > 3 then new_fn_ind = 1 end
            if not turtle[constants.DROP_FN[new_fn_ind]]() then
                textutils.slowPrint('even dropping an item failed!')
                os.sleep(10)
                return true
            end
        end

        local suck_fn = constants.SUCK_FN[fn_ind]

        if not turtle[suck_fn]() then
            textutils.slowPrint('fuel chest is empty! should be at')
            textutils.slowPrint(mem.current_path[#mem.current_path])
            os.sleep(10)
            return true
        end

        if not turtle.refuel() then
            textutils.slowPrint('got non-fuel from fuel chest!')
            textutils.slowPrint('delaying before next attempt')
            os.sleep(10)
            return true
        end

        return true
    end,
    [OBJ_DEPOSIT] = function(store, mem)
        if inv.count_empty() >= 16 then
            local fuel = turtle.getFuelLevel()
            if fuel ~= 'unlimited' and fuel < FUEL_MIN_TO_LEAVE then
                store:dispatch(set_objective(OBJ_REFUEL))
            else
                store:dispatch(set_objective(OBJ_GOTO))
            end

            clear_mem(mem)
            return true
        end

        if mem.current_path == nil then
            if not path_utils.set_path(
                        store, mem, MINERAL_CHEST, store.raw.mine.world, true, true) then
                os.sleep(10)
                return true
            end
        end

        if path_utils.tick_path(store, mem, true, false) then return true end

        local fn_ind = constants.MOVE_TO_FN_IND[
            mem.current_path[#mem.current_path]]
        local drop_fn = constants.DROP_FN[fn_ind]

        inv.consume_excess({}, turtle[drop_fn])
        if inv.count_empty() < 16 then
            textutils.slowPrint('mineral chest is full!')
            os.sleep(30)
        end

        return true
    end,
    [OBJ_ORES] = function(store, mem)
        if mem.ore_ctx == nil then mem.ore_ctx = {} end

        if ores.tick(store, mem.ore_ctx, 'ores', ores_filter) then
            return true
        end
        print('ores finished')

        clear_mem(mem)
        store:dispatch(finish_ores())
        return true
    end
}

local function tick(store, mem)
    return OBJECTIVE_TICKERS[store.raw.mine.objective](store, mem)
end

local function main()
    startup.inject('programs/mine.lua')

    local r, a, d, i = state.combine(
        {
            move_state=move_state.reducer,
            ores=ores.reducer,
            mine=cust_reducer
        },
        {
            move_state=move_state.actionator,
            ores=ores.actionator,
            mine=cust_actionator
        },
        {
            move_state=move_state.discriminators,
            ores=ores.discriminators,
            mine=cust_discriminators
        },
        {
            move_state=move_state.init,
            ores=ores.init,
            mine=cust_init
        }
    )

    r = reduce_wrapper(r)

    local store = state.Store:recover('mine_store', r, a, d, i)
    local hloc, hdir = home.loc() -- ensure initialized
    if hloc.y == 0 then
        print('Enter turtles y-coordinate: ')
        local turtle_y = tonumber(read())
        if turtle_y == nil then
            error('bad y value!')
            return
        end
        store:clean_and_save()
        store.raw.move_state.position.y = turtle_y
        store:clean_and_save()

        home.overwrite(hloc.x, turtle_y, hloc.z, hdir)
    end

    store:dispatch(move_state.update_fuel())
    store:clean_and_save()

    local mem = {}
    while tick(store, mem) do
    end

    textutils.slowPrint('all done!')

    startup.deject('programs/mine.lua')
    store:clean()
    home.delete()
end

main()
