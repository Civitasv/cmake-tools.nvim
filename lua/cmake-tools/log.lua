local log = {}

function log.notify(msg, log_level)
  vim.notify(msg, log_level, { title = "CMake" })
end

--- Error Message Alert
-- @param msg the error message
function log.error(msg)
  log.notify(msg, vim.log.levels.ERROR)
end

function log.info(msg)
  log.notify(msg, vim.log.levels.INFO)
end

return log
