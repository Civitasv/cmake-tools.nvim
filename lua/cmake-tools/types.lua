local function enum(tbl)
  local length = #tbl
  for i = 1, length do
    local v = tbl[i]
    tbl[v] = i
  end

  return tbl
end

local ErrorTypes = enum({
  "NOT_CONFIGURED",
  "NOT_SELECT_LAUNCH_TARGET",
  "SELECTED_LAUNCH_TARGET_NOT_BUILT",
  "NOT_A_LAUNCH_TARGET",
  "NOT_EXECUTABLE",
  "CANNOT_FIND_CMAKE_CONFIGURATION_FILE",
  "CANNOT_FIND_CODEMODEL_FILE",
  "CANNOT_DEBUG_LAUNCH_TARGET",
})

local SuccessTypes = enum({
  "SUCCESS",
})

return function()
  return ErrorTypes, SuccessTypes
end
