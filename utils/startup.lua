--- This module handles injecting one or more scripts into the turtles
-- startup. This module assumes it's the only one managing the startup
-- file to work. This makes a strong assumption about the directory structure
-- in the turtle (turtles2/ contains the turtles2 repo)

local startup = {}

--- Initializes the startup by setting the imported paths and importing them
-- all.
function startup._init(paths)
    startup._paths = paths

    for _, path in ipairs(paths) do
        dofile('turtles2/' .. path)
    end
end

--- Replaces the startup file with the current _paths.
function startup._replace()
    local h = fs.open('startup_paths.ini', 'w')
    h.write(textutils.serialize(startup._paths))
    h.close()

    if not fs.exists('startup') then
        local h = fs.open('startup', 'w')
        h.writeLine("if not require then")
        h.writeLine("  require_relative_file = 'turtles2/utils/require.lua'")
        h.writeLine("  dofile('turtles2/utils/require.lua')")
        h.writeLine("end")
        h.writeLine("local startup = require('utils/startup')")
        h.writeLine("local h = fs.open('startup_paths.ini', 'r')")
        h.writeLine("local txt = h.readAll()")
        h.writeLine("h.close()")
        h.writeLine("local paths = textutils.unserialize(txt)")
        h.writeLine("startup._init(paths)")
        h.close()
    end
end

--- Injects the given file into the startup if it is not already there. The
-- file is dofile()'d. The script path should be like "programs/vein.lua"
function startup.inject(script_path)
    if not startup._paths then startup._paths = {} end
    for i, v in ipairs(startup._paths) do
        if v == script_path then return end
    end

    startup._paths[#startup._paths + 1] = script_path
    startup._replace()
end

--- Removes the given file from the startup script.
function startup.deject(script_path)
    if not startup._paths then startup._paths = {} end
    local ind = nil
    for i, v in ipairs(startup._paths) do
        if v == script_path then
            ind = i
            break
        end
    end
    if ind then
        table.remove(startup._paths, ind)
        startup._replace()
    end
end

return startup
