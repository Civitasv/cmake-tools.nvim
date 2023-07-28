local log = require("cmake-tools.log")
local Job = require("plenary.job")

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

function quickfix.show(quickfix_opts)
  vim.api.nvim_command(quickfix_opts.position .. " copen " .. quickfix_opts.size)
  vim.api.nvim_command("wincmd p")
end

function quickfix.close()
  vim.api.nvim_command("cclose")
end

function quickfix.run(cmd, env, args, opts)
  vim.fn.setqflist({}, " ", { title = cmd .. " " .. table.concat(args, " ") })
  if opts.cmake_quickfix_opts.show == "always" then
    quickfix.show(opts.cmake_quickfix_opts)
  end

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
    cwd = vim.loop.cwd(),
    on_stdout = vim.schedule_wrap(append_to_quickfix),
    on_stderr = vim.schedule_wrap(append_to_quickfix),
    on_exit = vim.schedule_wrap(function(_, code, signal)
      append_to_quickfix("Exited with code " .. (signal == 0 and code or 128 + signal))
      if code == 0 and signal == 0 then
        if opts.on_success then
          opts.on_success()
        end
      elseif opts.cmake_quickfix_opts.show == "only_on_error" then
        quickfix.show(opts.cmake_quickfix_opts)
        quickfix.scroll_to_bottom()
      end
    end),
  })

  quickfix.job:start()
  return quickfix.job
end

function quickfix.has_active_job()
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

function quickfix.stop()
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

return quickfix
