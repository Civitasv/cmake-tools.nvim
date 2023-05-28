local Job = require("plenary.job")
local Path = require("plenary.path")
local Result = require("cmake-tools.result")
local Types = require("cmake-tools.types")
local const = require("cmake-tools.const")

local utils = {
  job = nil,
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

  if opts.cmake_use_terminals then
    print('testing from exectue()')
    vim.print(opts.cmake_terminal_opts)
    local _, buffer_idx = utils.create_terminal_if_not_created(opts.cmake_terminal_opts.main_terminal_name, opts.cmake_terminal_opts)
    utils.send_data_to_terminal(buffer_idx, executable)
    -- vim.api.nvim_chan_send(vim.api.nvim_buf_get_var(buffer_idx,"terminal_job_id"), "Start-Process -FilePath pwsh -ArgumentList '-Command Start-Sleep -Seconds 5 && ls && echo \"done!\" ' -PassThru -NoNewWindow | Wait-Process \r")
    if utils.check_if_term_is_running_child_procs(buffer_idx) then
      notify('CMake task is running in terminal', vim.log.levels.ERROR)
      return
    end
    utils.send_data_to_terminal(buffer_idx, executable)
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

  if opts.cmake_use_terminals then
    print('testing from run()')
    vim.print(opts.cmake_terminal_opts)
    local _, buffer_idx = utils.create_terminal_if_not_created(opts.cmake_terminal_opts.main_terminal_name, opts.cmake_terminal_opts)
    if utils.check_if_term_is_running_child_procs(buffer_idx) then
      notify('CMake task is running in terminal', vim.log.levels.ERROR)
      return
    end
    utils.send_data_to_terminal(buffer_idx, cmd)
    -- vim.api.nvim_chan_send(vim.api.nvim_buf_get_var(buffer_idx,"terminal_job_id"), "Start-Process -FilePath pwsh -ArgumentList '-Command Start-Sleep -Seconds 5 && ls && echo \"done!\" ' -PassThru -NoNewWindow | Wait-Process \r")
  else
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

function utils.check_if_term_is_running_child_procs(terminal_buffer_idx)
  local main_pid = vim.api.nvim_buf_get_var(terminal_buffer_idx, "terminal_job_pid")
  local child_procs = vim.api.nvim_get_proc_children(main_pid)
  if next(child_procs) then
    print('child procs:')
    vim.print(child_procs)
    return true
  else
    return false
  end

  vim.print(vim.api.nvim_get_proc_children(vim.api.nvim_buf_get_var(vim.api.nvim_win_get_buf(vim.api.nvim_get_current_buf()),"terminal_job_pid")))
end

function utils.send_data_to_terminal(buffer_idx, cmd)
  print('buffer_idx: ' .. buffer_idx .. ', cmd: ' ..cmd)
  local chan = vim.api.nvim_buf_get_var(buffer_idx,"terminal_job_id")
  vim.api.nvim_chan_send(chan, "Start-Process -FilePath pwsh -ArgumentList '-Command Start-Sleep -Seconds 5 && ls && echo \"done!\" ' -PassThru -NoNewWindow | Wait-Process \r")
end

function utils.create_terminal_if_not_created(term_name, opts)
  local term_idx = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    -- local name = vim.api.nvim_buf_get_name(bufnr)
    local name =  vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t')
    if string.match(term_name, name) == term_name then
      term_idx = bufnr
      -- print('term_name: ' .. term_name .. ", term_idx: " .. term_idx)
    else
      -- print('name: ' .. name .. "bufnr: " .. bufnr)
    end
  end

  if term_idx ~= nil then
    return true, term_idx
  else
    term_idx = utils.start_local_shell(opts)
    return false, term_idx
  end
end

function utils.get_buffer_number_from_name(buffer_name)
  local buffers = vim.api.nvim_list_bufs()
  for _, buffer in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(buffer)
    if string.match(name, buffer_name) == buffer_name then
      return buffer
    end
  end
  return nil -- Buffer with the given name not found
end

function utils.delete_buffers_except(buffer_name, buffer_list)
  for _, buffer in ipairs(buffer_list) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t')
    -- print('name....................' .. name)
    if name == buffer_name then
      -- print('name: ' .. name .. ', bufnr: ' .. buffer)
    else
      vim.cmd(':bw! ' .. buffer)
    end
  end
end

function utils.symmetric_difference(list1, list2)
  local unique_numbers = {}

  local list1_set = {}
  local list2_set = {}

  -- Create a set from list1
  for _, number in ipairs(list1) do
    list1_set[number] = true
  end

  -- Create a set from list2 and add numbers to unique_numbers if not in list1
  for _, number in ipairs(list2) do
    if not list1_set[number] then
      table.insert(unique_numbers, number)
    end
    list2_set[number] = true
  end

  -- Add numbers from list1 that are not in list2 to unique_numbers
  for _, number in ipairs(list1) do
    if not list2_set[number] then
      table.insert(unique_numbers, number)
    end
  end
  return unique_numbers
end

function utils.delete_scratch_buffers()
  local buffers = vim.api.nvim_list_bufs()
  for _, buffer in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(buffer)
    if string.match(name, '^scratch_') then
      vim.api.nvim_buf_delete(buffer, { force = true })
    end
  end
end

function utils.start_local_shell(opts)
  local buffers_before = vim.api.nvim_list_bufs()

  -- Now create the plit
  vim.cmd(':' .. opts.split_direction .. ' ' .. opts.split_size .. 'sp | :term') -- Creater terminal in a split
  local new_name = vim.fn.fnamemodify(opts.main_terminal_name, ":t")             -- Extract only the terminal name and reassign it
  vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), new_name) -- Set the buffer name
  vim.cmd(':setlocal laststatus=3')                                   -- Let there be a single status/lualine in the neovim instance

  -- Renamming a terminal buffer creates a new hidden buffer, so duplicate terminals need to be deleted
  local new_buffers_list = vim.api.nvim_list_bufs()
  -- print('new_buffers_list:')
  -- vim.print(new_buffers_list)
  local diff_buffers_list = utils.symmetric_difference(buffers_before, new_buffers_list)
  -- print('diff_buffers_list:')
  -- vim.print(diff_buffers_list)
  utils.delete_buffers_except(opts.main_terminal_name, diff_buffers_list)
  utils.delete_scratch_buffers()

  local new_buffer_idx = utils.get_buffer_number_from_name(opts.main_terminal_name)
  return new_buffer_idx
end

--- Check if exists active job.
-- @return true if not exists else false
function utils.has_active_job()
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
