local function enum(tbl)
  local length = #tbl
  for i = 1, length do
    local v = tbl[i]
    tbl[v] = i
  end

  return tbl
end

local Types = enum({
  "SUCCESS",
  "NOT_CONFIGURED",
  "NOT_SELECT_LAUNCH_TARGET",
  "NOT_SELECT_BUILD_TARGET",
  "SELECTED_LAUNCH_TARGET_NOT_BUILT",
  "NOT_A_LAUNCH_TARGET",
  "NOT_EXECUTABLE",
  "CANNOT_FIND_CMAKE_CONFIGURATION_FILE",
  "CANNOT_FIND_CODEMODEL_FILE",
  "CANNOT_CREATE_CODEMODEL_QUERY_FILE",
  "CANNOT_DEBUG_LAUNCH_TARGET",
  "CANNOT_CREATE_DIRECTORY",
})

return Types
