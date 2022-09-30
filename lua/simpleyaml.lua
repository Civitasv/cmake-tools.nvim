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

function simpleyaml.parse_file(path)
  local function atNestingLevel(nestingLevel, f, data, tab)
    if nestingLevel == 0 then
      f(data, tab)
    else
      atNestingLevel(nestingLevel - 1, f, data, tab[#tab].val)
    end
  end

  local function insertKey(key, nestingLevel, tab)
    atNestingLevel(
      nestingLevel,
      function(k, t)
        table.insert(t, { key = k, val = {} })
      end,
      key,
      tab
    )
  end

  local function insertString(str, nestingLevel, table)
    atNestingLevel(
      nestingLevel,
      function(s, t)
        t[#t].val = s
      end,
      str,
      table
    )
  end

  local function flatten(parsed)
    local flattened = {}
    for _, item in ipairs(parsed) do
      if type(item.val) ~= "string" then
        flattened[item.key] = flatten(item.val)
      else
        flattened[item.key] = item.val
      end
    end
    return flattened
  end

  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local nestingLevel = 0
  local indents      = {}
  local parsed       = {}

  for line in file:lines() do
    if line:gsub("%s*", "") == "" or line:find("^#") ~= nil or line:find("^---") ~= nil then
      goto cont_processing_lines
    end

    local indent = line:match("(%s*)%S.*"):len()
    if #indents > 0 then
      local prevIndent = indents[#indents]

      if indent > prevIndent then
        nestingLevel = nestingLevel + 1;
      elseif indent < prevIndent then
        nestingLevel = nestingLevel - 1;
        while indents[#indents] > indent do
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
    table.insert(indents, indent)

    local key = line:match("%s*(.*):")
    insertKey(key, nestingLevel, parsed)

    line = line:match(":%s*(.*)%s*")
    if line:len() > 0 then
      insertString(line, nestingLevel, parsed)
    end

    ::cont_processing_lines::
  end

  file:close()

  return flatten(parsed)
end

return simpleyaml
