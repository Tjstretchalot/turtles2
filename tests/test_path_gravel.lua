--- Tests to make sure that if the turtle encounters gravel or
-- sand it while mining it can get through it while maintaining
-- the correct location.
--
-- Setup:
-- - Place turtle
-- - In front of the turtle put a gravel column 3 high
package.path = '../?.lua;turtles2/?.lua'

local home = require('utils/home')
local state = require('utils/state')
local move_state = require('utils/move_state')
local constants = require('utils/constants')
local paths = require('utils/paths')
local path_utils = require('utils/path_utils')

local WORLD = {
    [tostring(vector.new(0, 0, 0))] = true,
    [tostring(vector.new(0, 0, 1))] = true,
    [tostring(vector.new(0, 0, 2))] = true
}

local function init_store()
    local r, a, d, i = state.combine(
        {
            move_state=move_state.reducer,
        },
        {
            move_state=move_state.actionator,
        },
        {
            move_state=move_state.discriminators,
        },
        {
            move_state=move_state.init,
        }
    )

    return state.Store:recover('test', r, a, d, i)
end

local function main()
    home.loc()

    local store = init_store()
    local mem = {}
    mem.current_path = path_utils.set_path(store, mem, rdest, WORLD, true, true)
    mem.current_path_ind = 1

    textutils.slowPrint(
        string.format('currently at %s', store.raw.move_state.position)
    )
    textutils.slowPrint('Path:')
    for i, ele in ipairs(mem.current_path) do
        textutils.slowPrint(string.format('%2d: %s', i, ele))
    end
    store:clean()
end

main()
