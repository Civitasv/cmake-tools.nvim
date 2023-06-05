local Path = require("plenary.path")
local Result = require("cmake-tools.result")
local Types = require("cmake-tools.types")
local terminal = require("cmake-tools.terminal")
local quickfix = require("cmake-tools.quickfix")

-- local const = require("cmake-tools.const")

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

function utils.get_cmake_configuration()
  local cmakelists = Path:new(vim.loop.cwd(), "CMakeLists.txt")
  if not cmakelists:is_file() then
    return Result:new(
      Types.CANNOT_FIND_CMAKE_CONFIGURATION_FILE,
      nil,
      "Cannot find CMakeLists.txt at cwd."
    )
  end
  return Result:new(Types.SUCCESS, cmakelists, "cmake-tools has found CMakeLists.txt.")
end

function utils.show_cmake_window(always_use_terminal, quickfix_opts, terminal_opts)
  if always_use_terminal then
    terminal.show(terminal_opts)
  else
    quickfix.show(quickfix_opts)
  end
end

function utils.close_cmake_window(always_use_terminal)
  if always_use_terminal then
    terminal.close()
  else
    quickfix.close()
  end
end

function utils.get_path(str, sep)
  sep = sep or "/"
  return str:match("(.*" .. sep .. ")")
end

--- Execute CMake launch target in terminal.
-- @param executable executable file
-- @param opts execute options
function utils.execute(executable, opts)
  -- Please save all
  vim.cmd("wall")

  -- First, if we use quickfix to generate, build, etc, we should close it
  if not opts.cmake_always_use_terminal then
    quickfix.close()
  end

  -- Then, execute it
  terminal.execute(executable, opts)
end

function utils.softlink(src, target)
  local dir_src = Path:new(src)
  local dir_target = Path:new(target)
  if dir_src:exists() and not dir_target:exists() then
    local cmd = "silent exec " .. "\"!cmake -E create_symlink " .. src .. " " .. target .. "\""
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

-- Execute CMake command using job api
function utils.run(cmd, env, args, opts)
  -- save all
  vim.cmd("wall")

  if opts.cmake_always_use_terminal then
    -- First, close the console
    utils.close_cmake_window()
    terminal.run(cmd, env, args, opts)
    vim.schedule_wrap(opts.on_success())
  else
    return quickfix.run(cmd, env, args, opts)
  end
end

--- Check if exists active job.
-- @return true if not exists else false
function utils.has_active_job(always_use_terminal, opts)
  if always_use_terminal and opts.launch_task_in_a_child_process then
    return terminal.has_active_job()
  elseif always_use_terminal and not opts.launch_task_in_a_child_process then
    -- Exclusively using terminal for directly laoding commands
    vim.notify("Feature is experimental! set \"cmake_always_use_terminal = false\" to avoid this mode. Currently, cannot chain commands in terminal unless the project is already configured!", vim.log.levels.WARN, { title = "CMake" })
    return true
  else
    return terminal.has_active_job() or quickfix.has_active_job()
  end
end

function utils.rmdir(dir)
  local _dir = Path:new(vim.loop.cwd(), dir)
  if _dir:exists() then
    _dir:rm({ recursive = true })
  end
end

function utils.file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

return utils
