--- Some utility functions for managing the turtles inventory.

local inv = {}

--- Attempts to merge stacks of items together. This can change the currently
-- selected item.
function inv.combine_stacks()
    for i=1, 16 do
        local avail = turtle.getItemSpace(i)
        if avail > 0 and turtle.getItemCount(i) > 0 then
            turtle.select(i)
            for j=i+1, 16 do
                if turtle.compareTo(j) then
                    turtle.select(j)
                    turtle.transferTo(i, avail)
                    avail = turtle.getItemSpace(i)
                    turtle.select(i)

                    if avail <= 0 then break end
                end
            end
        end
    end
end

--- Selects the first slot for which the result from turtle.getItemDetail
-- when passed to the given predicate function gets the result true.
-- @param pred function accepts the item detail result and returns true
-- if it should be selected and false otherwise
-- @return either true, data or false, nil. If true, data is the result
-- from turtle.getItemDetail for the selected slot. If false, no items
-- in the inventory match the predicate.
function inv.select_by_pred(pred)
    for i=1, 16 do
        local data = turtle.getItemDetail(i)
        if pred(data) then
            turtle.select(i)
            return true, data
        end
    end
    return false, nil
end

--- Counts the number of slots and items that pass the given predicate.
-- The predicate is passed the result for turtle.getItemDetail for each
-- slot, returning true if it should be counted and false otherwise.
-- Empty slots are counted as no items.
-- @param pred function accepts the result from turtle.getItemDetail,
-- returns a boolean indicating if the slot should be counted
-- @return stacks, items the sum of matching stacks and matching items (ie.,
-- one stack of 64 gets 1, 64. two stacks of 32 gives 2, 32)
function inv.count_by_pred(pred)
    local stacks = 0
    local items = 0
    for i=1, 16 do
        local data = turtle.getItemDetail(i)
        if pred(data) then
            stacks = stacks + 1
            if data then
                items = items + data.count
            end
        end
    end
    return stacks, items
end

--- For each item in the inventory matching the given predicate, this selects
-- it and calls the consumer with no arguments.
-- @param pred function accepts result from turtle.getItemDetail, returns true
-- if it should be consumed and false otherwise
-- @param cons function called after selecting a slot to consume
function inv.consume_by_pred(pred, cons)
    for i=1, 16 do
        local data = turtle.getItemDetail(i)
        if pred(data) then
            turtle.select(i)
            cons()
        end
    end
end

--- For each extra amount beyond the targets, this selects it and calls the
-- consumer with the amount of excess in the selected slot (i.e., as if the
-- consumer was turtle.drop). Empty item slots are ignored.
--
-- inv.targets_by_lookup may be helpful for constructing target predicates.
--
-- @param targets table array-like each item is {predicate, count} where the
-- count is the target number of items matching the predicate. An item will not
-- be checked for future predicates once it matches one, so predicates should
-- be ordered in most to least specific.
-- @param cons function the function that consumes the excess
function inv.consume_excess(targets, cons)
    local reqs = {}
    for i=1, #targets do
        reqs[i] = targets[i][1]
    end

    for i=1, 16 do
        local data = turtle.getItemDetail(i)
        if data ~= nil then
            for j, target in ipairs(targets) do
                if target[0](data) then
                    if reqs[j] < data.count then
                        turtle.select(i)
                        local exc = data.count - reqs[j]
                        cons(exc)
                        reqs[j] = 0
                    else
                        reqs[j] = reqs[j] - data.count
                    end
                end
            end
        end
    end
end

--- This predicate matches empty inventory slots.
function inv.pred_empty(data)
    return data == nil
end

--- Creates a predicate that returns true if the item slot is not empty
-- and the name is a key in the lookup with a truthy value
-- @param lookup table the item name lookup
-- @return a predicate based on the lookup
function inv.new_pred_by_name_lookup(lookup)
    return function(data)
        return data ~= nil and lookup[data.name]
    end
end

--- Creates a predicate that returns true if the item slot is not empty
-- and the name is NOT a key in the lookup with a truthy value.
-- @param lookup table the item name lookup
-- @return a predicate based on the lookup
function inv.new_pred_by_inv_name_lookup(lookup)
    return function(data)
        return data ~= nil and not lookup[data.name]
    end
end

--- Creates a predicate that returns true if the item slot has an item name
-- which matches the given name.
-- @param name the name of the item you want the predicate to match
-- @return a predicate which matches based on name
function inv.new_pred_by_name(name)
    return function(data)
        return data ~= nil and data.name == name
    end
end

--- Selects the first empty inventory slot, if there is one. Drops the data
-- result from select_by_pred for convenience.
-- @return boolean true if we selected an empty slot, false otherwise
function inv.select_empty()
    local succ, data = inv.select_by_pred(inv.pred_empty)
    return succ
end

--- Counts the number of empty slots in the turtles inventory. Drops
-- the items result from count_by_pred for convenience.
-- @return number the number of empty slots
function inv.count_empty()
    local stacks, _ = inv.count_by_pred(inv.pred_empty)
    return stacks
end

--- Creates the expected targets table using the lookup table and an arbitrary
-- ordering. The lookup table has keys which are names of items and values
-- which are the number we are trying to store, e.g.,
-- {['minecraft:sapling'] = 16}
--
-- @param lookup table contains what items we are trying to store and how many
-- @return targets table as expected for consume_excess
function inv.targets_by_lookup(lookup)
    local result = {}
    for name, amt in pairs(lookup) do
        result[#result + 1] = { inv.new_pred_by_name(name), amt }
    end
    return result
end

return inv
