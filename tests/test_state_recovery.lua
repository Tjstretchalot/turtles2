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

local function print_comparison(nm, a, b)
    local err_flag = ''
    if a ~= b then err_flag = 'ERR' end

    print(string.format('%4s%4s | %8s | %s', err_flag, nm, a, b))
end

local function store_matches_pos_dir(store, pos, dir)
    return store.raw.move_state.position.x == pos.x and store.raw.move_state.position.y == pos.y and store.raw.move_state.position.z == pos.z and store.raw.move_state.dir == dir
end

local function print_store_comparison_pos_dir(store, pos, dir)
    print(string.format('%8s | expected | actual', ''))
    print_comparison('x', pos.x, store.raw.move_state.position.x)
    print_comparison('y', pos.y, store.raw.move_state.position.y)
    print_comparison('z', pos.z, store.raw.move_state.position.z)
    print_comparison('dir', dir, store.raw.move_state.dir)
end

local function test_fail(action, fail_at, expected_pos, expected_dir)
    local store = init_store()
    store:clean_and_save()
    store:dispatch(state.deep_copy(action), fail_at)

    store = init_store()
    store:clean_and_save()

    if not store_matches_pos_dir(store, expected_pos, expected_dir) then
        print('not in expected dir after action:')
        print(textutils.serialize(action))
        print(string.format('fail_at = %d', fail_at))
        print_store_comparison_pos_dir(store, expected_pos, expected_dir)
        error()
    end
end

local function test_fails(forward_action, reverse_action)
    print('Starting test for action:')
    print(textutils.serialize(forward_action))

    print('With reverse action:')
    print(textutils.serialize(reverse_action))

    local store = init_store()

    local og_pos = state.shallow_copy(store.raw.move_state.position)
    local og_dir = store.raw.move_state.dir

    store:dispatch(state.deep_copy(forward_action))
    local succ_pos = state.shallow_copy(store.raw.move_state.position)
    local succ_dir = store.raw.move_state.dir

    store:dispatch(state.deep_copy(reverse_action))
    if not store_matches_pos_dir(store, og_pos, og_dir) then
        print('forward action is not reversed by reverse action:')
        print_store_comparison_pos_dir(store, og_pos, og_dir)
        error()
    end

    print('Testing fail_at=1...')
    test_fail(forward_action, 1, og_pos, og_dir)
    for i=2, 8 do
        print(string.format('Testing fail_at=%d...', i))
        test_fail(forward_action, i, succ_pos, succ_dir)

        store = init_store()
        store:clean_and_save()
        store:dispatch(state.deep_copy(reverse_action))

        if not store_matches_pos_dir(store, og_pos, og_dir) then
            print('forward action is not reversed by reverse action:')
            print_store_comparison_pos_dir(store, og_pos, og_dir)
            error()
        end
    end
    print('Action passed all tests')
end

local function main()
    print('Testing move forward failures..')
    test_fails(move_state.forward(), move_state.back())

    print('Testing move back failures..')
    test_fails(move_state.back(), move_state.forward())

    print('Testing move up failures..')
    test_fails(move_state.up(), move_state.down())

    print('Testing move down failures..')
    test_fails(move_state.down(), move_state.up())

    print('Testing turn left failures..')
    test_fails(move_state.turn_left(), move_state.turn_right())

    print('Testing turn right failures..')
    test_fails(move_state.turn_right(), move_state.turn_left())
end

main()
