local Path = require("plenary.path")

local Preset = {}

local function createInstance(self, obj, get_preset)
  local instance = setmetatable(obj or {}, self)
  self.__index = self
  instance.inheritedPresets = {}

  if type(instance.inherits) == "string" then
    local nextPreset = get_preset(instance.inherits)
    if nextPreset then
      local p = createInstance(self, nextPreset, get_preset)
      instance.binaryDir = instance.binaryDir or p.binaryDir
      table.insert(instance.inheritedPresets, p)
    end
  else
    if type(instance.inherits) == "table" then
      for _, inherited in ipairs(instance.inherits) do
        local nextPreset = get_preset(inherited)
        if nextPreset then
          local p = createInstance(self, nextPreset, get_preset)
          instance.binaryDir = instance.binaryDir or p.binaryDir
          table.insert(instance.inheritedPresets, p)
        end
      end
    end
  end

  return instance
end

local function resolveEnviroment(self)
  local function build(bPreset)
    local env = bPreset.environment or {}
    for _, inherited in ipairs(bPreset.inheritedPresets) do
      env = vim.tbl_deep_extend("keep", env, build(inherited))
    end

  -- macro expansion
  local source_path = Path:new(self.cwd)
  local source_relative = vim.fn.fnamemodify(self.cwd, ":t")
  str = str:gsub("${sourceDir}", ".") -- sourceDir is relative to the CMakePresests.json file, and should be relative
  str = str:gsub("${sourceParentDir}", source_path:parent().filename)
  str = str:gsub("${sourceDirName}", source_relative)
  str = str:gsub("${presetName}", self.name)
  if self.generator then
    str = str:gsub("${generator}", self.generator)
  end

  local function resolveEnvVars(tbl)
    local function resolve(value, visitedKeys)
      if type(value) ~= "string" then
        return value -- Only resolve string values
      end

      -- Resolve placeholders in the format $env{key}
      return value:gsub("%$env{(.-)}", function(envVar)
        -- Prevent infinite recursion: a key should not refer to itself
        if visitedKeys[envVar] then
          error("Circular reference detected for key: " .. envVar)
        end

        local envValue = tbl[envVar]
        if envValue == nil then
          return vim.env[envVar] or ""
        end

        -- Mark this key as visited to detect circular references
        visitedKeys[envVar] = true
        local ret = resolve(envValue, visitedKeys)
        visitedKeys[envVar] = nil -- Unmark the key after resolving

        return ret
      end)
    end

    -- Loop through all the keys in the table and resolve their values
    local result = {}
    for key, value in pairs(tbl) do
      result[key] = resolve(value, { [key] = true })
    end

    return result
  end

  self.environment = resolveEnvVars(build(self))
end

local function envLookup(str, env)
  return str:gsub("%$env{(.-)}", function(envVar)
    return env[envVar] or vim.env[envVar] or ""
  end)
end

local function resolveBuildDir(self)
  if not self.binaryDir then
    return
  end
  self.buildDir = envLookup(self.binaryDir, self.environment)

  -- macro expansion
  local source_path = Path:new(self.cwd)
  local source_relative = vim.fn.fnamemodify(self.cwd, ":t")
  self.buildDir = self.buildDir:gsub("${sourceDir}", ".") -- sourceDir is relative to the CMakePresests.json file, and should be relative
  self.buildDir = self.buildDir:gsub("${sourceParentDir}", source_path:parent().filename)
  self.buildDir = self.buildDir:gsub("${sourceDirName}", source_relative)
  self.buildDir = self.buildDir:gsub("${selfName}", self.name)
  if self.generator then
    self.buildDir = self.buildDir:gsub("${generator}", self.generator)
  end
  self.buildDir = self.buildDir:gsub("${hostSystemName}", vim.loop.os_uname().sysname)
  self.buildDir = self.buildDir:gsub("${fileDir}", source_path.filename)
  self.buildDir = self.buildDir:gsub("${dollar}", "$")
  self.buildDir = self.buildDir:gsub("${pathListSep}", "/")

  self.buildDir = vim.fn.fnamemodify(self.buildDir, ":.")
end

local function resolveCacheVariables(self)
  for _, var in pairs(self.cacheVariables) do
    var = envLookup(var, self.environment)
  end
end

function Preset:new(cwd, obj, get_preset)
  local instance = createInstance(self, obj, get_preset)
  instance.cwd = cwd

  resolveEnviroment(instance)
  resolveBuildDir(instance)
  resolveCacheVariables(instance)

  return instance
end

function Preset:get_build_type()
  return self.cacheVariables and self.cacheVariables.CMAKE_BUILD_TYPE or "Debug"
end

return Preset
