local Path = require("plenary.path")
local osys = require("cmake-tools.osys")

local BuildPreset = {}

-- 'None' instance for when no build preset should be used.
BuildPreset.None = {
  is_none = true,
  get_build_target = function()
    return ""
  end,
  get_build_type = function()
    return nil
  end,
}
setmetatable(BuildPreset.None, { __index = BuildPreset })

function BuildPreset:new(cwd, obj)
  local instance = setmetatable(obj or {}, { __index = self })
  instance.__index = self
  instance.environment = instance.environment or {}
  instance.cwd = cwd

  return instance
end

function BuildPreset:get_build_target()
  if self.targets == nil then
    return ""
  end
  if type(self.targets) == "string" then
    return self.targets
  elseif type(self.targets) == "table" then
    return table.concat(self.targets, " ")
  end
  return ""
end

function BuildPreset:get_build_type()
  if self.configuration == nil then
    return nil
  end
  return self.configuration
end

return BuildPreset
