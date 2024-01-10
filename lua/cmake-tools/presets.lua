local Path = require("plenary.path")

local presets = {}

-- Checks if there is a CMakePresets.json or CMakeUserPresets.json file
-- in the current directory, a CMakeUserPresets.json is
-- preferred over CMakePresets.json as CMakePresets.json
-- is implicitly included by CMakeUserPresets.json
function presets.check(cwd)
  -- helper function to find the config file
  -- returns file path if found, nil otherwise
  local function findcfg()
    local files = vim.fn.readdir(cwd)
    local file = nil
    local presetFiles = {}
    for _, f in ipairs(files) do -- iterate over files in current directory
      if
        f == "CMakePresets.json"
        or f == "CMakeUserPresets.json"
        or f == "cmake-presets.json"
        or f == "cmake-user-presets.json"
      then -- if a preset file is found
        presetFiles[#presetFiles + 1] = tostring(Path:new(cwd, f))
      end
    end
    table.sort(presetFiles, function(a, b)
      return a < b
    end)
    if #presetFiles > 0 then
      file = presetFiles[#presetFiles]
    end
    return file
  end

  local file = findcfg() -- check for config file

  return file
end

-- Extends (or creates a new) key-value pair in [dest] in which the
-- key is [key] and the value is the resulting list table of merging
-- dst[key] and src[key].
-- This function mutates dest.
local function merge_table_list_by_key(dst, src, key)
  if not dst[key] then
    dst[key] = {}
  end
  vim.list_extend(dst[key], src[key])
end

-- Decodes a Cmake[User]Presets.json and its "includes", if any
-- CMakeUserPresets.json implicitly includes CMakePresets.json if it exists
local function decode(file)
  local data = vim.fn.json_decode(vim.fn.readfile(file))
  if not data then
    error(string.format("Could not parse %s", file))
  end
  local includes = data["include"] and data["include"] or {}
  local includes_is_empty = next(includes) == nil
  local isUserPreset = string.find(file:lower(), "user")
  local parentDir = vim.fs.dirname(file)
  if includes_is_empty and isUserPreset then
    local preset = "CMakePresets.json"
    local presetKebapCase = "cmake-presets.json"
    local presetPath = parentDir .. "/" .. preset
    local presetKebapCasePath = parentDir .. "/" .. presetKebapCase

    if vim.fn.filereadable(presetPath) then
      includes[#includes + 1] = preset
    elseif vim.fn.filereadable(presetKebapCasePath) then
      includes[#includes + 1] = presetKebapCase
    end
  end

  if includes_is_empty then
    return data
  end

  for _, f in ipairs(includes) do
    local f_read_data = nil
    local f_path = Path.new(f)
    if f_path:is_absolute() then
      f_read_data = f_path:read()
    else
      f_read_data = (Path.new(parentDir) / f):read()
    end

    local fdata = vim.fn.json_decode(f_read_data)
    local thisFilePresetKeys = vim.tbl_filter(function(key)
      if string.find(key, "Presets") then
        return true
      else
        return false
      end
    end, vim.tbl_keys(fdata))

    for _, eachPreset in ipairs(thisFilePresetKeys) do
      merge_table_list_by_key(data, fdata, eachPreset)
    end
  end

  return data
end

-- Retrieve all presets with type
-- @param type: `buildPresets` or `configurePresets`
-- @param {opts}: include_hidden(bool|nil).
--                If true, hidden preset will be included in result.
-- @returns : list with all preset names
function presets.parse(type, opts, cwd)
  local file = presets.check(cwd)
  local options = {}
  if not file then
    return options
  end
  local include_hidden = opts and opts.include_hidden
  local data = decode(file)
  if not data then
    error("Error when parsing the presets file")
  end
  if data[type] then
    for _, v in pairs(data[type]) do
      if include_hidden or not v["hidden"] then
        table.insert(options, v["name"])
      end
    end
  end
  return options
end

-- Retrieve all presets with type
-- @param type: `buildPresets` or `configurePresets`
-- @param {opts}: include_hidden(bool|nil).
--                If true, hidden preset will be included in result.
-- @returns : table with preset name as key and preset content as value
function presets.parse_name_mapped(type, opts, cwd)
  local file = presets.check(cwd)
  local options = {}
  if not file then
    return options
  end
  local include_hidden = opts and opts.include_hidden
  local data = decode(file)
  if not data then
    error("Error when parsing the presets file")
  end
  if data[type] then
    for _, v in pairs(data[type]) do
      if include_hidden or not v["hidden"] then
        options[v["name"]] = v
      end
    end
  end
  return options
end

-- Retrieve preset by name and type
-- @param name: from `name` option
-- @param type: `buildPresets` or `configurePresets`
function presets.get_preset_by_name(name, type, cwd)
  local file = presets.check(cwd)
  if not file then
    return nil
  end
  local data = decode(file)
  if data[type] then
    for _, v in pairs(data[type]) do
      if v.name == name then
        return v
      end
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
function presets.get_build_dir(preset, cwd)
  -- check if this preset is extended
  local function helper(p_preset)
    if not p_preset then
      return ""
    end

    if p_preset.binaryDir then
      return p_preset.binaryDir
    end

    local build_dir = p_preset.name
    local inherits = p_preset.inherits
    if inherits then
      local set_dir_by_parent = function(parent)
        local ppreset = presets.get_preset_by_name(parent, "configurePresets", cwd)
        if ppreset ~= nil then
          local ppreset_build_dir = helper(ppreset)
          if ppreset_build_dir ~= "" then
            return ppreset_build_dir
          end
        end
        return nil
      end
      -- According to `https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html`,
      -- `inherits` field may be a list of strings or a single string.
      -- Check type then act.
      if type(inherits) == "table" then
        for _, parent in ipairs(inherits) do
          -- retrieve its parent preset
          local dir = set_dir_by_parent(parent)
          if dir then
            build_dir = dir
            break
          end
        end
      elseif type(inherits) == "string" then
        build_dir = set_dir_by_parent(inherits) or build_dir
      end
    end
    return build_dir
  end

  local build_dir = helper(preset)

  -- macro expansion
  local source_path = Path:new(cwd)
  local source_relative = vim.fn.fnamemodify(cwd, ":t")

  build_dir = build_dir:gsub("${sourceDir}", ".") -- sourceDir is relative to the CMakePresests.json file, and should be relative
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
