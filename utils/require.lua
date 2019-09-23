---
-- Defines the global function 'require' which acts similarly to
-- the require in default lua. Detects if require has already been
-- defined and does nothing in that case.
--
-- Defines the package table with package.loaded and package.path
-- which are meant to act similar to the default. The exact preloading
-- is not the same in all cases and this does not define preload/loadlib.
--
-- The package path is initialized to search one directory up from the
-- current running file. This can be overriden by defining the global
-- require_relative_file

if require then return end

package = {}
package.loaded = {}

if type(require_relative_file) ~= 'string' then
    require_relative_file = shell.getRunningProgram()
end

local file_loc = require_relative_file
local folder_loc = shell.resolve('/' .. file_loc .. '/../..')
package.path = folder_loc .. '/?;' .. folder_loc .. '/?.lua'

local cached_path = nil
local cached_path_arr = nil

--- Accepts a string. If the string does not have exactly one question mark,
-- this raises an error. Otherwise, this returns an array with two elements,
-- the first of which is before the question mark and the second is after
-- the question mark.
-- @param ele string the path element to split on the question mark
-- @return an array of before/after the question mark
local function split_path_element(ele)
    local question_ind = nil
    for i=1, #ele do
        local ch = string.sub(ele, i, i)
        if ch == '?' then
            if question_ind ~= nil then
                error('element ' .. ele .. ' has multiple question marks')
            end

            question_ind = i
        end
    end

    if question_ind == nil then
        error('element ' .. ele .. ' has no question marks')
    end

    return {
        string.sub(ele, 1, question_ind - 1),
        string.sub(ele, question_ind + 1)
    }
end

--- Finds each of the elements of the given path, where each element is
-- separated by a semicolon. The result is an array of arrays, where
-- each array in the result has 2 elements; the part before the ? and
-- the part after the ?.
--
-- @param path string the valid value for package.path
-- @return table of elements in the path
local function get_path_arr(path)
    local result = {}
    local current_start = 1

    for i = 2, #path do
        local ch = string.sub(path, i, i)
        if ch == ';' then
            if i > current_start then
                result[#result + 1] = string.sub(path, current_start, i - 1)
            end
            current_start = i + 1
        end
    end

    if current_start < #path then
        result[#result + 1] = string.sub(path, current_start)
    end

    for i = 1, #result do
        result[i] = split_path_element(result[i])
    end

    return result
end

--- Loads and returns the given module. If the module has already been loaded,
-- it is simply returned rather than run again. Uniqueness is based on the file
-- that would be loaded, not the name of the module.
-- @param modname string the name of the module to load or the relative path to it
-- @return the module
function require(modname)
    if cached_path ~= package.path then
        cached_path = package.path
        cached_path_arr = get_path_arr(cached_path)
    end

    for i = 1, #cached_path_arr do
        local ele = cached_path_arr[i]
        local tar_path = shell.resolve('/' .. ele[1] .. modname .. ele[2])

        if package.loaded[tar_path] then
            return package.loaded[tar_path]
        end

        if fs.exists(tar_path) then
            package.loaded[tar_path] = dofile(tar_path)
            return package.loaded[tar_path]
        end
    end

    for i = 1, #cached_path_arr do
        local ele = cached_path_arr[i]
        local tar_path = shell.resolve('/' .. ele[1] .. modname .. ele[2])
        print('checked ' .. tar_path)
    end

    error('failed to find module ' .. modname)
end
