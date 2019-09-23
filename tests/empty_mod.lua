--- An empty module that can be used with require()
print('empty_mod.lua called')

return {
    foo = function()
        print('foo')
    end
}