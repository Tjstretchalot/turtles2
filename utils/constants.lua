--- Contains constants that are useful
local constants = {}

--- Accepts right turns from south as the first key, and another for the second
-- key, and returns the distance in turns between the two.
constants.TURN_DISTANCES = {
    [0] = {[0] = 0, [1] = 1, [2] = 2, [3] = 1},
    [1] = {[0] = 1, [1] = 0, [2] = 1, [3] = 2},
    [2] = {[0] = 2, [1] = 1, [2] = 0, [3] = 1},
    [3] = {[0] = 1, [1] = 2, [2] = 1, [3] = 0}
}

constants.LEFT_DIRS = {
    [0] = 3,
    [1] = 0,
    [2] = 1,
    [3] = 2
}

constants.RIGHT_DIRS = {
    [0] = 1,
    [1] = 2,
    [2] = 3,
    [3] = 0
}

constants.BACK_DIRS = {
    [0] = 2,
    [1] = 3,
    [2] = 0,
    [3] = 1
}

constants.DELTA_TO_DIR = {
    ['0,1'] = 0,
    ['-1,0'] = 1,
    ['0,-1'] = 2,
    ['1,0'] = 3
}

constants.DIR_TO_NAME = {
    [0] = 'south',
    [1] = 'west',
    [2] = 'north',
    [3] = 'east'
}

constants.DIR_TO_DELTA = {
    [0] = vector.new(0, 0, 1),
    [1] = vector.new(-1, 0, 0),
    [2] = vector.new(0, 0, -1),
    [3] = vector.new(1, 0, 0)
}

constants.UP_DIR = vector.new(0, 1, 0)
constants.DOWN_DIR = vector.new(0, -1, 0)

--- The six neighboring blocks to the origin
constants.NEIGHBORS = {
    vector.new(-1, 0, 0),
    vector.new(1, 0, 0),
    vector.new(0, -1, 0),
    vector.new(0, 1, 0),
    vector.new(0, 0, -1),
    vector.new(0, 0, 1),
}

--- Maps the indices found by DIR_AND_DELTA_TO_FN_IND to the corresponding
-- dig function.
constants.DIG_FN = {'digUp', 'digDown', 'dig'}

--- Maps the indices found by DIR_AND_DELTA_TO_FN_IND to the corresponding
-- inspect function.
constants.INSPECT_FN = {'inspectUp', 'inspectDown', 'inspect'}

--- Maps the indices found by DIR_AND_DELTA_TO_FN_IND to the corresponding
-- detect function.
constants.DETECT_FN = {'detectUp', 'detectDown', 'detect'}

--- DETECT_FN for suck
constants.SUCK_FN = {'suckUp', 'suckDown', 'suck'}

--- DETECT_FN for drop
constants.DROP_FN = {'dropUp', 'dropDown', 'drop'}

--- DETECT_FN for place
constants.PLACE_FN = {'placeUp', 'placeDown', 'place'}


--- Takes two keys; the first is the current relative direction. The second is
-- the relative offset for a block. The value is nil if that block cannot be
-- dug/inspected from the current position. Otherwise, returns the index in
-- either DIG_FN or INSPECT_FN or DETECT_FN for the name of the attribute in
-- the turtle module which digs/inspects the target block.
constants.DIR_AND_DELTA_TO_FN_IND = {
    [0] = {
        ['0,1,0'] = 1,
        ['0,-1,0'] = 2,
        ['0,0,1'] = 3
    },
    [1] = {
        ['0,1,0'] = 1,
        ['0,-1,0'] = 2,
        ['-1,0,0'] = 3
    },
    [2] = {
        ['0,1,0'] = 1,
        ['0,-1,0'] = 2,
        ['0,0,-1'] = 3
    },
    [3] = {
        ['0,1,0'] = 1,
        ['0,-1,0'] = 2,
        ['1,0,0'] = 3
    },
}

constants.MOVE_TO_FN_IND = {
    up = 1,
    down = 2,
    forward = 3
}

constants.TIME_MORNING = 6
constants.TIME_EVENING = 19

-- The 9 inventory space indexes that make up the 3x3 crafting grid
-- for crafty turtles
constants.CRAFTING_SLOTS = {
    1, 2, 3,
    5, 6, 8,
    10, 11, 12
}

-- The lookup dictionary for CRAFTING_SLOTS; the value is
-- true if the key is a value in CRAFTING_SLOTS
constants.CRAFTING_SLOT_LOOKUP = {}
for _, v in ipairs(constants.CRAFTING_SLOTS) do
    constants.CRAFTING_SLOT_LOOKUP[v] = true
end

return constants
