local log = require("cmake-tools.log")
local Job = require("plenary.job")

---@alias quickfix_show '"always"'|'"only_on_error"'
---@alias quickfix_position '"belowright"'|'"bottom"'|'"top"'
---@alias quickfix_opts_type {show:quickfix_show, position:quickfix_position, size:number}
--
---@class quickfix : executor
local quickfix = {
  job = nil,
}

function quickfix.scroll_to_bottom()
  vim.api.nvim_command("cbottom")
end

local function append_to_quickfix(error, data)
  local line = error and error or data
  vim.fn.setqflist({}, "a", { lines = { line } })
  -- scroll the quickfix buffer to bottom
  if quickfix.check_scroll() then
    quickfix.scroll_to_bottom()
  end
end

function quickfix.show(opts)
  vim.api.nvim_command(opts.position .. " copen " .. opts.size)
  vim.api.nvim_command("wincmd p")
end

function quickfix.close(opts)
  vim.api.nvim_command("cclose")
end

function quickfix.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
  vim.fn.setqflist({}, " ", { title = cmd .. " " .. table.concat(args, " ") })
  if opts.show == "always" then
    quickfix.show(opts)
  end

  -- NOTE: Unused env_script for quickfix.run() as plenary does not yet support running scripts

  local job_args = {}

  if next(env) then
    table.insert(job_args, "-E")
    table.insert(job_args, "env")
    for _, v in ipairs(env) do
      table.insert(job_args, v)
    end
    table.insert(job_args, "cmake")
    for _, v in ipairs(args) do
      table.insert(job_args, v)
    end
  else
    job_args = args
  end

  quickfix.job = Job:new({
    command = cmd,
    args = job_args,
    cwd = cwd,
    on_stdout = vim.schedule_wrap(function(err, data)
      append_to_quickfix(err, data)
      on_output(data, err)
    end),
    on_stderr = vim.schedule_wrap(function(err, data)
      append_to_quickfix(err, data)
      on_output(data, err)
    end),
    on_exit = vim.schedule_wrap(function(_, code, signal)
      code = signal == 0 and code or 128 + signal
      local msg = "Exited with code " .. code

      append_to_quickfix(msg)
      if code ~= 0 and opts.show == "only_on_error" then
        quickfix.show(opts)
        quickfix.scroll_to_bottom()
      end
      if on_exit ~= nil then
        on_exit(code)
      end
    end),
  })

  quickfix.job:start()
end

---Checks if there is an active job
---@param opts quickfix_opts_type options for this adapter
---@return boolean
function quickfix.has_active_job(opts)
  if not quickfix.job or quickfix.job.is_shutdown then
    return false
  end
  log.error(
    "A CMake task is already running: "
      .. quickfix.job.command
      .. " Stop it before trying to run a new CMake task."
  )
  return true
end

---Stop the active job
---@param opts quickfix_opts_type options for this adapter
---@return nil
function quickfix.stop(opts)
  quickfix.job:shutdown(1, 9)

  for _, pid in ipairs(vim.api.nvim_get_proc_children(quickfix.job.pid)) do
    vim.loop.kill(pid, 9)
  end
end

function quickfix.check_scroll()
  local function is_cursor_at_last_line()
    local current_buf = vim.api.nvim_win_get_buf(0)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local line_count = vim.api.nvim_buf_line_count(current_buf)

    return cursor_pos[1] == line_count - 1
  end

  local buffer_type = vim.api.nvim_buf_get_option(0, "buftype")

  if buffer_type == "quickfix" then
    return is_cursor_at_last_line()
  end

  return true
end

function quickfix.is_installed()
  return true
end

return quickfix
