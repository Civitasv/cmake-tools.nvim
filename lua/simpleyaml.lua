--[[
MIT License

Copyright (c) 2022 Ole Lübke

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local simpleyaml = {}

-- parses the YAML file at `path` to a Lua table
-- returns `nil` in case of error
function simpleyaml.parse_file(path)
  -- helper function to apply function `f(data)` at `nestingLevel` of `tab`
  local function atNestingLevel(nestingLevel, f, data, tab)
    if nestingLevel == 0 then -- arrived at `nestingLevel`, apply `f`
      f(data, tab)
    else -- go deeper recursively
      atNestingLevel(nestingLevel - 1, f, data, tab[#tab].val)
    end
  end

  -- helper function to insert a new `key` at `nestingLevel` of `tab`
  local function insertKey(key, nestingLevel, tab)
    atNestingLevel(nestingLevel, function(k, t)
      table.insert(t, { key = k, val = {} })
    end, key, tab)
  end

  -- helper function to insert value `str` at `nestingLevel` of `tab`
  local function insertString(str, nestingLevel, tab)
    atNestingLevel(nestingLevel, function(s, t)
      t[#t].val = s
    end, str, tab)
  end

  -- flatten parsing table by removing indices, so the resulting table can directly be indexed with the YAML keys
  local function flatten(parsed)
    local flattened = {}
    for _, item in ipairs(parsed) do -- for all key-value pairs
      if type(item.val) ~= "string" then -- if the value is not a string (it's a table)
        flattened[item.key] = flatten(item.val) -- flatten the table
      else -- if the value is a string
        flattened[item.key] = item.val -- just assign it
      end
    end
    return flattened
  end

  -- start parsing

  -- (try to) open YAML file
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local nestingLevel = 0 -- current nesting level
  local indents = {} -- stack of indents
  local parsed = {} -- resulting table

  for line in file:lines() do -- for all lines in the file
    -- goto next line if current line is empty, a comment, the document start, or a directive
    if
      line:gsub("%s*", "") == ""
      or line:find("^#") ~= nil
      or line:find("^---") ~= nil
      or line:find("^%%") ~= nil
    then
      goto cont_processing_lines
    end

    local indent = line:match("(%s*)%S.*"):len() -- get indent of current line
    if #indents > 0 then -- if stack of indents not empty
      local prevIndent = indents[#indents]

      -- compare with indent of previous line
      if indent > prevIndent then -- if current indent larger, increase nesting level
        nestingLevel = nestingLevel + 1
      elseif indent < prevIndent then -- of current indent smaller, decrease nesting level and ...
        nestingLevel = nestingLevel - 1
        while indents[#indents] > indent do -- ... clean up the stack of indents, tracking the nesting level
          if prevIndent < indents[#indents] then
            nestingLevel = nestingLevel + 1
          elseif prevIndent > indents[#indents] then
            nestingLevel = nestingLevel - 1
          end
          prevIndent = indents[#indents]
          table.remove(indents)
        end
      end
    end
    table.insert(indents, indent) -- insert current indent into stack

    local key = line:match("%s*(.*):") -- read the key from the line (everything before ':')
    if key == "" then -- no key found, error
      return nil
    end
    insertKey(key, nestingLevel, parsed) -- insert the key

    line = line:match(":%s*(.*)%s*") -- read rest of the line (everything after ':')
    -- if there is something, insert the rest of the line as a string value
    -- otherwise, the value is an object, so go ahead to read next line
    if line:len() > 0 then
      insertString(line, nestingLevel, parsed)
    end

    ::cont_processing_lines::
  end

  file:close()

  return flatten(parsed)
end

return simpleyaml
