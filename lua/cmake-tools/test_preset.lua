---@class TestPreset: CMakeTestPreset
local TestPreset = {}
TestPreset.__index = TestPreset

---@return TestPreset
function TestPreset.new(cwd, obj)
  local instance = setmetatable(obj or {}, TestPreset)
  instance.cwd = cwd

  if instance.valid == nil then
    instance.valid = true
  end

  return instance
end

function TestPreset:isValid()
  return self.valid
end

return TestPreset
