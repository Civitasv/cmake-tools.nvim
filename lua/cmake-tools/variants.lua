--[[ local utils = require("cmake-tools.utils") ]]
local variants = {}

local syaml = require("simpleyaml")

-- fallback if no cmake-variants.[yaml|json] is found
local DEFAULT_VARIANTS = { "Debug", "Release", "RelWithDebInfo", "MinSizeRel" }
local DEFAULT_VARIANTS_VAL = {
  { short = "Debug", long = "" },
  { short = "Release", long = "" },
  { short = "RelWithDebInfo", long = "" },
  { short = "MinSizeRel", long = "" },
}

-- checks if there is a cmake-variants.[yaml|json] file and parses it to a Lua table
function variants.parse()
  -- helper function to find the config file
  -- returns file path if found, nil otherwise
  local function findcfg()
    local files = vim.fn.readdir(".")
    local file = nil
    for _, f in ipairs(files) do -- iterate over files in current directory
      if
        f == "cmake-variants.yaml"
        or f == "cmake-variants.json"
        or f == "CMakeVariants.yaml"
        or f == "CMakeVariants.json"
      then -- if a variants config file is found
        file = vim.fn.resolve("./" .. f)
        break
      end
    end

    return file
  end

  -- start parsing

  local config = nil

  local file = findcfg() -- check for config file
  if file then -- if one is found ...
    if file:match(".*%.yaml") then -- .. and is a YAML file, parse it with simpleyaml
      config = syaml.parse_file(file)
    else -- otherwise parse it with neovim's JSON parser
      config = vim.fn.json_decode(vim.fn.readfile(file))
    end
  end

  return config
end

-- returns a list of string descriptions of all possible combinations of configurations, using their short names and optional detailed description
function variants.get(variants_opt)
  -- helper function to collect all short names of choices
  local function collect_choices(config)
    local choices = {}

    for _, option in pairs(config) do -- for all options
      local cs = {}
      for _, choice in pairs(option["choices"]) do -- for all choices of that option
        table.insert(cs, choice) -- collect their short name
      end
      table.insert(choices, cs)
    end

    return choices
  end

  -- helper function to create all possible combinations of choices (cartesian product)
  local function create_combinations(choices)
    -- The following code is a *modified* version of
    -- https://rosettacode.org/wiki/Cartesian_product_of_two_or_more_lists#Functional-esque_(non-iterator)
    -- under CC-BY-SA 4.0
    -- accessed: 01.10.22
    -- BEGIN code from rosettacode

    -- support:
    local function T(t)
      return setmetatable(t, { __index = table })
    end

    local function clone(t)
      local s = T({})
      for k, v in ipairs(t) do
        s[k] = v
      end
      return s
    end

    local function reduce(t, f, acc)
      for i = 1, #t do
        acc = f(t[i], acc)
      end
      return acc
    end

    -- implementation:
    local function cartprod(sets)
      local temp, prod = T({}), T({})
      local function descend(depth)
        for _, v in ipairs(sets[depth]) do
          temp[depth] = v
          if depth == #sets then
            prod[#prod + 1] = clone(temp)
          else
            descend(depth + 1)
          end
        end
      end

      descend(1)
      return prod
    end

    -- END code from rosettacode
    local combinations = cartprod(choices)
    local strings = reduce(combinations, function(t, a)
      local function handleItem()
        local res = { short = "", long = "" }

        for i = 1, #t do
          res.short = res.short .. t[i]["short"]
          if i ~= #t then
            res.short = res.short .. " + "
          end
        end

        if variants_opt.long.show then
          local length = 0
          local max_length = variants_opt.long.max_length
          res.long = res.long .. "("
          length = length + 1

          for i = 1, #t do
            local detailed = t[i]["long"]
            -- if too long, then just show ...
            if length + #detailed >= max_length then
              res.long = res.long .. string.sub(detailed, 1, max_length - length) .. "..."
              break
            end
            res.long = res.long .. detailed
            if i ~= #t then
              res.long = res.long .. " + "
            end
            length = length + #detailed + 3
          end

          res.long = res.long .. ")"
        end
        return res
      end

      table.insert(a, handleItem())
      return a
    end, {})

    return strings
  end

  -- start parsing

  local config = variants.parse()
  if config then -- if a config is found
    local choices = collect_choices(config) -- collect all possible choices from it
    local combinations = create_combinations(choices) -- calculate the cartesian product
    table.sort(combinations, function(lhs, rhs)
      return lhs.short < rhs.short
    end) -- sort lexicographically
    return combinations
  end -- otherwise return the defaults

  return DEFAULT_VARIANTS_VAL
end

function variants.debuggable(variant)
  -- check if the chosen variants is one of the defaults
  for _, defaultvar in ipairs(DEFAULT_VARIANTS) do
    if variant == defaultvar then
      return variant == "Debug" or variant == "RelWithDebInfo"
    end
  end

  -- otherwise, find the config file to parse
  local config = variants.parse()
  if not config then
    return false -- silent error (empty arglist) if no config file found
  end

  -- for each choice in the chosen variant
  for choice in string.gmatch(variant, "%s*([^+]+)%s*") do -- split variant string on + to get choices
    local choice_found = false
    choice = choice:match("^%s*(.-)%s*$") -- trim (or come up with a better regex above)
    for _, option in pairs(config) do -- search for the choice
      for _, chc in pairs(option["choices"]) do
        local short = chc["short"]
        if choice == short then -- if the choice is found, add to the argument list according to the defined keys
          if chc["buildType"] ~= nil then -- CMAKE_BUILD_TYPE
            return chc["buildType"] == "Debug" or chc["buildType"] == "RelWithDebInfo"
          end
          choice_found = true
          break -- choice found, break loops
        end
      end
      if choice_found then
        break
      end
    end
  end
  return false
end

-- given a variant, build an argument list for CMake
function variants.build_arglist(variant)
  -- helper function to build a simple command line option that defines the CMAKE_BUILD_TYPE variable to `build_type`
  local function build_simple(build_type)
    return { "-D", "CMAKE_BUILD_TYPE:STRING=" .. build_type }
  end

  -- start building arglist

  -- check if the chosen variants is one of the defaults
  for _, defaultvar in pairs(DEFAULT_VARIANTS) do
    if variant == defaultvar then
      return build_simple(variant) -- if so, build the simple arglist and return
    end
  end

  -- otherwise, find the config file to parse
  local config = variants.parse()
  if not config then
    return {} -- silent error (empty arglist) if no config file found
  end

  local args = {}

  -- local function to add an argument to `args`
  local function add_args(as)
    for _, a in pairs(as) do
      table.insert(args, a)
    end
  end

  -- for each choice in the chosen variant
  for choice in string.gmatch(variant, "%s*([^+]+)%s*") do -- split variant string on + to get choices
    local choice_found = false
    choice = choice:match("^%s*(.-)%s*$") -- trim (or come up with a better regex above)
    for _, option in pairs(config) do -- search for the choice
      for _, chc in pairs(option["choices"]) do
        local short = chc["short"]
        if choice == short then -- if the choice is found, add to the argument list according to the defined keys
          if chc["buildType"] ~= nil then -- CMAKE_BUILD_TYPE
            add_args({ "-DCMAKE_BUILD_TYPE=" .. chc["buildType"] })
          end
          if chc["settings"] ~= nil then -- user DEFINITIONs
            for k, v in pairs(chc["settings"]) do
              add_args({ "-D" .. k .. "=" .. v })
            end
          end
          if chc["linkage"] ~= nil then -- BUILD_SHARED_LIBS
            local function add_linkage(linkage)
              add_args({ "-DBUILD_SHARED_LIBS=" .. linkage })
            end

            if chc["linkage"] == "static" then
              add_linkage("OFF")
            elseif chc["linkage"] == "shared" then
              add_linkage("ON")
            end
          end
          choice_found = true
          break -- choice found, break loops
        end
      end
      if choice_found then
        break
      end
    end
  end
  return args
end

return variants
