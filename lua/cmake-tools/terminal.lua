local osys = require("cmake-tools.osys")
local log = require("cmake-tools.log")

local terminal = {}

-- Make a new terminal named term_name
function terminal.start_local_shell(term_name, opts)
  local buffers_before = vim.api.nvim_list_bufs()

  -- Now create the plit
  vim.cmd(":" .. opts.split_direction .. " " .. opts.split_size .. "sp | :term") -- Creater terminal in a split
  -- local new_name = vim.fn.fnamemodify(term_name, ":t")                           -- Extract only the terminal name and reassign it
  -- print('newname in start local: '.. new_name)
  -- print('term_name in start local: '.. term_name)
  vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), term_name) -- Set the buffer name
  vim.cmd(":setlocal laststatus=3") -- Let there be a single status/lualine in the neovim instance

  -- Renamming a terminal buffer creates a new hidden buffer, so duplicate terminals need to be deleted
  local new_buffers_list = vim.api.nvim_list_bufs()
  -- print('new_buffers_list:')
  -- vim.print(new_buffers_list)
  local diff_buffers_list = terminal.symmetric_difference(buffers_before, new_buffers_list)
  -- print('diff_buffers_list:')
  -- vim.print(diff_buffers_list)
  terminal.delete_duplicate_terminal_buffers_except(term_name, diff_buffers_list)
  terminal.delete_scratch_buffers()

  local new_buffer_idx = terminal.get_buffer_number_from_name(term_name)
  return new_buffer_idx
end

function terminal.symmetric_difference(list1, list2)
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

function terminal.delete_duplicate_terminal_buffers_except(buffer_name, buffer_list)
  for _, buffer in ipairs(buffer_list) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ":t")
    -- print('name....................' .. name)
    -- if string.match(name, buffer_name) == name then
    if name == buffer_name then
      -- print('DONOT Delete: name in delete duplicate: ' .. name .. ', bufnr: ' .. buffer)
    else
      vim.cmd(":bw! " .. buffer)
    end
  end
end

function terminal.delete_scratch_buffers()
  local buffers = vim.api.nvim_list_bufs()
  for _, buffer in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(buffer)
    if string.match(name, "^scratch_") then
      vim.api.nvim_buf_delete(buffer, { force = true })
    end
  end
end

function terminal.get_buffer_number_from_name(buffer_name)
  local buffers = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    -- print('get_buffer_number_from_name: ' .. name .. ", required name: " .. buffer_name)
    if name == buffer_name then
      -- print(' HIT! get_buffer_number_from_name: ' .. name .. ", required name: " .. buffer_name)
      return bufnr
    end
  end
  return nil -- Buffer with the given name not found
end

function terminal.check_if_running_child_procs(terminal_buffer_idx)
  local main_pid = vim.api.nvim_buf_get_var(terminal_buffer_idx, "terminal_job_pid")
  local child_procs = vim.api.nvim_get_proc_children(main_pid)
  if next(child_procs) then
    print("child procs:")
    print(child_procs)
    return true
  else
    return false
  end
end

function terminal.send_data_to_terminal(buffer_idx, cmd, opts)
  -- print('buffer_idx: ' .. buffer_idx .. ', cmd: ' .. cmd)
  local chan = vim.api.nvim_buf_get_var(buffer_idx, "terminal_job_id")
  if osys.iswin32 then
    -- print('win32')
    if opts.wrap then
      cmd = "Start-Process -FilePath pwsh -ArgumentList '-Command " ..
          cmd .. " ' -PassThru -NoNewWindow | Wait-Process \r"
    else
      cmd = cmd .. " \r"
    end
  elseif osys.ismac then
    -- TODO: Process wrapper for mac
  elseif osys.iswsl then
    -- TODO: Process wrapper for wsl
  elseif osys.islinux then
    -- Process wrapper for Linux
    if opts.wrap then
      cmd = cmd .. " \n"
    else
      cmd = cmd .. " \n"
    end
  end
  vim.api.nvim_chan_send(chan, cmd)
end

function terminal.create_if_not_exists(term_name, opts)
  local term_idx = nil
  print("term_name much before........ " .. term_name)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    print("name before: " .. name)
    name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    print("name after: " .. name)
    if name == term_name then
      term_idx = bufnr
      print("term_name: " .. term_name .. ", term_idx: " .. term_idx)
    else
      print("name: " .. name .. "bufnr: " .. bufnr)
    end
    print(" ")
  end
  print("term_name: " .. term_name)
  print("term_idx: " .. tostring(term_idx))

  if term_idx ~= nil then
    return true, term_idx
  else
    print("to start_term term_name: " .. term_name)
    term_idx = terminal.start_local_shell(term_name, opts)
    return false, term_idx
  end
end

function terminal.reposition(buffer_idx, opts)
  -- TODO: Reposition Windows
  -- This takes care of all window handling with a single buffer idx and opts.cmake_terminal_opts which are passed in as opts

  -- print('Reposition! ... window: ' .. buffer_idx .. opts)

  -- First get all buffers across all tabs, with the custom prefix
  print("prefix from within reposition_term(): " .. opts.prefix_for_all_cmake_terminals)
  local all_open_cmake_terminal_buffers = terminal.get_buffers_with_prefix(opts.prefix_for_all_cmake_terminals)

  -- Check how, where and weather the buffers are displayed in the neovim instance
  local all_buffer_display_info = {}
  for _, buffer in ipairs(all_open_cmake_terminal_buffers) do
    table.insert(all_buffer_display_info, terminal.get_buffer_display_info(buffer))
  end
  print("all_buffer_display_info: ")
  vim.print(all_buffer_display_info) -- Use vim.print() for printing tables
end

function terminal.get_buffer_display_info(buffer_idx)
  local buffer_display_info = { buffer_idx = buffer_idx, tabpages = {} }

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    local tabpage_id = vim.api.nvim_tabpage_get_number(tabpage)
    buffer_display_info.tabpages[tabpage_id] = {}

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_get_buf(win) == buffer_idx then
        table.insert(buffer_display_info.tabpages[tabpage_id], win)
      end
    end
  end

  return buffer_display_info
end

function terminal.get_buffers_with_prefix(prefix)
  local buffers = vim.api.nvim_list_bufs()
  local filtered_buffers = {}

  for _, buffer in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(buffer)
    local basename = vim.fn.fnamemodify(name, ":t")
    if basename:sub(1, #prefix) == prefix then
      table.insert(filtered_buffers, buffer)
    end
  end

  return filtered_buffers
end

function terminal.execute(executable, opts)
  local prefix = opts.cmake_terminal_opts.prefix_for_all_cmake_terminals
  -- print('testing from exectue()')
  -- vim.print(opts.cmake_terminal_opts)
  -- print('opts.cmake_launch_path: ')
  -- vim.print(opts.cmake_launch_path)
  -- print('executable ')
  -- vim.print(executable)

  -- Check if executable target is built first, as sometimes it is cleaned and user tries to run
  if executable == nil then
    log.error("You must build the executable first!... Use \":CMakeBuild\"")
    return
  end

  -- Get pure executable name
  executable = vim.fn.fnamemodify(executable, ":t")
  --[[ print("Executable", executable) ]]

  -- Buffer name of executable needs to be set with a prefix so that the reposition_term() function can find it
  local executable_buffer_name = prefix .. vim.fn.fnamemodify(executable, ":t")
  local _, buffer_idx = terminal.create_if_not_exists(executable_buffer_name,
    opts.cmake_terminal_opts)

  --[[ print("bufferidx: " .. buffer_idx) ]]

  if terminal.check_if_running_child_procs(buffer_idx) then
    log.error("CMake task is running in terminal")
    return
  end

  -- Reposition the terminal buffer, before sending commands
  terminal.reposition(buffer_idx, opts.cmake_terminal_opts)

  -- Prepare Launch path if sending to terminal
  local launch_path = terminal.prepare_launch_path(opts.cmake_launch_path,
    opts.cmake_terminal_opts.launch_task_in_a_child_process)

  -- Launch form executable's build directory by default
  -- if opts.cmake_terminal_opts.launch_executable_from_build_directory == true then
  if osys.iswin32 then
    -- Weird windows thing: executables that are not in path only work as ".\executable" and not "executable" on the cmdline (even if focus is in the same directory)
    executable = "cd " .. launch_path .. " && .\\" .. executable
  elseif osys.islinux then
    executable = "cd " .. launch_path .. " && ./" .. executable
  end
  -- end

  -- Send final cmd to terminal
  terminal.send_data_to_terminal(buffer_idx, executable,
    { wrap = opts.cmake_terminal_opts.launch_executable_in_a_child_process })
end

function terminal.run(cmd, env, args, opts)
  local prefix = opts.cmake_terminal_opts.prefix_for_all_cmake_terminals -- [CMakeTools]
  -- print('testing from run()')
  -- vim.print(opts.cmake_terminal_opts)

  -- prefix is added to the terminal name because the reposition_term() function needs to find it
  local _, buffer_idx = terminal.create_if_not_exists(
    prefix .. opts.cmake_terminal_opts.main_terminal_name, -- [CMakeTools]Main Terminal
    opts.cmake_terminal_opts
  )

  --[[ if os.check_if_term_is_running_child_procs(buffer_idx) then ]]
  --[[   notify("CMake task is running in terminal", vim.log.levels.ERROR) ]]
  --[[   return ]]
  --[[ end ]]

  print("prefix from within run(): " .. opts.cmake_terminal_opts.prefix_for_all_cmake_terminals)
  -- Reposition the terminal buffer, before sending commands
  terminal.reposition(buffer_idx, opts.cmake_terminal_opts)

  -- Prepare Launch path form
  local launch_path = terminal.prepare_launch_path(opts.cmake_launch_path,
    opts.cmake_terminal_opts.launch_task_in_a_child_process)

  -- Launch form executable's build directory by default
  -- if opts.cmake_terminal_opts.launch_executable_from_build_directory then
  cmd = "cd " .. launch_path .. " && " .. cmd
  -- end

  -- Add args to the cmd
  for _, arg in ipairs(args) do
    cmd = cmd .. " " .. arg
  end

  -- Send final cmd to terminal
  terminal.send_data_to_terminal(buffer_idx, cmd, { wrap = opts.cmake_terminal_opts.launch_task_in_a_child_process })

  --[[ while os.check_if_term_is_running_child_procs(buffer_idx) do ]]
  --[[   print("I'm waiting") ]]
  --[[ end ]]
end

function terminal.prepare_launch_path(path, in_a_child_process)
  if osys.iswin32 then
    if in_a_child_process then
      path = "\\\"" .. path .. "\\\""
    end
  elseif osys.islinux then
    if in_a_child_process then
      path = path
    end
  end

  return path
end

return terminal
