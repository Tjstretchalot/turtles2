--- This module makes it easy to determine where "home" should be through
-- persistant restarts. The general idea is that home is at "home.loc(filen)".
-- If GPS information is available, home will be the correct absolute location
-- and direction. Otherwise, home will be the origin and facing south, and
-- coordinates will instead be relative (as there is no absolute truth). This
-- is a very specific case of a waypoint.
local gps_locate = require('utils/gps_locate')

local home = {}

function home._init()
    if fs.exists('home.ini') then
        local h = fs.open('home.ini', 'r')
        local txt = h.readAll()
        h.close()

        local loc = textutils.unserialize(txt)
        if loc ~= nil then
            home._loc = loc
            return
        end
        fs.delete('home.ini')
    end

    local just_loc, dir = gps_locate.locate()
    if just_loc then
        home._loc = {
            x = just_loc.x,
            y = just_loc.y,
            z = just_loc.z,
            dir = dir,
            absolute=true
        }
    else
        home._loc = {x=0, y=0, z=0, dir=0, absolute=false}
    end

    local h = fs.open('home.ini', 'w')
    h.write(textutils.serialize(home._loc))
    h.close()
end

--- Clears the home location if there is one
function home.delete()
    if fs.exists('home.ini') then
        fs.delete('home.ini')
    end

    home._loc = nil
end

--- Gets the home location, which is either the origin facing south
-- if there is no GPS or the absolute location where we started if
-- we could use a GPS to determine it.
-- @return vector, number the location and direction of home
function home.loc()
    if not home._loc then home._init() end

    return vector.new(home._loc.x, home._loc.y, home._loc.z), home._loc.dir
end

--- Determines if the home location is in absolute or relative coordinates
-- @return boolean true if home is relative, false if home is absolute
function home.absolute()
    if not home._loc then home._init() end

    return home._loc.absolute
end

return home
