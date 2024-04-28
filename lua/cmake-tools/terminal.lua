local osys = require("cmake-tools.osys")
local log = require("cmake-tools.log")
local dump = require("cmake-tools.utils").dump
---@class terminal : executor, runner
local _terminal = {
  id = nil, -- id for the unified terminal
  id_old = nil, -- Old id to keep track of the buffer
  is_running = false,
}

function _terminal.has_active_job(opts)
  return _terminal.is_running
  -- if _terminal.id then
  --   -- first, check if this buffer is valid
  --   if not vim.api.nvim_buf_is_valid(_terminal.id) then
  --     return false
  --   end
  --   local main_pid = vim.api.nvim_buf_get_var(_terminal.id, "terminal_job_pid")
  --   local child_procs = vim.api.nvim_get_proc_children(main_pid)
  --
  --   if next(child_procs) then
  --     return true
  --   else
  --     return false
  --   end
  -- end
  --
  -- return false
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

function _terminal.delete_buffer_list(buffer_list)
  for _, buffer in ipairs(buffer_list) do
    vim.api.nvim_buf_delete(buffer, { force = 1 })
  end
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
function _terminal.delete_if_exists(prefix)
  local buffs = _terminal.get_buffers_with_prefix(prefix)
  print(dump(buffs))
  -- Add args to the cmd
  for _, buf in ipairs(buffs) do
    vim.api.nvim_buf_delete(buf, { force = 1 })
  end
end

function _terminal.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
  _terminal.is_running = true
  local prefix = opts.prefix_name -- [CMakeTools]
  local term_name = prefix .. opts.name
  _terminal.delete_if_exists(prefix)
  vim.cmd(":" .. opts.split_direction .. " " .. opts.split_size .. "sp | enew ")
  vim.fn.termopen(cmd, {
    cwd = cwd,
    detach = 1,
    -- callbacks for processing the output
    on_stdout = function(t, data, name)
      on_output(data)
    end, -- callback for processing output on stdout
    on_stderr = function(t, data, name)
      on_output(nil, data)
    end, -- callback for processing output on stderr
    on_exit = function(t, exit_code, name)
      _terminal.is_running = false
      on_exit(exit_code)
    end, -- function to run when terminal process exits
  })
  _terminal.id = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(vim.api.nvim_get_current_buf(), "filetype", "cmake_tools_terminal")

  -- Renamming a terminal buffer creates a new hidden buffer, so duplicate terminals need to be deleted
  local buffers_before = vim.api.nvim_list_bufs()
  vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), term_name) -- Set the buffer name
  local new_buffers_list = vim.api.nvim_list_bufs()
  _terminal.delete_buffer_list(_terminal.symmetric_difference(buffers_before, new_buffers_list))
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
