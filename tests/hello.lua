--- This is just used to verify the install is working correctly and you are
-- running the files correctly.

package.path = '../?.lua;turtles2/?.lua'

local empty_mod = require('tests/empty_mod')
require('tests/empty_mod')
empty_mod.foo()

print('tests/hello.lua completed')
