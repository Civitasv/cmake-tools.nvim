local Job = require("plenary.job")
local Path = require("plenary.path")
local Result = require("cmake-tools.result")
local Types = require("cmake-tools.types")
local terminal = require("cmake-tools.terminal")
local osys = require("cmake-tools.osys")
local log = require("cmake-tools.log")

-- local const = require("cmake-tools.const")

local utils = {
  job = nil,
}

local function append_to_cmake_console(error, data)
  local line = error and error or data
  vim.fn.setqflist({}, "a", { lines = { line } })
  -- scroll the quickfix buffer to bottom
  vim.api.nvim_command("cbottom")
end

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

function utils.show_cmake_console(cmake_console_position, cmake_console_size)
  vim.api.nvim_command(cmake_console_position .. " copen " .. cmake_console_size)
  vim.api.nvim_command("wincmd p")
end

function utils.close_cmake_console()
  vim.api.nvim_command("cclose")
end

--- Execute CMake launch target in terminal.
-- @param executable executable file
-- @param opts execute options
function utils.execute(executable, opts)
  -- save all
  vim.cmd("wall")

  if opts.cmake_unify_terminal_for_launch then
    terminal.execute(executable, opts)
  else
    -- print("EXECUTABLE", executable)
    local set_bufname = "file " .. opts.bufname
    local prefix = string.format("%s %d new", opts.cmake_console_position, opts.cmake_console_size)

    utils.close_cmake_console();

    -- check if buufer exists. If it exists, delete it!
    local all_buffs = vim.api.nvim_list_bufs()
    -- local temp = " " -- This is only for testing
    for _, buf_nr in ipairs(all_buffs) do
      local name = vim.api.nvim_buf_get_name(buf_nr)
      local test = string.match(name, set_bufname) == set_bufname
      -- print(test)
      -- temp = temp .. name ..": " .. tostring(test) .. ", "
      if test then
        -- the buffer is already avaliable
        vim.api.nvim_buf_delete(buf_nr, { force = true })
        vim.cmd(set_bufname)
        break
      end
    end

    -- print(temp)
    local cmd = prefix .. " | term " .. "cd " .. opts.cmake_launch_path .. " && " .. executable
    if (opts.cmake_launch_args ~= nil) then
      for _, arg in ipairs(opts.cmake_launch_args) do
        cmd = cmd .. ' "' .. arg .. '"'
      end
    end

    vim.cmd(cmd)
    vim.opt_local.relativenumber = false
    vim.opt_local.number = false
    vim.bo.buflisted = false -- We set this to true, so that we can detect in in vim.api.nvim_list_bufs(), a few lines above.
    vim.cmd("startinsert")
  end
end

function utils.softlink(src, target)
  local dir_src = Path:new(src)
  local dir_target = Path:new(target)
  if dir_src:exists() and not dir_target:exists() then
    local cmd = "!cmake -E create_symlink " .. src .. " " .. target;
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

  --[[ if opts.cmake_unify_terminal_for_launch then ]]
  --[[   terminal.run(cmd, env, args, opts) ]]
  --[[ else ]]
  vim.fn.setqflist({}, " ", { title = cmd .. " " .. table.concat(args, " ") })
  opts.cmake_show_console = opts.cmake_show_console == "always"
  if opts.cmake_show_console then
    utils.show_cmake_console(opts.cmake_console_position, opts.cmake_console_size)
  end

  utils.job = Job:new({
    command = cmd,
    args = next(env) and { "-E", "env", table.concat(env, " "), "cmake", unpack(args) } or args,
    cwd = vim.loop.cwd(),
    on_stdout = vim.schedule_wrap(append_to_cmake_console),
    on_stderr = vim.schedule_wrap(append_to_cmake_console),
    on_exit = vim.schedule_wrap(function(_, code, signal)
      append_to_cmake_console("Exited with code " .. (signal == 0 and code or 128 + signal))
      if code == 0 and signal == 0 then
        if opts.on_success then
          opts.on_success()
        end
      elseif opts.cmake_show_console == "only_on_error" then
        utils.show_cmake_console(opts.cmake_console_position, opts.cmake_console_size)
        vim.api.nvim_command("cbottom")
      end
    end),
  })

  utils.job:start()
  return utils.job
  --[[ end ]]
end

--- Check if exists active job.
-- @return true if not exists else false
function utils.has_active_job()
  if not utils.job or utils.job.is_shutdown then
    return true
  end
  log.error(
    "A CMake task is already running: "
    .. utils.job.command
    .. " Stop it before trying to run a new CMake task."
  )
  return false
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
