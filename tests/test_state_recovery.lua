--- Tests state recovery during movements
package.path = '../?.lua;turtles2/?.lua'

local home = require('utils/home')
local state = require('utils/state')
local move_state = require('utils/move_state')
local constants = require('utils/constants')

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

local function test_fail(action, fail_at, expected_pos, expected_dir)
    local store = init_store()
    store:clean_and_save()
    store:dispatch(action, fail_at)

    if fail_at == 1 then
end

local function test_fails(forward_action, reverse_action)
    local store = init_store()

    local og_pos = state.shallow_copy(store.raw.move_state.position)
    local og_dir = store.raw.move_state.dir

    store:dispatch(forward_action)
    local succ_pos = state.shallow_copy(store.raw.move_state.position)
    local succ_dir = store.raw.move_state.dir

    store:dispatch(reverse_action)
    if og_pos.x ~= store.raw.move_state.position.x or og_pos.y ~= store.raw.move_state.position.y or og_pos.z ~= store.raw.move_state.position.z then
        print('forward action is not reversed by reverse action:')
        print('    | original | after redo/undo')
        print(string.format('  x | %8s | %s', og_pos.x, store.raw.move_state.position.x))
        print(string.format('  y | %8s | %s', og_pos.y, store.raw.move_state.position.y))
        print(string.format('  z | %8s | %s', og_pos.z, store.raw.move_state.position.z))
        print(string.format('dir | %8s | %s', og_dir, store.raw.move_state.dir))
        error()
    end

    test_fail(forward_action, 1, og_pos, og_dir)
    for i=2, 8 do
        test_fail(forward_action, 2, succ_pos, succ_dir)
        store:dispatch(reverse_action)
    end
end

local function main()
    print('Testing move forward failures..')
    test_fails(move_state.forward(), move_state.back())
end

main()
