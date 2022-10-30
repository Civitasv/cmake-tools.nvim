local variants = {}

local syaml = require("simpleyaml")

local DEFAULT_VARIANTS = { "Debug", "Release", "RelWithDebInfo", "MinSizeRel" }

local function parse()
  local function findcfg()
    local files = vim.fn.readdir(".")
    local file = nil
    local dir = ".."
    while files and not file do
      for _, f in ipairs(files) do
        if f == "cmake-variants.yaml" or f == "cmake-variants.json" then
          dir = dir:match("%.%./((%.%./)*)")
          if not dir then dir = "./" end
          file = vim.fn.resolve(dir .. f)
          break
        end
      end
      files = vim.fn.readdir(dir)
      dir = dir .. "/.."
    end

    return file
  end

  local config = nil

  local file = findcfg()
  if file then
    if file:match(".*%.yaml") then
      config = syaml.parse_file(file)
    else
      config = vim.fn.json_decode(vim.fn.readfile(file))
    end
  end

  return config
end

function variants.get()
  local function collect_choices(config)
    local choices = {}

    for _, option in pairs(config) do
      local cs = {}
      for _, choice in pairs(option["choices"]) do
        table.insert(cs, choice["short"])
      end
      table.insert(choices, cs)
    end

    return choices
  end

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
      local s = T {}
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
      local temp, prod = T {}, T {}
      local function descend(depth)
        for _, v in ipairs(sets[depth]) do
          temp[depth] = v
          if (depth == #sets) then prod[#prod + 1] = clone(temp) else descend(depth + 1) end
        end
      end

      descend(1)
      return prod
    end

    -- END code from rosettacode

    local combinations = cartprod(choices)
    local strings = reduce(combinations, function(t, a) table.insert(a, t:concat(" + ")); return a end, {})

    return strings
  end

  local config = parse()
  if config then
    local choices = collect_choices(config)
    local combinations = create_combinations(choices)
    table.sort(combinations)
    return combinations
  end

  return DEFAULT_VARIANTS
end

function variants.build_arglist(variant)
  local function build_simple(build_type)
    return { "-D", "CMAKE_BUILD_TYPE=" .. build_type }
  end

  for defaultvar in pairs(DEFAULT_VARIANTS) do
    if variant == defaultvar then
      return build_simple(variant)
    end
  end

  local config = parse()
  if not config then
    return {} -- silent error
  end

  local args = {}

  local function add_args(as)
    for _, a in pairs(as) do
      table.insert(args, a)
    end
  end

  for choice in string.gmatch(variant, "%s*([^+]+)%s*") do -- split on +
    local choice_found = false
    choice = choice:match("^%s*(.-)%s*$") -- trim (or come up with a better regex above)
    for _, option in pairs(config) do
      for _, chc in pairs(option["choices"]) do
        local short = chc["short"]
        if choice == short then
          if chc["buildType"] ~= nil then
            add_args({ "-DCMAKE_BUILD_TYPE=" .. chc["buildType"] })
          end
          if chc["settings"] ~= nil then
            for k, v in pairs(chc["settings"]) do
              add_args({ "-D" .. k .. "=" .. v })
            end
          end
          if chc["linkage"] ~= nil then
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
          break
        end
      end
      if choice_found then break end
    end
  end
  return args
end

return variants
