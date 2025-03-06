local Path = require("plenary.path")
local osys = require("cmake-tools.osys")

local Preset = {}

local function expandMacro(self, str)
  if type(str) == "table" and str.value ~= nil then
    str = str.value
  end

  if type(str) ~= "string" then
    return str
  end

  str = str:gsub("%$env{(.-)}", function(envVar)
    return self.environment[envVar] or vim.env[envVar] or ""
  end)

  str = str:gsub("%$penv{(.-)}", function(envVar)
    return vim.env[envVar] or ""
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
  str = str:gsub("${hostSystemName}", osys.iswin32 and "Windows" or vim.loop.os_uname().sysname)
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
          if cond.string == expandMacro(self, entry) then
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

local function resolveEnvVars(self)
  local function resolve(value, visitedKeys)
    if type(value) ~= "string" then
      return value -- Only resolve string values
    end

    -- Resolve placeholders in the format $env{key}
    value = value:gsub("%$env{(.-)}", function(envVar)
      -- Prevent infinite recursion: a key should not refer to itself
      if visitedKeys[envVar] then
        error("Circular reference detected for key: " .. envVar)
      end

      local envValue = self.environment[envVar]
      if envValue == nil then
        return vim.env[envVar] or ""
      end

      -- Mark this key as visited to detect circular references
      visitedKeys[envVar] = true
      local ret = resolve(envValue, visitedKeys)
      visitedKeys[envVar] = nil -- Unmark the key after resolving

      return ret
    end)

    return value:gsub("%$penv{(.-)}", function(envVar)
      return vim.env[envVar] or ""
    end)
  end

  -- Loop through all the keys in the table and resolve their values
  for key, value in pairs(self.environment) do
    self.environment[key] = resolve(value, { [key] = true })
  end
end

local function parseTree(self, get_preset)
  local queue = { self }
  local queueIdx = 0

  while #queue ~= queueIdx do
    local current = queue[queueIdx + 1]
    current = setmetatable(current, self)

    current.environment = current.environment or {}
    current.cacheVariables = current.cacheVariables or {}
    current.inheritedPresets = current.inheritedPresets or {}

    local function update(nextPresetName)
      local nextPreset = get_preset(nextPresetName)
      if nextPreset then
        table.insert(current.inheritedPresets, nextPreset)
        table.insert(queue, nextPreset)
      end
    end

    if type(current.inherits) == "string" then
      update(current.inherits)
    else
      if type(current.inherits) == "table" then
        for _, inherited in ipairs(current.inherits) do
          update(inherited)
        end
      end
    end

    queueIdx = queueIdx + 1
  end

  local queueSize = #queue
  if queueSize > 1 then
    -- Iterate from the back to pull the parents value down the inheritance hierarchy
    for i = queueSize - 1, 1, -1 do
      local current = queue[i]
      for _, parent in ipairs(current.inheritedPresets) do
        current.environment = vim.tbl_deep_extend("keep", current.environment, parent.environment)
        current.binaryDir = current.binaryDir or parent.binaryDir
        current.cacheVariables =
          vim.tbl_deep_extend("keep", current.cacheVariables, parent.cacheVariables)
      end
    end
  end
end

function Preset:new(cwd, obj, get_preset)
  local instance = setmetatable(obj or {}, self)
  instance.__index = self
  instance.environment = instance.environment or {}
  instance.cwd = cwd

  parseTree(instance, get_preset)
  resolveEnvVars(instance)
  resolveCacheVariables(instance)
  resolveBuildDir(instance)
  -- We have to resolve the environment first as the condition might depend on envVars
  resolveConditions(instance)

  return instance
end

function Preset:get_build_type()
  return self.cacheVariables and self.cacheVariables.CMAKE_BUILD_TYPE or "Debug"
end

return Preset
