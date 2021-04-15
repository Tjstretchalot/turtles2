--- Tests the priority queue in PQue
package.path = '../?.lua;turtles2/?.lua'

local PQue = require('utils/pque')

local function test_construct_not_nil()
    local q = PQue:new()
    if q == nil then error('PQue:new() is nil') end
end
test_construct_not_nil()

local function test_construct_length_0()
    local q = PQue:new()
    if q:length() ~= 0 then error('PQue:new() length is ' .. tostring(q:length())) end
end
test_construct_length_0()

local function test_pop_empty_returns_nil()
    local q = PQue:new()
    if q:pop() ~= nil then error('PQue:pop() on empty queue is not nil') end
end
test_pop_empty_returns_nil()

local function test_insert_no_error()
    local q = PQue:new()
    q:insert(1, 1)
end
test_insert_no_error()

local function test_insert_pop_returns_inserted()
    local q = PQue:new()

    for i=1, 5 do
        q:insert(i, i)
        local popped = q:pop()
        if popped ~= i then
            error('expected ' .. tostring(i) .. ', got ' .. tostring(popped))
        end
    end
end
test_insert_pop_returns_inserted()

local function test_insert_2_ooo()
    local q = PQue:new()
    q:insert(5, 5)
    q:insert(3, 3)
    local popped = q:pop()
    if popped ~= 3 then error(tostring(popped)) end
    popped = q:pop()
    if popped ~= 5 then error(tostring(popped)) end
    popped = q:pop()
    if popped ~= nil then error(tostring(popped)) end
end
test_insert_2_ooo()

local function _pop_min(arr)
    if #arr == 0 then error() end
    local smallest = arr[1]
    local smallest_ind = 1
    for i=2, #arr do
        if arr[i] < smallest then
            smallest = arr[i]
            smallest_ind = i
        end
    end

    table.remove(arr, smallest_ind)
    return smallest
end

local function regression1()
    local q = PQue:new()
    q:insert(-15, -15)
    q:verify()
    q:insert(-2, -2)
    q:verify()
    q:insert(-11, -11)
    q:verify()
    q:insert(15, 15)
    q:verify()
    q:insert(-12, -12)
    q:verify()
    local popped = q:pop()
    q:verify()
    if popped ~= -15 then error(tostring(popped)) end
    local popped = q:pop()
    q:verify()
    if popped ~= -12 then error(tostring(popped)) end
    local popped = q:pop()
    q:verify()
    if popped ~= -11 then error(tostring(popped)) end
    local popped = q:pop()
    q:verify()
    if popped ~= -2 then error(tostring(popped)) end
    local popped = q:pop()
    q:verify()
    if popped ~= 15 then error(tostring(popped)) end
end
regression1()

local function test_fuzz_inserts_then_pops(seq_len, repeats)
    seq_len = seq_len or 5
    repeats = repeats or 10

    for i=1, repeats do
        local q = PQue:new()
        local inserted = {}
        local inserted_cp = {}
        for j=1, seq_len do
            local val = math.random(-20, 20)
            inserted[#inserted + 1] = val
            inserted_cp[#inserted_cp + 1] = val
            q:insert(val, val)
        end

        for j=1, seq_len do
            local expected = _pop_min(inserted_cp)
            local actual = q:pop()

            if expected ~= actual then
                local err_str = 'inserted = {\n'
                for k=1, seq_len do
                    err_str = err_str .. '  ' .. tostring(inserted[k]) .. ',\n'
                end
                err_str = err_str .. '}; pop #' .. tostring(j)
                err_str = err_str .. ' expected ' .. tostring(expected)
                err_str = err_str .. ', got ' .. tostring(actual)
                error(err_str)
            end
        end
    end
end
test_fuzz_inserts_then_pops()
