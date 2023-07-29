local Result = {
  code = 0,
  data = nil,
  message = "",
}

function Result:new(code, data, message)
  local obj = {}
  setmetatable(obj, self)
  self.__index = self

  self.code = code
  self.data = data
  self.message = message
  return obj
end

return Result
