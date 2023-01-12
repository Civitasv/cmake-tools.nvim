local Path = require("plenary.path")

local presets = {}

-- Checks if there is a CMakePresets.json or CMakeUserPresets.json file
function presets.check()
  -- helper function to find the config file
  -- returns file path if found, nil otherwise
  local function findcfg()
    local files = vim.fn.readdir(".")
    local file = nil
    for _, f in ipairs(files) do -- iterate over files in current directory
      if f == "CMakePresets.json" or f == "CMakeUserPresets.json" then -- if a kits config file is found
        file = vim.fn.resolve("./" .. f)
        break
      end
    end

    return file
  end

  local file = findcfg() -- check for config file

  return file
end

-- Retrieve all presets with type
-- @param type: `buildPresets` or `configurePresets`
-- @param {opts}: include_hidden(bool|nil).
--                If true, hidden preset will be included in result.
-- @returns : list with all preset names
function presets.parse(type, opts)
  local file = presets.check()
  local options = {}
  if not file then
    return options
  end
  local include_hidden = opts and opts.include_hidden
  local data = vim.fn.json_decode(vim.fn.readfile(file))
  for _, v in pairs(data[type]) do
    if include_hidden or not v["hidden"] then
      table.insert(options, v["name"])
    end
  end
  return options
end

-- Retrieve all presets with type
-- @param type: `buildPresets` or `configurePresets`
-- @param {opts}: include_hidden(bool|nil).
--                If true, hidden preset will be included in result.
-- @returns : table with preset name as key and preset content as value
function presets.parse_name_mapped(type, opts)
  local file = presets.check()
  local options = {}
  if not file then
    return options
  end
  local include_hidden = opts and opts.include_hidden
  local data = vim.fn.json_decode(vim.fn.readfile(file))
  for _, v in pairs(data[type]) do
    if include_hidden or not v["hidden"] then
      options[v["name"]] = v
    end
  end
  return options
end

-- Retrieve preset by name and type
-- @param name: from `name` option
-- @param type: `buildPresets` or `configurePresets`
function presets.get_preset_by_name(name, type)
  local file = presets.check()
  if not file then
    return nil
  end
  local data = vim.fn.json_decode(vim.fn.readfile(file))
  for _, v in pairs(data[type]) do
    if v.name == name then
      return v
    end
  end
  return nil
end

-- Retrieve build type from preset
function presets.get_build_type(preset)
  if preset and preset.cacheVariables and preset.cacheVariables.CMAKE_BUILD_TYPE then
    return preset.cacheVariables.CMAKE_BUILD_TYPE
  end
  return "Debug"
end

-- Retrieve build directory from preset
function presets.get_build_dir(preset)
  -- check if this preset is extended
  local function helper(p_preset)
    local build_dir = ""

    if not p_preset then
      return build_dir
    end

    if p_preset.inherits then
      local inherits = p_preset.inherits
      local set_dir_by_parent = function (parent)
          local ppreset = presets.get_preset_by_name(parent, "configurePresets")
          local ppreset_build_dir = helper(ppreset)
          if ppreset_build_dir ~= "" then
            build_dir = ppreset_build_dir
          end
      end

      -- According to `https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html`,
      -- `inherits` field may be a list of strings or a single string.
      -- Check type then act.
      if type(inherits) == "table" then
        -- iterate inherits from end, cause
        -- If multiple inherits presets provide conflicting
        -- values for the same field, the earlier preset in
        -- the inherits array will be preferred.
        for i = #inherits, 1, -1 do
          local parent = inherits[i]

          -- retrieve its parent preset
          set_dir_by_parent(parent)
        end
      elseif type(inherits) == "string" then
        set_dir_by_parent(inherits)
      end
    end

    if p_preset.binaryDir then
      build_dir = p_preset.binaryDir
    end

    return build_dir
  end

  local build_dir = helper(preset)

  -- macro expansion
  local source_path = Path:new(vim.loop.cwd())
  local source_relative = vim.fn.fnamemodify(vim.loop.cwd(), ":t")

  build_dir = build_dir:gsub("${sourceDir}", vim.loop.cwd())
  build_dir = build_dir:gsub("${sourceParentDir}", source_path:parent().filename)
  build_dir = build_dir:gsub("${sourceDirName}", source_relative)
  build_dir = build_dir:gsub("${presetName}", preset.name)
  if preset.generator then
    build_dir = build_dir:gsub("${generator}", preset.generator)
  end
  build_dir = build_dir:gsub("${hostSystemName}", vim.loop.os_uname().sysname)
  build_dir = build_dir:gsub("${fileDir}", source_path.filename)
  build_dir = build_dir:gsub("${dollar}", "$")
  build_dir = build_dir:gsub("${pathListSep}", "/")

  build_dir = vim.fn.fnamemodify(build_dir, ":.")

  return build_dir
end

return presets
