local Path = require("plenary.path")
local Preset = require("cmake-tools.preset")

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

  local data = decode(userPresetFile)

  if presetFile then
    local presetData = decode(presetFile)
    if presetData then
      data = merge_presets(data, presetData)
    end
  end

  local instance = setmetatable(data, self)
  self.__index = self

  local function createPreset(obj)
    local function getPreset(name)
      return instance:get_configure_preset(name, { include_hidden = true, include_disabled = true })
    end
    return Preset:new(cwd, obj, getPreset)
  end

  for _, preset in ipairs(instance.configurePresets) do
    preset = createPreset(preset)
  end

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
  return get_preset(name, self.buildPresets, opts)
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
