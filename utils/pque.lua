---
-- Priority queue optimized for the paths module. Implemented with a heap.
-- Capable of insertion and extracting the smallest element.

--- A priority queue class.
-- @type PQue
--
-- Instance variables
-- heap_prios table each element is a number which corresponds to the priority
-- of the corresponding element in heap
-- heap table the elements with index correspondence with heap_prios
local PQue = {}

--- Constructs an uninitialized priority queue. Should be treated as a private
-- constructor.
function PQue:_init()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

--- Constructs an empty priority queue with the given prioritization function.
function PQue:new()
    local o = PQue:_init()
    o.heap_prios = {}
    o.heap = {}
    return o
end

--- Determines the number of elements in this queue
-- @return the number of elements in the queue
function PQue:length()
    return #self.heap
end

--- Inserts the given element with the given priority
-- @param element any the element to insert
-- @param priority number the priority of the element, lower will be returned
-- sooner.
function PQue:insert(element, priority)
    local ind = #self.heap_prios + 1

    while ind > 1 do
        local parent_ind = math.floor(ind / 2)
        if priority >= self.heap_prios[parent_ind] then break end
        self.heap[ind] = self.heap[parent_ind]
        self.heap_prios[ind] = self.heap_prios[parent_ind]
        ind = parent_ind
    end

    self.heap[ind] = element
    self.heap_prios[ind] = priority
end

--- Pops the element with lowest value for priority off this queue.
-- @return the element with the smallest priority in this queue
function PQue:pop()
    local res = self.heap[1]

    local end_ind = #self.heap
    local to_ins = self.heap[end_ind]
    local to_ins_prio = self.heap_prios[end_ind]

    self.heap[end_ind] = nil
    self.heap_prios[end_ind] = nil

    if end_ind == 1 then return res end

    local cur_ind = 1
    local left_child = cur_ind * 2
    local right_child = left_child + 1
    while left_child < end_ind do
        if (self.heap_prios[left_child] < to_ins_prio
                and (
                    right_child >= end_ind or
                    self.heap_prios[left_child] < self.heap_prios[right_child]))
                then
            self.heap[cur_ind] = self.heap[left_child]
            self.heap_prios[cur_ind] = self.heap_prios[left_child]

            cur_ind = left_child
        elseif right_child >= end_ind then break
        elseif self.heap_prios[right_child] < to_ins_prio then
            self.heap[cur_ind] = self.heap[right_child]
            self.heap_prios[cur_ind] = self.heap_prios[right_child]

            cur_ind = right_child
        else break end

        left_child = cur_ind * 2
        right_child = left_child + 1
    end

    self.heap[cur_ind] = to_ins
    self.heap_prios[cur_ind] = to_ins_prio
    return res
end

--- Verifies the internal state of the heap is valid
function PQue:verify()
    for i=1, math.floor(self:length() / 2) do
        local val = self.heap_prios[i]
        local left_child = self.heap_prios[i * 2]
        if left_child < val then
            error('heap_prios[' .. tostring(i) .. '] > heap_prios['
                  .. tostring(i * 2) .. ']')
        end

        if i * 2 + 1 <= self:length() then
            local right_child = self.heap_prios[i * 2 + 1]
            if right_child < val then
                error('heap_prios[' .. tostring(i) .. '] > heap_prios['
                      .. tostring(i * 2 + 1) .. ']')
            end
        end
    end
end

function PQue:tostring()
    local res = 'PQue length = ' .. tostring(self:length()) .. ' heap={\n'
    for i=1, self:length() do
        res = res .. '  ' .. tostring(self.heap[i]) .. ',\n'
    end
    res = res .. '}'
    return res
end

return PQue
