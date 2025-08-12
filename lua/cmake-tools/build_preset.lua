local Path = require("plenary.path")
local osys = require("cmake-tools.osys")

local BuildPreset = {}

function BuildPreset:new(cwd, obj)
  local instance = setmetatable(obj or {}, { __index = self })
  instance.__index = self
  instance.environment = instance.environment or {}
  instance.cwd = cwd

  if instance.valid == nil then
    instance.valid = true
  end

  return instance
end

function BuildPreset:get_build_target()
  if self.targets == nil then
    return nil
  end
  if type(self.targets) == "string" then
    return { self.targets }
  elseif type(self.targets) == "table" then
    return self.targets
  end
  return nil
end

function BuildPreset:get_build_type()
  if self.configuration == nil then
    return nil
  end
  return self.configuration
end

function BuildPreset:is_valid()
  return self.valid
end

return BuildPreset
