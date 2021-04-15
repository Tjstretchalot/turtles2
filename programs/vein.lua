--- Very simple program which mines a single vein. Meant to be used as an
-- example, but sometimes helpful (i.e., deconstructing a cobblestone base
-- or a huge tree).
--
-- Usage:
--   Put at least one of each item that you want to mine with the ores module
--   into the turtles inventory, then run. The turtle will exhaustively search
--   adjacent tiles for those blocks and mine them. This process then repeats
--   on each of the adjacent tiles.
--
-- Persistance:
--   This is meant to be completely persistent; once run, it will automatically
--   detect and handle restarts until completion.

package.path = '../?.lua;turtles2/?.lua'
local state = require('utils/state')
local move_state = require('utils/move_state')
local ores = require('utils/ores')
local home = require('utils/home')
local startup = require('utils/startup')

--- Constructs a filter for ores which checks if the item name
-- is in the given list.
local function filter_list(items)
    local lookup = {}
    for i, v in ipairs(items) do
        lookup[v] = true
    end

    local function result(inf)
        return not not lookup[inf.name]
    end

    return result
end

local function main()
    startup.inject('programs/vein.lua')
    home.loc()

    local items = {}
    for i=1, 16 do
        local data = turtle.getItemDetail(i)
        if data ~= nil then
            items[#items + 1] = data.name
        end
    end

    if #items <= 0 then
        print('You must put at least one item in our inventory to dig.')
        return
    end

    local filter = filter_list(items)

    local r, a, d, i = state.combine(
        {
            move_state=move_state.reducer,
            ores=ores.reducer,
        },
        {
            move_state=move_state.actionator,
            ores=ores.actionator
        },
        {
            move_state=move_state.discriminators,
            ores=ores.discriminators
        },
        {
            move_state=move_state.init,
            ores=ores.init
        }
    )

    local store = state.Store:recover('vein_store', r, a, d, i)
    store:dispatch(move_state.update_fuel())
    store:clean_and_save()

    if not store.raw.ores.initialized then
        store:dispatch(ores.set_start_to_cur(store))
    end

    local mem = {}
    while ores.tick(store, mem, 'ores', filter) do end

    store:clean()
    home.delete()
    startup.deject('programs/vein.lua')
end

main()
