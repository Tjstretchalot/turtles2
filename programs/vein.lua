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

dofile('turtles2/utils/require.lua')

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

local function init_ctx()
    local poss = ores.OreContext.recover_possible('vein_ores_ctx')
    if #poss == 1 then return poss[1] end

    poss = ores.OreContext.recover_with_fuel(poss)
    if #poss == 1 then return poss[1] end

    if home.absolute() then
        local hloc, hdir = home.loc()
        poss = ores.OreContext.recover_with_gps(poss, hloc, hdir)
        if #poss == 1 then return poss[1] end
    end

    poss = ores.OreContext.recover_with_guess(poss)
    return poss[1]
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
    local ctx = init_ctx()
    ctx:clean_and_save()
    while ctx:next(filter) do end

    startup.deject('programs/vein.lua')
    fs.delete('vein_ores_ctx')
    home.delete()
end

main()
