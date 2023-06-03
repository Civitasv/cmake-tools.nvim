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
  vim.cmd(":setlocal laststatus=3")                                    -- Let there be a single status/lualine in the neovim instance

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
    -- print("child procs:")
    -- print(child_procs)
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
  elseif osys.islinux then
    -- Process wrapper for Linux
    if opts.wrap then
      cmd = cmd .. " & \n"
    else
      cmd = cmd .. " \n"
    end
  elseif osys.iswsl then
    --NOTE: Techinically, wsl-2 and linux are detected as linux. We might see a diferrence in wsl-1 vs wsl-2
    -- Process wrapper for Linux
    if opts.wrap then
      cmd = cmd .. " & \n"
    else
      cmd = cmd .. " \n"
    end
  end
  if opts and opts.load_buf_in_win ~= -1 then
    -- The window is alive, so we set buffer in window
    vim.api.nvim_win_set_buf(opts.load_buf_in_win, buffer_idx)
    if opts.split_direction == "horizontal" then
      vim.api.nvim_win_set_height(opts.load_buf_in_win, opts.split_size)
    else
      vim.api.nvim_win_set_width(opts.load_buf_in_win, opts.split_size)
    end
  elseif opts and opts.load_buf_in_win >= -1 then
    -- The window is not active, we need to create a nre buffer
    vim.cmd(":" .. opts.split_direction .. " " .. opts.split_size .. "sp") -- Split
    vim.api.nvim_win_set_buf(0, buffer_idx)
  else
    -- log.error("Invalid window Id!")
    -- do nothing
  end
  vim.api.nvim_chan_send(chan, cmd)
  if opts.startinsert then
    vim.cmd('startinsert')
  end
end

function terminal.create_if_not_exists(term_name, opts)
  local term_idx = nil
  -- print("term_name much before........ " .. term_name)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    -- print("name before: " .. name)
    name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    -- print("name after: " .. name)
    if name == term_name then
      term_idx = bufnr
      -- print("term_name: " .. term_name .. ", term_idx: " .. term_idx)
    else
      -- print("name: " .. name .. "bufnr: " .. bufnr)
    end
    -- print(" ")
  end
  -- print("term_name: " .. term_name)
  -- print("term_idx: " .. tostring(term_idx))

  if term_idx ~= nil then
    return true, term_idx
  else
    -- print("to start_term term_name: " .. term_name)
    term_idx = terminal.start_local_shell(term_name, opts)
    return false, term_idx
  end
end

function terminal.reposition(buffer_idx, opts)
  local all_open_cmake_terminal_buffers = terminal.get_buffers_with_prefix(opts.prefix_for_all_cmake_terminals)
  -- Check all cmake terminals with buffers
  -- print("all_open_cmake_terminal_buffers: ")
  -- vim.print(all_open_cmake_terminal_buffers)

  -- Check how, where and weather the buffers are displayed in the neovim instance
  local all_buffer_display_info = {}
  for _, buffer in ipairs(all_open_cmake_terminal_buffers) do
    table.insert(all_buffer_display_info, terminal.get_buffer_display_info(buffer, {
      ignore_current_tab = false, -- Set this to true to get info of all tabs execept current tab
      get_unindexed_list = false  -- Set this to true for viewing a visually appealing nice table
    }))
  end

  -- DEBUG options
  -- print("all_buffer_display_info: ")
  -- vim.print(all_buffer_display_info) -- Use vim.print() for printing tables
  -- print('opts:')
  -- vim.print(opts)

  if opts.launch_executable_in_a_child_process or opts.launch_task_in_a_child_process then
    log.error("Reposition term is not supported for running task/executable child processes")
    return
  end

  --[[
  -- TODO: Implement single terminal buffer for all tasks,
  -- i.e. run, build, clean, generate, etc... [except debug, as debug uses nvim.dap]

  local STBE = opts.single_terminal_buffer_for_everything
  ]]

  local SingleWindowAcrossInstance = opts.display_single_terminal_window_arcoss_instance
  local SingleWindowPerTab = opts.single_terminal_window_per_tab
  local StaticWindowLocation = opts.keep_terminal_window_in_static_location

  local final_win_id = -1 -- If -1, then a new window needs to be created, otherwise, we must return an existing winid
  if SingleWindowAcrossInstance then
    -- print('display_single_terminal_across_instance!')
    if StaticWindowLocation then
      -- print('keep_terminal_in_static_location')
      terminal.close_window_from_tabs(
      --[[ignore_current_tab=]] true,
        opts)                                                                            -- Close all cmake windows in all other tabs
      local buflist = terminal.check_if_cmake_buffers_are_displayed_in_current_tab(opts) -- Get list of all buffers that are displayed in current tab
      -- vim.print(buflist)
      if next(buflist) then
        for i = 1, #buflist do -- Buffers exist in current tab, so close all except first buffer in buflist
          if i > 1 then
            vim.api.nvim_win_close(buflist[i], false)
          end
        end
        -- print('bug here....................')
        final_win_id = buflist[1]
      end
    else
      -- print('donot keep_terminal_in_static_location')
      terminal.close_window_from_tabs(
      --[[ignore_current_tab=]] true,
        opts)                                                                            -- Close all cmake windows in all tabs
      local buflist = terminal.check_if_cmake_buffers_are_displayed_in_current_tab(opts) -- Get list of all buffers that are displayed in current tab
      if next(buflist) then
        -- Buffers exist in current tab, so close all buffers in buflist
        for i = 1, #buflist do
          if i > 1 then
            vim.api.nvim_win_close(buflist[i], false)
          end
        end
      end
      final_win_id = -1
    end
  elseif SingleWindowPerTab then
    -- print('single_terminal_per_tab!')
    if StaticWindowLocation then
      -- print('keep_terminal_in_static_location')
      local buflist = terminal.check_cmake_buffers_are_displayed_in_current_tab(opts)
      if next(buflist) then
        for i = 1, #buflist do -- Buffers exist in current tab, so close all except first buffer in buflist
          if i > 1 then
            vim.api.nvim_win_close(buflist[i], false)
          end
        end
        final_win_id = buflist[1]
      else
        final_win_id = -1
      end
    else
      -- print('donot keep_terminal_in_static_location')
      local buflist = terminal.check_cmake_buffers_are_displayed_in_current_tab(opts)
      if next(buflist) then
        for i = 1, #buflist do -- Buffers exist in current tab, so close all except first buffer in buflist
          vim.api.nvim_win_close(buflist[i], false)
        end
      end
    end
  else
    -- print('mulit terminals!')
    -- Launch multiple terminals
    final_win_id = 0
    vim.notify(
      "Caution: Multiple termianls may clutter your workspace!",
      vim.log.levels.WARN,
      { title = "CMakeTools" }
    )
  end

  -- print('repositioning complete')
  return final_win_id
end

-- Matches all the tabs and wins with buffer_idx and retunrs list of winid's indexed with resprect to their tabpages
-- Set opts.get_unindexed_list = true for getting an iterable list of values that you can use to close windows with. These are returned as a for the current buffer.
-- Only set opts.get_unindexed_list to false for viewing buffer info... i.e. how they are laid out across tabs and windows
-- Set opts.ignore_current_tab to true if you want a list of windows only from other tabs.
function terminal.get_buffer_display_info(buffer_idx, opts)
  local buffer_display_info = {}

  if opts and opts.get_unindexed_list then
    buffer_display_info = {}
  else
    buffer_display_info = { buffer_idx = buffer_idx, windows = {} }
  end

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_get_buf(win) == buffer_idx then
        --
        -- This may seem a little hairy, but it has only 2 options
        --
        if opts and opts.get_unindexed_list then
          if opts.ignore_current_tab then
            if vim.api.nvim_get_current_tabpage() == tabpage then
              -- Ignore current tabpage if set: do nothing
            else
              table.insert(buffer_display_info, win)
            end
          else
            table.insert(buffer_display_info, win)
          end
        else
          if opts.ignore_current_tab then
            local tabpage_id = vim.api.nvim_tabpage_get_number(tabpage)
            if (opts.ignore_current_tab and vim.api.nvim_get_current_tabpage() == tabpage) then
              -- Ignore current tabpage if set: do nothing
            else
              table.insert(buffer_display_info.windows, { tabpage_id = tabpage_id, win = win })
            end
          else
            local tabpage_id = vim.api.nvim_tabpage_get_number(tabpage)
            if (opts.ignore_current_tab and vim.api.nvim_get_current_tabpage() == tabpage) then
              -- Ignore current tabpage if set: do nothing
            else
              table.insert(buffer_display_info.windows, { tabpage_id = tabpage_id, win = win })
            end
          end
        end
        --
        --
        --
      end
    end
  end

  return buffer_display_info
end

function terminal.close_window_from_tabs(ignore_current_tab, opts)
  local all_open_cmake_terminal_buffers = terminal.get_buffers_with_prefix(opts.prefix_for_all_cmake_terminals)
  local unindexed_window_list = {}
  for _, buffer in ipairs(all_open_cmake_terminal_buffers) do
    local windows_open_for_buffer = terminal.get_buffer_display_info(buffer,
      {
        ignore_current_tab = ignore_current_tab,
        get_unindexed_list = true
      })
    for _, win in ipairs(windows_open_for_buffer) do
      table.insert(
        unindexed_window_list,
        win
      )
      -- print('windows_open_for_buffer: ')
      -- vim.print(windows_open_for_buffer)
    end
  end
  -- vim.print(unindexed_window_list)
  for i = 1, #unindexed_window_list do
    if i > 1 then
      -- print('win new closed: ' .. i)
      vim.api.nvim_win_close(unindexed_window_list[i], false)
    end
  end
end

function terminal.check_cmake_buffers_are_displayed_in_current_tab(opts)
  local all_open_cmake_terminal_buffers = terminal.get_buffers_with_prefix(opts.prefix_for_all_cmake_terminals)

  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local current_windows = vim.api.nvim_tabpage_list_wins(current_tabpage)
  local displayed_windows = {}

  for _, win in ipairs(current_windows) do
    local win_bufnr = vim.api.nvim_win_get_buf(win)
    if vim.tbl_contains(all_open_cmake_terminal_buffers, win_bufnr) then
      table.insert(displayed_windows, win)
    end
  end
  -- print('cmake buffers in current tab')
  -- vim.print(displayed_windows)

  return displayed_windows
end

function terminal.check_if_cmake_buffers_are_displayed_in_current_tab(opts)
  local all_open_cmake_terminal_buffers = terminal.get_buffers_with_prefix(opts.prefix_for_all_cmake_terminals)
  local unindexed_window_list = {}
  for _, buffer in ipairs(all_open_cmake_terminal_buffers) do
    local windows_open_for_buffer = terminal.get_buffer_display_info(buffer,
      {
        ignore_current_tab = false,
        get_unindexed_list = true
      })
    for _, win in ipairs(windows_open_for_buffer) do
      table.insert(
        unindexed_window_list,
        win
      )
      -- print('windows_open_for_buffer: ')
      -- vim.print(windows_open_for_buffer)
    end
  end
  -- print('unindexed window list:')
  -- vim.print(unindexed_window_list)
  -- Now, we return the list of buffers
  return unindexed_window_list
end

function terminal.get_windows_in_other_tabs(buflist, opts)
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local windows = {}

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if not opts.ignore_current_tab or tabpage ~= current_tabpage then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        local bufnr = vim.api.nvim_win_get_buf(win)
        if vim.tbl_contains(buflist, bufnr) then
          table.insert(windows, win)
        end
      end
    end
  end

  return windows
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

  -- Check if executable target is built first, as sometimes it is cleaned and user tries to run
  if executable == nil then
    log.error("You must build the executable first!... Use \":CMakeBuild\"")
    return
  end

  -- Get pure executable name
  executable = vim.fn.fnamemodify(executable, ":t")

  -- Buffer name of executable needs to be set with a prefix so that the reposition_term() function can find it
  local executable_buffer_name = prefix .. vim.fn.fnamemodify(executable, ":t")
  local _, buffer_idx = terminal.create_if_not_exists(executable_buffer_name,
    opts.cmake_terminal_opts)

  if terminal.check_if_running_child_procs(buffer_idx) then
    log.error("CMake task is running in terminal")
    return
  end

  -- Reposition the terminal buffer, before sending commands
  local final_winid = terminal.reposition(buffer_idx, opts.cmake_terminal_opts)
  -- print("final_winid: " .. final_winid)

  -- Prepare Launch path if sending to terminal
  local launch_path = terminal.prepare_launch_path(opts.cmake_launch_path,
    opts.cmake_terminal_opts.launch_executable_in_a_child_process)

  -- Launch form executable's build directory by default
  -- if opts.cmake_terminal_opts.launch_executable_from_build_directory == true then -- TODO: decide whether this option is needed
  if osys.iswin32 then
    -- Weird windows thing: executables that are not in path only work as ".\executable" and not "executable" on the cmdline (even if focus is in the same directory)
    executable = "cd " .. launch_path .. " && .\\" .. executable
  elseif osys.islinux then
    executable = "cd " .. launch_path .. " && ./" .. executable
  end
  -- end

  -- Send final cmd to terminal
  terminal.send_data_to_terminal(buffer_idx, executable,
    {
      wrap = opts.cmake_terminal_opts.launch_executable_in_a_child_process,
      load_buf_in_win = final_winid,
      split_direction = opts.cmake_terminal_opts.split_direction,
      split_size = opts.cmake_terminal_opts.split_size,
      startinsert = opts.cmake_terminal_opts.startinsert_in_launch_task
    })
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

  -- print("prefix from within run(): " .. opts.cmake_terminal_opts.prefix_for_all_cmake_terminals)
  -- Reposition the terminal buffer, before sending commands
  local final_winid = terminal.reposition(buffer_idx, opts.cmake_terminal_opts)
  -- print("final_winid: " .. final_winid)

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
  terminal.send_data_to_terminal(buffer_idx, cmd,
    {
      wrap = opts.cmake_terminal_opts.launch_task_in_a_child_process,
      load_buf_in_win = final_winid,
      split_direction = opts.cmake_terminal_opts.split_direction,
      split_size = opts.cmake_terminal_opts.split_size,
      startinsert = opts.cmake_terminal_opts.startinsert_in_other_tasks
    })

  --[[ while os.check_if_term_is_running_child_procs(buffer_idx) do ]]
  --[[   print("I'm waiting") ]]
  --[[ end ]]
end

function terminal.prepare_launch_path(path, in_a_child_process)
  if osys.iswin32 then
    if in_a_child_process then
      path = "\\\"" .. path .. "\\\""
    else
      path = "\"" .. path .. "\"" -- The path is kept in double quotes ... Windows Duh!
    end
  elseif osys.islinux then
    if in_a_child_process then
      path = path
    end
  end

  return path
end

return terminal
