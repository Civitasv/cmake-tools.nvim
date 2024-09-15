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

local function buildEnvironment(self)
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

local function expandMacro(self, str)
  if type(str) ~= "string" then
    return str
  end

  str = str:gsub("%$env{(.-)}", function(envVar)
    return self.environment[envVar] or vim.env[envVar] or ""
  end)

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
  str = str:gsub("${hostSystemName}", vim.loop.os_uname().sysname)
  str = str:gsub("${fileDir}", source_path.filename)
  str = str:gsub("${dollar}", "$")
  str = str:gsub("${pathListSep}", "/")

  return str
end

local function resolveBuildDir(self)
  if not self.binaryDir then
    return
  end
  self.binaryDirExpanded = expandMacro(self, self.binaryDir)
  self.binaryDirExpanded = vim.fn.fnamemodify(self.binaryDirExpanded, ":.")
end

local function buildCacheVariables(self)
  local function build(bPreset)
    local env = bPreset.cacheVariables or {}
    for _, inherited in ipairs(bPreset.inheritedPresets) do
      env = vim.tbl_deep_extend("keep", env, build(inherited))
    end

    return env
  end

  self.cacheVariables = build(self)
end

local function resolveCacheVariables(self)
  for key, var in pairs(self.cacheVariables or {}) do
    self.cacheVariables[key] = expandMacro(self, var)
  end
end

local function resolveConditions(self)
  local function evalCondition(preset)
    local function eval(cond)
      if not type(cond) == "table" then
        error("condition field has to be a JSON object")
      end

      local ctype = cond.type
      if not ctype then
        error("condition field missing required field 'type'")
      end

      local function equals()
        if type(cond.lhs) ~= "string" then
          error("condition field missing required string field 'lhs'")
        elseif type(cond.rhs) ~= "string" then
          error("condition field missing required string field 'rhs'")
        end
        return expandMacro(self, cond.lhs) == expandMacro(self, cond.rhs)
      end

      local function inList()
        if type(cond.string) ~= "string" then
          error("condition field missing required string field 'string'")
        end
        if not vim.isarray(cond.list) then
          error("condition field missing required array field 'list'")
        end

        cond.string = expandMacro(self, cond.string)

        for _, entry in ipairs(cond.list) do
          if type(entry) ~= "string" then
            error("list field must be of type string")
          end
          if cond.string == expandMacro(self, self, entry) then
            return true
          end
        end

        return false
      end

      if ctype == "const" then
        if not type(cond.value) == "bool" then
          error("condition type 'const' requires a boolean field 'value'")
        end
        return cond.value
      elseif ctype == "equals" then
        return equals()
      elseif ctype == "notEquals" then
        return not equals()
      elseif ctype == "inList" then
        return inList()
      elseif ctype == "notInList" then
        return not inList()
      elseif ctype == "anyOf" then
        if not vim.isarray(cond.conditions) then
          error("conditions field must be of type array")
        end
        for _, nestedCond in ipairs(cond.conditions) do
          if eval(nestedCond) then
            return true
          end
        end
        return true
      elseif ctype == "allOf" then
        if not vim.isarray(cond.conditions) then
          error("conditions field must be of type array")
        end
        for _, nestedCond in ipairs(cond.conditions) do
          if not eval(nestedCond) then
            return false
          end
        end
        return true
      elseif ctype == "not" then
        if not type(cond.condition) == "table" then
          error("condition field 'condition' must be of type object")
        end
        return not eval(cond.condition)
      else
        -- matches and notMatches currently not supported due to lua's limited regex support
        -- for now, lets just pass the check and let cmake handle the rest
        return true
      end
    end

    if not preset.condition then
      return
    end
    return eval(preset.condition)
  end

  local function checkPreset(preset)
    local queue = { preset }
    local i = 0

    while #queue ~= i do
      local current = queue[i + 1]
      local ret = evalCondition(current)
      if ret ~= nil then
        return ret
      end

      for _, nestedPreset in ipairs(current.inheritedPresets) do
        table.insert(queue, nestedPreset)
      end
      i = i + 1
    end

    return nil
  end
  local enabled = checkPreset(self)

  self.disabled = (enabled ~= nil) and (enabled == false)
end

function Preset:new(cwd, obj, get_preset)
  local instance = createInstance(self, obj, get_preset)
  instance.environment = resolveEnvVars(instance.environment)
  instance.cwd = cwd

  -- gather all environment variables in the top preset
  buildEnvironment(instance)
  -- gather all cache variables in the top preset
  buildCacheVariables(instance)

  resolveBuildDir(instance, cwd)
  resolveCacheVariables(instance)

  -- We have to resolve the environment first as the condition might depend on envVars
  resolveConditions(instance)

  return instance
end

function Preset:get_build_type()
  return self.cacheVariables and self.cacheVariables.CMAKE_BUILD_TYPE or "Debug"
end

return Preset
