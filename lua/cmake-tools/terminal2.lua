local osys = require("cmake-tools.osys")
local log = require("cmake-tools.log")
local dump = require("helpers").dump
---@class terminal2 : executor, runner
local _terminal2 = {
  id = nil, -- id for the unified terminal
  id_old = nil, -- Old id to keep track of the buffer
}

function _terminal2.has_active_job(opts)
  if _terminal2.id then
    -- first, check if this buffer is valid
    if not vim.api.nvim_buf_is_valid(_terminal2.id) then
      return false
    end
    local main_pid = vim.api.nvim_buf_get_var(_terminal2.id, "terminal_job_pid")
    local child_procs = vim.api.nvim_get_proc_children(main_pid)

    if next(child_procs) then
      return true
    else
      return false
    end
  end

  return false
end

-- function _terminal2.show(opts)
--   if not _terminal2.id then
--     log.info("There is no terminal instance")
--     return
--   end
--
--   local win_id = _terminal2.reposition(opts)
--
--   if win_id ~= -1 then
--     -- The window is alive, so we set buffer in window
--     vim.api.nvim_win_set_buf(win_id, _terminal2.id)
--     if opts.split_direction == "horizontal" then
--       vim.api.nvim_win_set_height(win_id, opts.split_size)
--     else
--       vim.api.nvim_win_set_width(win_id, opts.split_size)
--     end
--   elseif win_id >= -1 then
--     -- The window is not active, we need to create a new buffer
--     vim.cmd(":" .. opts.split_direction .. " " .. opts.split_size .. "sp") -- Split
--     vim.api.nvim_win_set_buf(0, _terminal2.id)
--   else
--     -- log.error("Invalid window Id!")
--     -- do nothing
--   end
-- end

function _terminal2.get_buffers_with_prefix(prefix)
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

function _terminal2.prepare_cmd_for_run(executable, args, launch_path, wrap_call, env)
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

function _terminal2.prepare_cmd_for_execute(cmd, env, args)
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
function _terminal2.delete_if_exists(prefix)
  local buffs = _terminal2.get_buffers_with_prefix(prefix)
  print(dump(buffs))
  -- Add args to the cmd
  for _, buf in ipairs(buffs) do
    vim.api.nvim_buf_delete(buf, { force = 1 })
  end
end

function _terminal2.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
  local prefix = opts.prefix_name -- [CMakeTools]
  local term_name = prefix .. opts.name
  _terminal2.delete_if_exists(prefix)
  vim.cmd(":" .. opts.split_direction .. " " .. opts.split_size .. "sp | enew ")
  vim.fn.termopen(cmd, {
    cwd = cwd,
    detach = 1,
    -- callbacks for processing the output
    on_stdout = function(t, job, data, name)
      on_output(data)
    end, -- callback for processing output on stdout
    on_stderr = function(t, job, data, name)
      on_output(nil, data)
    end, -- callback for processing output on stderr
    on_exit = function(t, job, exit_code, name)
      on_exit(exit_code)
    end, -- function to run when terminal process exits
  })
  vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), term_name) -- Set the buffer name
end
function _terminal2.prepare_launch_path(path)
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

function _terminal2.close(opts)
  if not _terminal2.id then
    log.info("There is no terminal instance")
    return
  end

  local win_id = _terminal2.reposition(opts)

  if win_id ~= -1 then
    vim.api.nvim_win_close(win_id, false)
  else
    -- log.error("Invalid window Id!")
    -- do nothing
  end
end

function _terminal2.stop(opts)
  if not _terminal2.has_active_job() then
    return
  end
  local main_pid = vim.api.nvim_buf_get_var(_terminal2.id, "terminal_job_pid")
  local child_procs = vim.api.nvim_get_proc_children(main_pid)
  for _, pid in ipairs(child_procs) do
    vim.loop.kill(pid, 9)
  end
end

function _terminal2.is_installed()
  return true
end

return _terminal2
