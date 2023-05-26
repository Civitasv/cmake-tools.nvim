local Job = require("plenary.job")
local Path = require("plenary.path")
local Result = require("cmake-tools.result")
local Types = require("cmake-tools.types")
local const = require("cmake-tools.const")
local os_config = require("cmake-tools.os_config")
local config = require("cmake-tools.config")

local utils = {
  job = nil,
  main_term_job = nil,
  run_term_job = {},
  debug_term_job = {},
}

local function notify(msg, log_level)
  vim.notify(msg, log_level, { title = "CMake" })
end

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

--- Error Message Alert
-- @param msg the error message
function utils.error(msg)
  notify(msg, vim.log.levels.ERROR)
end

--- Execute CMake launch target in terminal.
-- @param executable executable file
-- @param opts execute options
function utils.execute(executable, opts)
  -- save all
  vim.cmd("wall")
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
  if const.cmake_use_terminals == true then
    if opts.cmake_launch_path then
      cmd = "cd " .. opts.cmake_launch_path .. " && " .. cmd
    end
    -- TODO: vim.schedule this
    utils.start_proccess_in_terminal(opts.terminal_buffer_name, cmd .. " " .. table.concat(args, " "))

  else -- Use QuickFix Lists
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
  end
end

--- Check if exists active job.
-- @return true if not exists else false
function utils.has_active_job(terminal_buffer_name)
  if const.cmake_use_terminals == true then
    local term_already_existed, terminal_buffer_idx = utils.create_term_if_term_did_not_exist(terminal_buffer_name)
    -- if utils.terminal_has_active_job(terminal_buffer_name) then
    --   return true
    -- end
    return true
  else -- Using QuickFix Lists
    if not utils.job or utils.job.is_shutdown then
      return true
    end
    utils.error(
      "A CMake task is already running: "
      .. utils.job.command
      .. " Stop it before trying to run a new CMake task."
    )
    return false
  end
end

-- Error Checking in CMake Task: https://stackoverflow.com/questions/7402587/run-command2-only-if-command1-succeeded-in-cmd-windows-shell
---Check if main terminal has active job
function utils.terminal_has_active_job(terminal_buffer_name)
  -- Lookup the terminal buffer idx from it's name
  local terminal_buffer_idx = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == terminal_buffer_name then
      terminal_buffer_idx = bufnr
      break
    end
  end

  -- If terminal is found, then get the list of chil procs
  if terminal_buffer_idx then
    local term_proc = vim.fn.jobpid(vim.api.nvim_buf_get_var(terminal_buffer_idx, 'terminal_job_id'))
    local term_child_procs = vim.api.nvim_get_proc_children(term_proc)
    if next(term_child_procs) == nil then
      return false -- Term has no child process. New process can be spwanned
    end
    utils.error(
      "A CMake task is already running: "
      .. utils.main_term_job
      .. " Stop it before trying to run a new CMake Build/Generate/Clean/CleanRebuild/Install."
    )
    return true -- Child processes exist. Cannot launch new task
  else
    return false
  end
end

function utils.create_term_if_term_did_not_exist(terminal_buffer_name)
  -- Lookup the terminal buffer idx from it's name
  local terminal_buffer_idx
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    -- print('buffer names: ' .. name)
    if string.match(name, terminal_buffer_name) == terminal_buffer_name then
      terminal_buffer_idx = bufnr
      break
    end
  end

  if terminal_buffer_idx then
    return true, terminal_buffer_idx
  else
    os_config.start_local_shell(const.cmake_terminal_opts.terminal_split_direction)
    vim.cmd(':setlocal laststatus=3') -- Let there be a single status/lualine in the neovim instance
    terminal_buffer_idx = vim.api.nvim_get_current_buf()                                 -- Get the buffer idx
    local terminal_name = vim.fn.fnamemodify(terminal_buffer_name, ":t")                 -- Extract only the terminal name
    vim.api.nvim_buf_set_name(0, terminal_name)                                          -- Set the buffer name
    return false, terminal_buffer_idx
  end
end

function utils.get_child_procs_from_parent_terminal(terminal_buffer_name)
  -- Lookup the terminal buffer idx from it's name
  local terminal_buffer_idx = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == terminal_buffer_name then
      terminal_buffer_idx = bufnr
      break
    end
  end

  -- If terminal buffer exists, then get its child procs
  if terminal_buffer_idx then
    local term_proc = vim.fn.jobpid(vim.api.nvim_buf_get_var(terminal_buffer_idx, 'terminal_job_id'))
    -- TODO: Check if term_proc is nil and try using :h nvim_get_proc()
    return vim.api.nvim_get_proc_children(term_proc)
  else
    utils.error("CMake Console: " .. terminal_buffer_name .. " does not exist! : CMAKE INTERNAL PROC ERROR!")
    return nil
  end
end

function utils.start_proccess_in_terminal(terminal_buffer_name, cmd)
  -- Lookup the terminal buffer idx from it's name
  local terminal_buffer_idx = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if string.match(name, terminal_buffer_name) == terminal_buffer_name then
      terminal_buffer_idx = bufnr
      break
    end
  end

  -- print('terminal_buffer_name: ' .. terminal_buffer_name .. ", terminal_buffer_idx: " .. tostring(terminal_buffer_idx))

  -- If terminal is found, then get the last line in the buffer, and check for substring: 'CMake Task Finished'
  if terminal_buffer_idx ~= nil then
    local term_job_id = vim.api.nvim_buf_get_var(terminal_buffer_idx, 'terminal_job_id')
    -- vim.cmd("norm G")
    -- print('term_job_id:' .. term_job_id)
    local final_cmd = cmd .. string.char(13) -- String char 13 is the <Enter Key>
    vim.api.nvim_chan_send(term_job_id, final_cmd)

    ----------- All this is testing to check if we can somehow prevent the user from spamming multiple CMake <Taks> Commands, all at once.
    -- local final_cmd = os_config.get_process_wrapper_for(cmd)
    -- vim.cmd("call chansend(" .. term_job_id .. ', "\x1b\x5b\x41\\<cr>")')
    -- vim.cmd("call chansend(" .. term_job_id .. ",\"\\<Esc>[A\\<CR>\"))
    -- vim.cmd("call chansend(" .. term_job_id .. ', "\x1b\x5b\x41\\<cr>")')
    -- vim.cmd("call feedkeys('\\<CR>', 't')")
    -- vim.api.nvim_chan_send(term_job_id, vim.api.nvim_feedkeys("<CR>", 'n', true))
    -- vim.api.nvim_feedkeys("\\<CR>", 'i', true)
    return true -- Child processes exist. Cannot launch new task
  else
    return false
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
