---@class cmake.Result
---@field code number
---@field data any
---@field message string?
local Result = {
  code = 0,
  data = nil,
  message = "",
}

---@return cmake.Result
function Result:new(code, data, message)
  local obj = {}
  setmetatable(obj, { __index = self })

  obj.code = code
  obj.data = data
  obj.message = message
  return obj
end

function Result:new_error(code, message)
  return self:new(code, nil, message)
end

function Result:is_ok()
  return self.code == 0
end

return Result
