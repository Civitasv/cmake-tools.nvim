local Path = require("plenary.path")
local osys = require("cmake-tools.osys")
local Result = require("cmake-tools.result")
local Types = require("cmake-tools.types")
local terminal = require("cmake-tools.executors.terminal")
local notification = require("cmake-tools.notification")

-- local const = require("cmake-tools.const")
---@alias executor_conf {name:string, opts:table}

local utils = {}

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

--- Get the appropriate executor by name
---@param name string
---@return executor
function utils.get_executor(name)
  return require("cmake-tools.executors")[name]
end

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

---@param executor_data executor_conf
function utils.show_cmake_window(executor_data)
  utils.get_executor(executor_data.name).show(executor_data.opts)
end

---@param executor_data executor_conf
function utils.close_cmake_window(executor_data)
  utils.get_executor(executor_data.name).close(executor_data.opts)
end

function utils.get_path(str, sep)
  sep = sep or (osys.iswin32 and "\\" or "/")
  return str:match("(.*" .. sep .. ")")
end

--- Execute CMake launch target in terminal.
---@param executable string executable file
---@param full_cmd string full command line
---@param terminal_data executor_conf execute options
---@param executor_data executor_conf execute options
function utils.execute(executable, full_cmd, terminal_data, executor_data)
  -- Please save all
  vim.cmd("silent exec " .. '"wall"')

  -- First, if we use quickfix to generate, build, etc, we should close it
  if executor_data.name ~= "terminal" then
    utils.close_cmake_window(executor_data)
  end

  -- Then, execute it
  terminal.execute(executable, full_cmd, terminal_data.opts)
end

function utils.softlink(src, target, use_terminal, cwd, opts)
  if use_terminal and not utils.file_exists(target) then
    local cmd = "cmake -E create_symlink " .. src .. " " .. target
    terminal.run(cmd, "", {}, {}, cwd, opts)
    return
  end

  if utils.file_exists(src) and not utils.file_exists(target) then
    -- if we don't always use terminal
    local cmd = "silent exec " .. '"!cmake -E create_symlink ' .. src .. " " .. target .. '"'
    vim.cmd(cmd)
  end
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

local notify_update_line = function(out, err)
  local line = err and err or out
  if line ~= nil then
    if line and line:match("^%[%s*(%d+)%s*%%%]") then     -- only show lines containing build progress e.g [ 12%]
      notification.notification.id = notification.notify( -- notify with percentage and message
        line,
        err and "warn" or notification.notification.level,
        { replace = notification.notification.id, title = "CMakeTools" }
      )
    end
  end
end

---Run a commond
---@param cmd string the executable to execute
---@param env_script string environment setup script
---@param env table environment variables
---@param args table arguments to the executable
---@param cwd string the directory to run in
---@param executor_data executor_conf the executor
---@param on_success nil|function extra arguments, f.e on_success is a callback to be called when the process finishes
---@return nil
function utils.run(cmd, env_script, env, args, cwd, executor_data, on_success, cmake_notifications)
  -- save all
  vim.cmd("wall")

  notification.notification = cmake_notifications

  if notification.notification.enabled then
    notification.notification.spinner_idx = 1
    notification.notification.level = "info"

    notification.notification.id =
        notification.notify(cmd, notification.notification.level, { title = "CMakeTools" })
    notification.update_spinner()
  end

  utils.get_executor(executor_data.name).run(cmd, env_script, env, args, cwd, executor_data.opts, function(code)
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

--- Check if exists active job.
---@param terminal_data executor_conf the executor
---@param executor_data executor_conf the executor
-- @return true if exists else false
function utils.has_active_job(terminal_data, executor_data)
  return utils.get_executor(executor_data.name).has_active_job(executor_data.opts)
      or utils.get_executor(terminal_data.name).has_active_job(terminal_data.opts)
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

---@param executor_data executor_conf the executor
function utils.stop(executor_data)
  utils.get_executor(executor_data.name).stop(executor_data.opts)
end

return utils
