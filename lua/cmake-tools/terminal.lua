local osys = require("cmake-tools.osys")
local log = require("cmake-tools.log")

---@class terminal : executor, runner
local _terminal = {
  id = nil, -- id for the unified terminal
  id_old = nil, -- Old id to keep track of the buffer
}

function _terminal.has_active_job(opts)
  if _terminal.id then
    -- first, check if this buffer is valid
    if not vim.api.nvim_buf_is_valid(_terminal.id) then
      return false
    end
    local main_pid = vim.api.nvim_buf_get_var(_terminal.id, "terminal_job_pid")
    local child_procs = vim.api.nvim_get_proc_children(main_pid)

    if next(child_procs) then
      return true
    else
      return false
    end
  end

  return false
end

function _terminal.show(opts)
  if not _terminal.id then
    log.info("There is no terminal instance")
    return
  end

  local win_id = _terminal.reposition(opts)

  if win_id ~= -1 then
    -- The window is alive, so we set buffer in window
    vim.api.nvim_win_set_buf(win_id, _terminal.id)
    if opts.split_direction == "horizontal" then
      vim.api.nvim_win_set_height(win_id, opts.split_size)
    else
      vim.api.nvim_win_set_width(win_id, opts.split_size)
    end
  elseif win_id >= -1 then
    -- The window is not active, we need to create a new buffer
    vim.cmd(":" .. opts.split_direction .. " " .. opts.split_size .. "sp") -- Split
    vim.api.nvim_win_set_buf(0, _terminal.id)
  else
    -- log.error("Invalid window Id!")
    -- do nothing
  end
end

-- Make a new terminal named term_name
function _terminal.new_instance(term_name, opts)
  local buffers_before = vim.api.nvim_list_bufs()

  -- Now create the plit
  vim.cmd(":" .. opts.split_direction .. " " .. opts.split_size .. "sp | :term") -- Creater terminal in a split
  -- local new_name = vim.fn.fnamemodify(term_name, ":t")                           -- Extract only the terminal name and reassign it
  vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), term_name) -- Set the buffer name
  vim.cmd(":setlocal laststatus=3") -- Let there be a single status/lualine in the neovim instance

  -- Renamming a terminal buffer creates a new hidden buffer, so duplicate terminals need to be deleted
  local new_buffers_list = vim.api.nvim_list_bufs()
  local diff_buffers_list = _terminal.symmetric_difference(buffers_before, new_buffers_list)
  _terminal.delete_duplicate_terminal_buffers_except(term_name, diff_buffers_list)

  -- This is mainly for users to do filtering if necessary, as termial does not have a default type.
  -- Example: using a filter in 'hardtime.nvim' to make sure
  -- we can use chained hjkl keys in sucession in the terminal to scroll.
  -- It also makes it easier to get the terminals that are unique to cmake_tools
  vim.api.nvim_buf_set_option(vim.api.nvim_get_current_buf(), "filetype", "cmake_tools_terminal")

  _terminal.delete_scratch_buffers()

  local new_buffer_idx = _terminal.get_buffer_number_from_name(term_name)
  return new_buffer_idx
end

function _terminal.symmetric_difference(list1, list2)
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

function _terminal.delete_duplicate_terminal_buffers_except(buffer_name, buffer_list)
  for _, buffer in ipairs(buffer_list) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ":t")
    -- if string.match(name, buffer_name) == name then
    if name == buffer_name then
      -- print('DONOT Delete: name in delete duplicate: ' .. name .. ', bufnr: ' .. buffer)
    else
      vim.cmd(":bw! " .. buffer)
    end
  end
end

function _terminal.delete_scratch_buffers()
  local buffers = vim.api.nvim_list_bufs()
  for _, buffer in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(buffer)
    if string.match(name, "^scratch_") then
      vim.api.nvim_buf_delete(buffer, { force = true })
    end
  end
end

function _terminal.get_buffer_number_from_name(buffer_name)
  local buffers = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(buffers) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    -- print('get_buffer_number_from_name: ' .. name .. ", required name: " .. buffer_name)
    if name == buffer_name then
      -- print(' HIT! get_buffer_number_from_name: ' .. name .. ", required name: " .. buffer_name)
      return bufnr
    end
  end
  return nil -- Buffer with the given name not found
end

function _terminal.send_data_to_terminal(buffer_idx, cmd, opts)
  if not opts or not opts.do_not_add_newline then
    if osys.iswin32 then
      cmd = cmd .. " \r"
    elseif osys.ismac then
      cmd = cmd .. " \n"
    elseif osys.islinux then
      cmd = cmd .. " \n"
    elseif osys.iswsl then
      --NOTE: Techinically, wsl-2 and linux are detected as linux. We might see a diferrence in wsl-1 vs wsl-2
      cmd = cmd .. " \n"
    end
  else
    -- Append a space but NOT the newline, so that the user has a chance to review the command before executing it
    cmd = cmd .. " "
  end

  if opts and opts.win_id ~= -1 then
    -- The window is alive, so we set buffer in window
    vim.api.nvim_win_set_buf(opts.win_id, buffer_idx)
    if opts.split_direction == "horizontal" then
      vim.api.nvim_win_set_height(opts.win_id, opts.split_size)
    else
      vim.api.nvim_win_set_width(opts.win_id, opts.split_size)
    end
  elseif opts and opts.win_id >= -1 then
    -- The window is not active, we need to create a new buffer
    vim.cmd(":" .. opts.split_direction .. " " .. opts.split_size .. "sp") -- Split
    vim.api.nvim_win_set_buf(0, buffer_idx) -- Set buffer to newly created window
  else
    -- log.error("Invalid window Id!")
    -- do nothing
  end

  -- Now, the cmake buffer's window is currently in focus

  if opts and opts.focus then
    -- We want to focus on the newly set terminal
    vim.api.nvim_set_current_win(opts.win_id)
    if opts.start_insert then
      vim.cmd("startinsert")
    end
  else
    -- We want to focus on our currently focused window and not ther cmake terminal
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(0))
    local basename = vim.fn.fnamemodify(name, ":t")
    if opts and (basename:sub(1, #opts.prefix) == opts.prefix) then -- If currently focused buffer is cmake buffer then ...
      -- Now we check again if the buffer needs to be focused as the user might be scrolling
      -- a cmake buffer and execute a :CMakeCommand, so we do not want to move their
      -- cursor out of the cmake buffer, as it can be annoying
      if opts and not opts.focus then
        vim.cmd("wincmd p") -- Goes back to previous window: Equivalent to [[ CTRL-W p ]]
      end
    end
  end

  -- Focus on the last line in the buffer to keep the scrolling output
  -- [[ We keep this option enabled by default because when users scroll the buffer and run :CMakeCommands,
  --    we must scroll the buffer even if they are focused on it
  -- ]]
  vim.api.nvim_buf_call(buffer_idx, function()
    local type = vim.api.nvim_get_option_value("buftype", {
      buf = buffer_idx,
    })
    if type == "terminal" then
      vim.cmd("execute feedkeys('G', 't')")
    end
  end)

  -- Finally send data to the terminal for execution
  local chan = vim.api.nvim_buf_get_var(buffer_idx, "terminal_job_id")
  vim.api.nvim_chan_send(chan, cmd)
end

function _terminal.create_if_not_exists(term_name, opts)
  local term_idx = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    if name == term_name then
      term_idx = bufnr
    else
    end
  end

  local terminal_already_exists = false

  if term_idx ~= nil and vim.api.nvim_buf_is_valid(term_idx) then
    local type = vim.api.nvim_get_option_value("buftype", {
      buf = term_idx,
    })
    if type == "terminal" then
      terminal_already_exists = true
    else
      vim.api.nvim_buf_delete(term_idx, { force = true })
    end
  end

  if not terminal_already_exists then
    term_idx = _terminal.new_instance(term_name, opts)
    -- does_terminal_already_exist terminal will be default (false)
  end
  return terminal_already_exists, term_idx
end

function _terminal.reposition(opts)
  local all_open_cmake_terminal_buffers = _terminal.get_buffers_with_prefix(opts.prefix_name)
  -- Check all cmake terminals with buffers

  -- Check how, where and weather the buffers are displayed in the neovim instance
  local all_buffer_display_info = {}
  for _, buffer in ipairs(all_open_cmake_terminal_buffers) do
    table.insert(
      all_buffer_display_info,
      _terminal.get_buffer_display_info(buffer, {
        ignore_current_tab = false, -- Set this to true to get info of all tabs execept current tab
        get_unindexed_list = false, -- Set this to true for viewing a visually appealing nice table
      })
    )
  end

  local single_terminal_per_instance = opts.single_terminal_per_instance
  local single_terminal_per_tab = opts.single_terminal_per_tab
  local static_window_location = opts.keep_terminal_static_location

  local final_win_id = -1 -- If -1, then a new window needs to be created, otherwise, we must return an existing winid
  if single_terminal_per_instance then
    if static_window_location then
      _terminal.close_window_from_tabs_with_prefix(true, opts) -- Close all cmake windows in all other tabs
      local buflist = _terminal.check_if_cmake_buffers_are_displayed_across_all_tabs(opts) -- Get list of all buffers that are displayed in current tab
      if next(buflist) then
        for i = 1, #buflist do -- Buffers exist in current tab, so close all except first buffer in buflist
          if i > 1 then
            vim.api.nvim_win_close(buflist[i], false)
          end
        end
        final_win_id = buflist[1]
      end
    else
      _terminal.close_window_from_tabs_with_prefix(true, opts) -- Close all cmake windows in all tabs
      local buflist = _terminal.check_if_cmake_buffers_are_displayed_across_all_tabs(opts) -- Get list of all buffers that are displayed in current tab
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
  elseif single_terminal_per_tab then
    if static_window_location then
      local buflist = _terminal.check_cmake_buffers_are_displayed_in_current_tab(opts)
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
      local buflist = _terminal.check_cmake_buffers_are_displayed_in_current_tab(opts)
      if next(buflist) then
        for i = 1, #buflist do -- Buffers exist in current tab, so close all except first buffer in buflist
          vim.api.nvim_win_close(buflist[i], false)
        end
      end
    end
  else
    -- Launch multiple terminals
    final_win_id = 0
    log.warn("Caution: Multiple termianls may clutter your workspace!")
  end

  return final_win_id
end

-- Matches all the tabs and wins with buffer_idx and retunrs list of winid's indexed with resprect to their tabpages
-- Set opts.get_unindexed_list = true for getting an iterable list of values that you can use to close windows with. These are returned as a for the current buffer.
-- Only set opts.get_unindexed_list to false for viewing buffer info... i.e. how they are laid out across tabs and windows
-- Set opts.ignore_current_tab to true if you want a list of windows only from other tabs.
function _terminal.get_buffer_display_info(buffer_idx, opts)
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
            if opts.ignore_current_tab and vim.api.nvim_get_current_tabpage() == tabpage then
              -- Ignore current tabpage if set: do nothing
            else
              table.insert(buffer_display_info.windows, { tabpage_id = tabpage_id, win = win })
            end
          else
            local tabpage_id = vim.api.nvim_tabpage_get_number(tabpage)
            if opts.ignore_current_tab and vim.api.nvim_get_current_tabpage() == tabpage then
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

-- Close all window in all tabs by prefix.
-- @param ignore_current_tab: if ignore current tab
-- @param opts: { prefix_name }
function _terminal.close_window_from_tabs_with_prefix(ignore_current_tab, opts)
  local buffers = _terminal.get_buffers_with_prefix(opts.prefix_name)
  local unindexed_window_list = {}
  for _, buffer in ipairs(buffers) do
    local windows_open_for_buffer = _terminal.get_buffer_display_info(buffer, {
      ignore_current_tab = ignore_current_tab,
      get_unindexed_list = true,
    })
    for _, win in ipairs(windows_open_for_buffer) do
      table.insert(unindexed_window_list, win)
    end
  end
  for i = 1, #unindexed_window_list do
    if i > 1 then
      vim.api.nvim_win_close(unindexed_window_list[i], false)
    end
  end
end

function _terminal.check_cmake_buffers_are_displayed_in_current_tab(opts)
  local all_open_cmake_terminal_buffers = _terminal.get_buffers_with_prefix(opts.prefix_name)

  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local current_windows = vim.api.nvim_tabpage_list_wins(current_tabpage)
  local displayed_windows = {}

  for _, win in ipairs(current_windows) do
    local win_bufnr = vim.api.nvim_win_get_buf(win)
    if vim.tbl_contains(all_open_cmake_terminal_buffers, win_bufnr) then
      table.insert(displayed_windows, win)
    end
  end

  return displayed_windows
end

function _terminal.check_if_cmake_buffers_are_displayed_across_all_tabs(opts)
  local all_open_cmake_terminal_buffers = _terminal.get_buffers_with_prefix(opts.prefix_name)
  local unindexed_window_list = {}
  for _, buffer in ipairs(all_open_cmake_terminal_buffers) do
    local windows_open_for_buffer = _terminal.get_buffer_display_info(buffer, {
      ignore_current_tab = false,
      get_unindexed_list = true,
    })
    for _, win in ipairs(windows_open_for_buffer) do
      table.insert(unindexed_window_list, win)
    end
  end
  -- Now, we return the list of buffers
  return unindexed_window_list
end

function _terminal.get_windows_in_other_tabs(buflist, opts)
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

function _terminal.get_buffers_with_prefix(prefix)
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

function _terminal.prepare_cmd_for_run(executable, args, launch_path, wrap_call, env)
  local full_cmd = ""
  -- executable = vim.fn.fnamemodify(executable, ":t")

  -- Launch form executable's build directory by default
  full_cmd = 'cd "' .. launch_path .. '" &&'

  if osys.iswin32 then
    for _, v in ipairs(env) do
      full_cmd = full_cmd .. " set " .. v .. " &&"
    end
  else
    full_cmd = full_cmd .. " " .. table.concat(env, " ")
  end

  -- prepend wrap_call args
  if wrap_call then
    for _, arg in ipairs(wrap_call) do
      full_cmd = full_cmd .. " " .. arg
    end
  end

  full_cmd = full_cmd .. " "

  if osys.islinux or osys.iswsl or osys.ismac then
    full_cmd = " " .. full_cmd -- adding a space in front of the command prevents bash from recording the command in the history (if configured)
  end

  full_cmd = full_cmd .. '"' .. executable .. '"'

  -- Add args to the cmd
  if args then
    for _, arg in ipairs(args) do
      full_cmd = full_cmd .. " " .. arg
    end
  end

  if osys.iswin32 then -- wrap in sub process to prevent env vars from being persited
    full_cmd = 'cmd /C "' .. full_cmd .. '"'
  end

  return full_cmd
end

function _terminal.prepare_cmd_for_execute(cmd, env, args)
  local full_cmd = ""
  if next(env) then
    full_cmd = full_cmd .. cmd .. " -E " .. " env " .. table.concat(env, " ") .. " " .. cmd
  else
    full_cmd = full_cmd .. cmd
  end

  -- Add args to the cmd
  for _, arg in ipairs(args) do
    full_cmd = full_cmd .. " " .. arg
  end

  return full_cmd
end

function _terminal.run(cmd, env_script, env, args, cwd, opts)
  local prefix = opts.prefix_name -- [CMakeTools]

  -- prefix is added to the terminal name because the reposition_term() function needs to find it
  local terminal_already_exists, buffer_idx = _terminal.create_if_not_exists(
    prefix .. opts.name, -- [CMakeTools]Executor Terminal/Runner Terminal
    opts
  )
  _terminal.id = buffer_idx

  -- Reposition the terminal buffer, before sending commands
  local final_win_id = _terminal.reposition(opts)

  --- NOTE: env_script needs to be run only once if the terminal buffer does not already exist
  --- We compare the old and the new id and only if they are not the same, plus if the terminal exists,
  --    only then, we do not reinitialize the environment, else we reinit the env
  if not terminal_already_exists or _terminal.id_old ~= _terminal.id then
    _terminal.id_old = _terminal.id
    _terminal.send_data_to_terminal(buffer_idx, env_script, {
      win_id = final_win_id,
      prefix = opts.prefix_name,
      split_direction = opts.split_direction,
      split_size = opts.split_size,
      start_insert = opts.start_insert,
      focus = opts.focus,
    })
  end

  -- Send final cmd to terminal
  _terminal.send_data_to_terminal(buffer_idx, cmd, {
    win_id = final_win_id,
    prefix = opts.prefix_name,
    split_direction = opts.split_direction,
    split_size = opts.split_size,
    start_insert = opts.start_insert,
    focus = opts.focus,
    do_not_add_newline = opts.do_not_add_newline,
  })
end

function _terminal.prepare_launch_path(path)
  if osys.iswin32 then
    path = '"' .. path .. '"' -- The path is kept in double quotes ... Windows Duh!
  elseif osys.islinux then
    path = path
  elseif osys.iswsl then
    path = path
  elseif osys.ismac then
    path = path
  end

  return path
end

function _terminal.close(opts)
  if not _terminal.id then
    log.info("There is no terminal instance")
    return
  end

  local win_id = _terminal.reposition(opts)

  if win_id ~= -1 then
    vim.api.nvim_win_close(win_id, false)
  else
    -- log.error("Invalid window Id!")
    -- do nothing
  end
end

function _terminal.stop(opts)
  if not _terminal.has_active_job() then
    return
  end
  local main_pid = vim.api.nvim_buf_get_var(_terminal.id, "terminal_job_pid")
  local child_procs = vim.api.nvim_get_proc_children(main_pid)
  for _, pid in ipairs(child_procs) do
    vim.loop.kill(pid, 9)
  end
end

function _terminal.is_installed()
  return true
end

return _terminal
