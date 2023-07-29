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
-- @param full_cmd full command line
-- @param opts execute options
function utils.execute(executable, full_cmd, opts)
  -- Please save all
  vim.cmd("silent exec " .. '"wall"')

  -- First, if we use quickfix to generate, build, etc, we should close it
  if not opts.cmake_always_use_terminal then
    quickfix.close()
  end

  -- Then, execute it
  terminal.execute(executable, full_cmd, opts)
end

function utils.softlink(src, target, opts)
  if opts.cmake_always_use_terminal and not utils.file_exists(target) then
    local cmd = "cmake -E create_symlink " .. src .. " " .. target
    terminal.run(cmd, opts)
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

-- Execute CMake command using job api
function utils.run(cmd, env, args, opts)
  -- save all
  vim.cmd("wall")

  if opts.cmake_always_use_terminal then
    return terminal.run(cmd, opts)
  else
    return quickfix.run(cmd, env, args, opts)
  end
end

--- Check if exists active job.
-- @return true if exists else false
function utils.has_active_job(always_use_terminal)
  if always_use_terminal then
    return terminal.has_active_job()
  else
    return terminal.has_active_job() or quickfix.has_active_job()
  end
end

function utils.mkdir(dir)
  local _dir = Path:new(dir)
  _dir:mkdir({ parents = true, exists_ok = true })
end

function utils.rmdir(dir)
  local _dir = Path:new(vim.loop.cwd(), dir)
  if _dir:exists() then
    _dir:rm({ recursive = true })
  end
end

function utils.file_exists(path)
  local file = Path:new(path)
  if not file:exists() then
    return false
  end
  return true
end

function utils.stop(opts)
  if opts.cmake_always_use_terminal then
    terminal.stop()
  else
    quickfix.stop()
  end
end

return utils
