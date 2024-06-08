local Path = require("plenary.path")
local osys = require("cmake-tools.osys")
local Result = require("cmake-tools.result")
local Types = require("cmake-tools.types")
local notification = require("cmake-tools.notification")
local scratch = require("cmake-tools.scratch")

---@alias executor_conf {name:string, opts:table}
---@alias runner_conf {name:string, opts:table}

local utils = {}

function utils.get_cmake_configuration(cwd)
  local cmakelists = Path:new(cwd, "CMakeLists.txt")
  if not cmakelists:is_file() then
    return Result:new(
      Types.CANNOT_FIND_CMAKE_CONFIGURATION_FILE,
      nil,
      "Cannot find CMakeLists.txt at cwd (" .. cwd .. ")."
    )
  end
  return Result:new(Types.SUCCESS, cmakelists, "cmake-tools has found CMakeLists.txt.")
end

-- Get string representation for object o
function utils.dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k .. '"'
      end
      s = s .. "[" .. k .. "] = " .. utils.dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

function utils.get_path(str, sep)
  sep = sep or (osys.iswin32 and "\\" or "/")
  return str:match("(.*" .. sep .. ")")
end

function utils.mkdir(dir)
  local _dir = Path:new(dir)
  _dir:mkdir({ parents = true, exists_ok = true })
end

function utils.rmfile(file)
  if file:exists() then
    file:rm()
  end
end

function utils.file_exists(path)
  local file = Path:new(path)
  if not file:exists() then
    return false
  end
  return true
end

function utils.deepcopy(orig, copies)
  copies = copies or {}
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    if copies[orig] then
      copy = copies[orig]
    else
      copy = {}
      copies[orig] = copy
      for orig_key, orig_value in next, orig, nil do
        copy[utils.deepcopy(orig_key, copies)] = utils.deepcopy(orig_value, copies)
      end
      setmetatable(copy, utils.deepcopy(getmetatable(orig), copies))
    end
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function utils.softlink(src, target)
  if utils.file_exists(src) and not utils.file_exists(target) then
    -- if we don't always use terminal
    local cmd = "exec "
      .. "'!cmake -E create_symlink "
      .. utils.transform_path(src)
      .. " "
      .. utils.transform_path(target)
      .. "'"
    vim.cmd(cmd)
  end
end

function utils.transform_path(path, keep)
  if keep then
    return path
  end
  if path[1] ~= '"' and string.find(path, " ") then
    return '"' .. path .. '"'
  else
    return path
  end
end

--- Get the appropriate executor by name
---@param name string
---@return executor
function utils.get_executor(name)
  return require("cmake-tools.executors")[name]
end

--- Get the appropriate runner by name
---@param name string
---@return runner
function utils.get_runner(name)
  return require("cmake-tools.runners")[name]
end

---@param executor_data executor_conf
function utils.show_executor(executor_data)
  utils.get_executor(executor_data.name).show(executor_data.opts)
end

---@param runner_data runner_conf
function utils.show_runner(runner_data)
  utils.get_runner(runner_data.name).show(runner_data.opts)
end

---@param executor_data executor_conf
function utils.close_executor(executor_data)
  utils.get_executor(executor_data.name).close(executor_data.opts)
end

---@param runner_data runner_conf
function utils.close_runner(runner_data)
  utils.get_runner(runner_data.name).close(runner_data.opts)
end

---@param executor_data executor_conf
function utils.stop_executor(executor_data)
  utils.get_executor(executor_data.name).stop(executor_data.opts)
end

---@param runner_data runner_conf
function utils.stop_runner(runner_data)
  utils.get_runner(runner_data.name).stop(runner_data.opts)
end

--- Check if exists active job.
---@param runner_data executor_conf the runner
---@param executor_data executor_conf the executor
-- @return true if exists else false
function utils.has_active_job(runner_data, executor_data)
  return utils.get_executor(executor_data.name).has_active_job(executor_data.opts)
    or utils.get_runner(runner_data.name).has_active_job(runner_data.opts)
end

local notify_update_line = function(out, err)
  if not notification.notification.enabled then
    return
  end
  local line = err and err or out
  if line ~= nil then
    if line and vim.fn.match(line, "^%[%s*(%d+)%s*%%%]") then -- only show lines containing build progress e.g [ 12%]
      notification.notification.id = notification.notify( -- notify with percentage and message
        line,
        err and "warn" or notification.notification.level,
        { replace = notification.notification.id, title = "CMakeTools" }
      )
    end
  end
end

---Run a command using specified executor, this is used by generate, build, clean, install, etc.
---@param cmd string the executable to execute
---@param env_script string environment setup script
---@param env table environment variables
---@param args table arguments to the executable
---@param cwd string the directory to run in
---@param runner runner_conf the executor or runner
---@param on_success nil|function extra arguments, f.e on_success is a callback to be called when the process finishes
---@return nil
function utils.run(cmd, env_script, env, args, cwd, runner, on_success, cmake_notifications)
  -- save all
  vim.cmd("silent exec " .. '"wall"')

  notification.notification = cmake_notifications
  notification.notification.enabled = cmake_notifications.runner.enabled

  if notification.notification.enabled then
    notification.notification.spinner_idx = 1
    notification.notification.level = "info"

    notification.notification.id =
      notification.notify(cmd, notification.notification.level, { title = "CMakeTools" })
    notification.update_spinner()
  end

  local _mes =
    { "[RUN]:", cmd, table.concat(args, " "), "<ENV>", table.concat(env, " "), "{CWD}", cwd }
  scratch.append(table.concat(_mes, " "))

  utils.get_runner(runner.name).run(cmd, env_script, env, args, cwd, runner.opts, function(code)
    local msg = "Exited with code " .. code
    local level = cmake_notifications.level
    local icon = ""
    if code ~= 0 then
      level = "error"
      icon = ""
    end
    notification.notify(
      msg,
      level,
      { icon = icon, replace = notification.notification.id, timeout = 3000 }
    )
    notification.notification = {} -- reset and stop update_spinner
    if code == 0 and on_success then
      on_success()
    end
  end, notify_update_line)
end

---Run a command using specified executor, this is used by generate, build, clean, install, etc.
---@param cmd string the executable to execute
---@param env_script string environment setup script
---@param env table environment variables
---@param args table arguments to the executable
---@param cwd string the directory to run in
---@param executor executor_conf the executor or runner
---@param on_success nil|function extra arguments, f.e on_success is a callback to be called when the process exits with a 0 exit code
---@return nil
function utils.execute(cmd, env_script, env, args, cwd, executor, on_success, cmake_notifications)
  -- save all
  vim.cmd("silent exec " .. '"wall"')

  notification.notification = cmake_notifications
  notification.notification.enabled = cmake_notifications.executor.enabled

  if notification.notification.enabled then
    notification.notification.spinner_idx = 1
    notification.notification.level = "info"

    notification.notification.id =
      notification.notify(cmd, notification.notification.level, { title = "CMakeTools" })
    notification.update_spinner()
  end

  local _mes =
    { "[EXECUTE]:", cmd, table.concat(args, " "), "<ENV>", table.concat(env, " "), "{CWD}", cwd }
  scratch.append(table.concat(_mes, " "))

  utils
    .get_executor(executor.name)
    .run(cmd, env_script, env, args, cwd, executor.opts, function(code)
      local msg = "Exited with code " .. code
      local level = cmake_notifications.level
      local icon = ""
      if code ~= 0 then
        level = "error"
        icon = ""
      end
      notification.notify(
        msg,
        level,
        { icon = icon, replace = notification.notification.id, timeout = 3000 }
      )
      notification.notification = {} -- reset and stop update_spinner
      if code == 0 and type(on_success) == "function" then
        on_success()
      end
    end, notify_update_line)
end

return utils
