---
-- Describes the Mover interface, which is a class which is capable of moving
-- the turtle. Also provides an implementation which stores relative location
-- and direction from a given starting position. Note that after a restart we
-- can always confirm our location to within one move, but it requires a
-- satellite / gps setup to get the exact location.
local mover = {}

---
-- The mover interface. Something which abstracts low-level turtle movements
-- in order to allow for stop/resume functionality.
--
-- @type mover.Mover
mover.Mover = {}

---
-- Performs the given action, which corresponds to a name in the turtle module
-- such as 'up' for an up movement. This should only be used for the movement
-- related functions (turnLeft/turnRight/up/down/forward/back). This should
-- block until success.
-- @param act string the action to take as a name of an attribute in turtle
function mover.Mover:move(act)
    error('mover.Mover is an interface and has no implementation')
end

---
-- Describes a mover which stores the location and direction of the turtle from
-- some reference point. These are absolute coordinates when initialized with
-- absolute coordinates, etc.
--
-- Instance variables
-- filen string where we save our status. we also use filen .. '.bak'
-- loc vector2 where we are right now
-- dir int the direction (0-3) that we are facing (0 is south, 1 is west)
--
-- @type mover.LocationStoreMover
mover.LocationStoreMover = {}

--- Constructs an unitialized location store mover. Should be treated as a
-- private constructor.
-- @return mover.LocationStoreMover a new unitialized instance
function mover.LocationStoreMover:_init()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

--- Construct a new location store mover with the given starting position and
-- direction. If the start is omitted it is treated as the origin. If the
-- direction is omitted, it is treated as south. Note that this is only capable
-- of recoverring post-restart if this is consistent with the result of
-- gps.locate.
-- @param filen where we save our status for recovery. We will also use
-- filen .. '.bak'. For recovery, use mover.LocationStoreMover.recover(filen)
-- @param start vector where we are right now
-- @param start_dir int the direction we are facing (0 is south, 1 is west)
function mover.LocationStoreMover:new(filen, start, start_dir)
    local o = mover.LocationStoreMover:_init()
    o.filen = filen
    o.loc = start
    o.dir = start_dir
    return o
end

-- TODO finish implementing mover.LocationStoreMover

return mover