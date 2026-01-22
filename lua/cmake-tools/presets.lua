local Path = require("plenary.path")
local Preset = require("cmake-tools.preset")
local BuildPreset = require("cmake-tools.build_preset")

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

local KNOWN_PRESET_KEYS = {
  configurePresets = true,
  buildPresets = true,
  testPresets = true,
  packagePresets = true,
  workflowPresets = true,
}

-- Decodes a Cmake[User]Presets.json and its "includes", if any
-- CMakeUserPresets.json implicitly includes CMakePresets.json if it exists
local function decode(file, visited)
  visited = visited or {}
  local abs_file_path = vim.fn.fnamemodify(file, ":p")

  if visited[abs_file_path] then
    return {}
  end

  local file_path = Path:new(abs_file_path)
  if not file_path:exists() or file_path:is_dir() then
    return {} -- Do not error on missing include
  end

  visited[abs_file_path] = true

  local data = vim.fn.json_decode(file_path:read())
  if not data then
    error(string.format("Could not parse %s", abs_file_path))
  end
  local includes = data.include or {}
  local parentDir = vim.fs.dirname(abs_file_path)

  local filename_lower = vim.fn.fnamemodify(abs_file_path, ":t"):lower()
  local is_user_preset = filename_lower == "cmakeuserpresets.json"
    or filename_lower == "cmake-user-presets.json"

  if #includes == 0 and is_user_preset then
    local preset_pascal_case = "CMakePresets.json"
    local preset_kebab_case = "cmake-presets.json"
    local preset_pascal_case_path = tostring(Path:new(parentDir) / preset_pascal_case)
    local preset_kebab_case_path = tostring(Path:new(parentDir) / preset_kebab_case)

    if vim.fn.filereadable(preset_pascal_case_path) > 0 then
      includes[#includes + 1] = preset_pascal_case
    elseif vim.fn.filereadable(preset_kebab_case_path) > 0 then
      includes[#includes + 1] = preset_kebab_case
    end
  end

  if #includes == 0 then
    return data
  end

  for _, include_path in ipairs(includes) do
    local included_file_str
    local f_path = Path:new(include_path)
    if f_path:is_absolute() then
      included_file_str = include_path
    else
      included_file_str = tostring(Path:new(parentDir) / include_path)
    end

    local included_data = decode(included_file_str, visited)
    for key, _ in pairs(included_data) do
      if KNOWN_PRESET_KEYS[key] then
        merge_table_list_by_key(data, included_data, key)
      end
    end
  end

  return data
end

local Presets = {}

function Presets:parse(cwd)
  local function merge_presets(lhs, rhs)
    local ret = vim.deepcopy(lhs)
    for k, v2 in pairs(rhs) do
      local v1 = ret[k]

      if v1 == nil then
        ret[k] = vim.deepcopy(v2)
      else
        if type(v1) == "table" and type(v2) == "table" then
          if vim.isarray(v1) and vim.isarray(v2) then
            for _, v in ipairs(v2) do
              table.insert(v1, v)
            end
          else
            merge_presets(v1, v2)
          end
        else
          -- If not tables or arrays, keep lhs
        end
      end
    end

    return ret
  end

  local userPresetFile, presetFile = self.find_preset_files(cwd)

  local visited = {}
  local data = decode(userPresetFile, visited)

  if presetFile then
    local presetData = decode(presetFile, visited)
    if presetData then
      data = merge_presets(data, presetData)
    end
  end

  -- Instance extends self
  local instance = setmetatable(data, self)
  self.__index = self

  local function createPreset(obj)
    local function getPreset(name)
      return instance:get_configure_preset(name, { include_hidden = true, include_disabled = true })
    end
    return Preset:new(cwd, obj, getPreset)
  end

  local function createBuildPreset(obj)
    return BuildPreset:new(cwd, obj)
  end

  for _, preset in ipairs(instance.configurePresets) do
    preset = createPreset(preset)
  end

  instance.buildPresets = instance.buildPresets or {}
  for _, build_preset in ipairs(instance.buildPresets) do
    build_preset = createBuildPreset(build_preset)
  end

  table.insert(instance.buildPresets, createBuildPreset({ name = "None", valid = false }))

  return instance
end

-- Retrieve all preset names for the given type
-- @param type: `buildPresets` or `configurePresets`
-- @param {opts}: include_hidden(bool|nil).
--                If true, hidden preset will be included in result.
-- @returns : list with all preset names
local function get_preset_names(presets, opts)
  local options = {}
  local include_hidden = opts and opts.include_hidden
  local include_disabled = opts and opts.include_disabled

  if presets then
    for _, v in pairs(presets) do
      if include_disabled or not v.disabled then
        if include_hidden or not v.hidden then
          table.insert(options, v.name)
        end
      end
    end
  end
  return options
end

function Presets:get_configure_preset_names(opts)
  return get_preset_names(self.configurePresets, opts)
end

function Presets:get_build_preset_names(opts)
  local presets = get_preset_names(self.buildPresets, opts)
  local ret = {}
  for _, bpreset in ipairs(presets) do
    local cpresetName = self:get_build_preset(bpreset, opts).configurePreset

    if not cpresetName then
      table.insert(ret, bpreset)
    else
      local cpreset = self:get_configure_preset(
        cpresetName,
        { include_hidden = true, include_disabled = opts.include_disabled }
      )
      if cpreset and (opts.include_disabled or not cpreset.disabled) then
        table.insert(ret, bpreset)
      end
    end
  end

  return ret
end

local function get_preset(name, tbl, opts)
  local include_hidden = opts and opts.include_hidden
  local include_disabled = opts and opts.include_disabled
  if tbl then
    for _, v in pairs(tbl) do
      if v.name == name then
        if include_disabled or not v.disabled then
          if include_hidden or not v.hidden then
            return v
          end
        end
      end
    end
  end
end

function Presets:get_configure_preset(name, opts)
  return get_preset(name, self.configurePresets, opts)
end

function Presets:get_build_preset(name, opts)
  return get_preset(name, self.buildPresets, { include_hidden = true, include_disabled = true })
end

function Presets.find_preset_files(cwd)
  local files = vim.fn.readdir(cwd)
  local presetFiles = {}
  for _, f in ipairs(files) do -- iterate over files in current directory
    if
      f == "CMakePresets.json"
      or f == "CMakeUserPresets.json"
      or f == "cmake-presets.json"
      or f == "cmake-user-presets.json"
    then -- if a preset file is found
      table.insert(presetFiles, tostring(Path:new(cwd, f)))
    end
  end
  table.sort(presetFiles, function(a, b)
    return a > b
  end)

  return unpack(presetFiles)
end

function Presets.exists(cwd)
  return Presets.find_preset_files(cwd) ~= nil
end

return Presets
