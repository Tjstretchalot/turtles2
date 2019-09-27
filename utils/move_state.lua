---
-- This module provides the actions, reducer, actionator, and discriminator
-- for the 6 turtle movements (turn left/right, up, forward, down, back).
-- The state contains position: {x=,y=,z=}, direction (a number of right
-- turns), and the fuel level (number or 'unlimited'). Note that after
-- refueling the UPDATE_FUEL action should be taken

local constants = require('utils/constants')
local gps_locate = require('utils/gps_locate')
local state = require('utils/state')

local move_state = {}

move_state.TURN_LEFT = 'turn_left'
move_state.TURN_RIGHT = 'turn_right'
move_state.FORWARD = 'forward'
move_state.UP = 'up'
move_state.DOWN = 'down'
move_state.BACK = 'back'
move_state.UPDATE_FUEL = 'update_fuel'

move_state.FROM_TURTLE_ATTR = {
    turnLeft = move_state.TURN_LEFT,
    turnRight = move_state.TURN_RIGHT,
    forward = move_state.FORWARD,
    up = move_state.UP,
    down = move_state.DOWN,
    back = move_state.BACK
}

--- Creates a new turn left action
function move_state.turn_left()
    return { type=move_state.TURN_LEFT }
end

--- Creates a new turn right action
function move_state.turn_right()
    return { type=move_state.TURN_RIGHT }
end

--- Creates a new forward action
function move_state.forward()
    return { type=move_state.FORWARD }
end

--- Creates a new up action
function move_state.up()
    return { type=move_state.UP }
end

--- Creates a new down action
function move_state.down()
    return { type=move_state.DOWN }
end

--- Creates a new back action
function move_state.back()
    return { type=move_state.BACK }
end

--- Creates a new action to update the fuel to the current amount
function move_state.update_fuel()
    return { type=move_state.UPDATE_FUEL, fuel=turtle.getFuelLevel() }
end

--- Initializes a new move state using the gps if possible.
function move_state.init()
    local abs_loc, abs_dir = gps_locate.locate()
    local absolute = not not abs_loc
    if not abs_loc then
        local x, y, z = gps.locate()
        if x then
            abs_loc = {x=x, y=y, z=z}
        else
            abs_loc = {x=0,y=0,z=0}
            abs_dir = 0
        end
    else
        abs_loc = {x=abs_loc.x, y=abs_loc.y, z=abs_loc.z}
    end

    return {
        position = abs_loc,
        dir = abs_dir,
        absolute = absolute,
        fuel = turtle.getFuelLevel()
    }
end

local function _add_vec(state, vec)
    state.position.x = state.position.x + vec.x
    state.position.y = state.position.y + vec.y
    state.position.z = state.position.z + vec.z
end

local function _reduce_fuel(state)
    if state.fuel ~= 'unlimited' then
        state.fuel = state.fuel - 1
    end
end

--- The reducer for the move state.
function move_state.reducer(raw, action)
    if raw == nil or raw.fuel == nil then
        textutils.slowPrint('move_state.reducer(')
        textutils.slowPrint(textutils.serialize(raw))
        textutils.slowPrint(', ' .. textutils.serialize(action))
        textutils.slowPrint(')')
        error('raw/action is nil', 2)
    end

    if action.type == move_state.TURN_LEFT then
        local res = state.deep_copy(raw)
        res.dir = constants.LEFT_DIRS[res.dir]
        return res
    elseif action.type == move_state.TURN_RIGHT then
        local res = state.deep_copy(raw)
        res.dir = constants.RIGHT_DIRS[res.dir]
        return res
    elseif action.type == move_state.FORWARD then
        if raw.fuel == 0 then return raw end
        local res = state.deep_copy(raw)
        local delta = constants.DIR_TO_DELTA[res.dir]
        _add_vec(res, delta)
        _reduce_fuel(res)
        return res
    elseif action.type == move_state.BACK then
        if raw.fuel == 0 then return raw end
        local res = state.deep_copy(raw)
        local delta = constants.DIR_TO_DELTA[
            constants.BACK_DIRS[res.dir]
        ]
        _add_vec(res, delta)
        _reduce_fuel(res)
        return res
    elseif action.type == move_state.UP then
        if raw.fuel == 0 then return raw end
        local res = state.deep_copy(raw)
        _add_vec(res, constants.UP_DIR)
        _reduce_fuel(res)
        return res
    elseif action.type == move_state.DOWN then
        if raw.fuel == 0 then return raw end
        local res = state.deep_copy(raw)
        _add_vec(res, constants.DOWN_DIR)
        _reduce_fuel(res)
        return res
    elseif action.type == move_state.UPDATE_FUEL then
        if raw.fuel == action.fuel then return raw end
        local res = state.deep_copy(raw)
        res.fuel = action.fuel
        return res
    end

    return raw
end

--- The actionator for the move state
move_state.actionator = {
    [move_state.TURN_LEFT] = function(act) turtle.turnLeft() end,
    [move_state.TURN_RIGHT] = function(act) turtle.turnRight() end,
    [move_state.FORWARD] = function(act) turtle.forward() end,
    [move_state.BACK] = function(act) turtle.back() end,
    [move_state.UP] = function(act) turtle.up() end,
    [move_state.DOWN] = function(act) turtle.down() end
}

--- This discriminator can be used on actions which consume fuel to determine
-- the correct state by eliminating those with the wrong amount of fuel
function move_state.discriminate_with_fuel(act, poss, corrupted, key)
    local fuel = turtle.getFuelLevel()
    if fuel == 'unlimited' then return poss end

    local new_poss = {}
    for i=1, #poss do
        local ele = poss[i].raw
        if key ~= nil then ele = ele[key] end
        if ele == nil then error('ele[' .. tostring(i) .. '] nil', 2) end

        if ele ~= nil and ele.fuel == fuel then
            new_poss[#new_poss + 1] = poss[i]
        end
    end
    if #new_poss == 0 then
        textutils.slowPrint('move_state.discriminate_with_fuel - no possibilities')
        textutils.slowPrint('fuel=' .. tostring(fuel))
        for i=1, #poss do
            local ele = poss[i].raw
            if key ~= nil then ele = ele[key] end
            textutils.slowWrite('poss[' .. tostring(i) .. '] = ')
            textutils.slowPrint(textutils.serialize(ele))
        end
        return poss
    end

    return new_poss
end

--- Tries to use just the location from the gps to discriminate
-- between the possibilities. If the possibilities are stored
-- with absolute coordinates and a gps is available, those possibilities
-- with the wrong absolute coordinates are eliminated.
function move_state.discriminate_with_gps_pos(act, poss, corrupted, key)
    local x, y, z = gps.locate()
    if not x then return poss end

    local new_poss = {}
    for i=1, #poss do
        local ele = poss[i].raw
        if key ~= nil then ele = ele[key] end

        if (not ele.absolute or
                (ele.position.x == x
                and ele.position.y == y
                and ele.position.z == z)) then
            new_poss[#new_poss + 1] = poss[i]
        end
    end

    if #new_poss == 0 then
        textutils.slowPrint('move_state.discriminate_with_gps_pos - no possibilities')
        textutils.slowPrint('loc=' .. tostring(vector.new(x, y, z)))
        for i=1, #poss do
            local ele = poss[i].raw
            if key ~= nil then ele = ele[key] end
            textutils.slowWrite('poss[' .. tostring(i) .. '] = ')
            textutils.slowPrint(textutils.serialize(ele))
        end
        return poss
    end

    return new_poss
end

--- Tries to use the gps position and direction (from gps_locate) to eliminate
-- possibilities which have the wrong direction.
function move_state.discriminate_with_gps_dir(act, poss, corrupted, key)
    local loc, dir = gps_locate.locate()
    if not loc then return poss end

    local new_poss = {}
    for i=1, #poss do
        local ele = poss[i].raw
        if key ~= nil then ele = ele[key] end

        if not ele.absolute or ele.dir == dir then
            new_poss[#new_poss + 1] = poss[i]
        end
    end

    if #new_poss == 0 then
        textutils.slowPrint('move_state.discriminate_with_gps_dir - no possibilities')
        textutils.slowPrint('dir=' .. tostring(dir))
        for i=1, #poss do
            local ele = poss[i].raw
            if key ~= nil then ele = ele[key] end
            textutils.slowWrite('poss[' .. tostring(i) .. '] = ')
            textutils.slowPrint(textutils.serialize(ele))
        end
        return poss
    end

    return new_poss
end

--- The suggested discriminators for the move state.
move_state.discriminators = {
    [move_state.TURN_LEFT] = {
        move_state.discriminate_with_gps_dir,
        state.discriminate_with_guess
    },
    [move_state.TURN_RIGHT] = {
        move_state.discriminate_with_gps_dir,
        state.discriminate_with_guess
    },
    [move_state.FORWARD] = {
        move_state.discriminate_with_fuel,
        move_state.discriminate_with_gps_pos,
        state.discriminate_with_guess
    },
    [move_state.BACK] = {
        move_state.discriminate_with_fuel,
        move_state.discriminate_with_gps_pos,
        state.discriminate_with_guess
    },
    [move_state.UP] = {
        move_state.discriminate_with_fuel,
        move_state.discriminate_with_gps_pos,
        state.discriminate_with_guess
    },
    [move_state.DOWN] = {
        move_state.discriminate_with_fuel,
        move_state.discriminate_with_gps_pos,
        state.discriminate_with_guess
    }
}

return move_state
