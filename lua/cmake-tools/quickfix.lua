local log = require("cmake-tools.log")
local Job = require("plenary.job")
local has_notify, notify = pcall(require, "notify")

local quickfix = {
  job = nil,
  notification = {},
}

function quickfix.update_spinner() -- update spinner helper function to defer
  if quickfix.notification.spinner_idx then
    local new_spinner = (quickfix.notification.spinner_idx + 1) % #quickfix.notification.spinner
    quickfix.notification.spinner_idx = new_spinner

    quickfix.notification.id = quickfix.notify(nil, quickfix.notification.level, {
      title = "CMakeTools",
      hide_from_history = true,
      icon = quickfix.notification.spinner[new_spinner],
      replace = quickfix.notification.id,
    })

    vim.defer_fn(function()
      quickfix.update_spinner()
    end, quickfix.notification.refresh_rate_ms)
  end
end

function quickfix.notify(msg, lvl, opts)
  if quickfix.notification.enabled and has_notify then
    opts.hide_from_history = true
    return notify(msg, lvl, opts)
  end
end

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

  if line and line:match("^%[%s*(%d+)%s*%%%]") then -- only show lines containing build progress e.g [ 12%]
    quickfix.notification.id = quickfix.notify( -- notify with percentage and message
      line,
      quickfix.notification.level,
      { replace = quickfix.notification.id, title = "CMakeTools" }
    )
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

  quickfix.notification = opts.cmake_notifications

  if quickfix.notification.enabled then
    quickfix.notification.spinner_idx = 1
    quickfix.notification.level = "info"

    quickfix.notification.id =
      quickfix.notify(cmd, quickfix.notification.level, { title = "CMakeTools" })
    quickfix.update_spinner()
  end

  quickfix.job = Job:new({
    command = cmd,
    args = next(env) and { "-E", "env", table.concat(env, " "), "cmake", unpack(args) } or args,
    cwd = vim.loop.cwd(),
    on_stdout = vim.schedule_wrap(append_to_quickfix),
    on_stderr = vim.schedule_wrap(function(err, data)
      quickfix.notification.level = "warn"
      append_to_quickfix(err, data)
    end),
    on_exit = vim.schedule_wrap(function(_, code, signal)
      local msg = "Exited with code " .. (signal == 0 and code or 128 + signal)
      local level = "error"
      local icon = ""

      append_to_quickfix(msg)

      if code == 0 and signal == 0 then
        level = quickfix.notification.level -- either info or warn
        icon = ""
        if opts.on_success then
          opts.on_success()
        end
      elseif opts.cmake_quickfix_opts.show == "only_on_error" then
        quickfix.show(opts.cmake_quickfix_opts)
        quickfix.scroll_to_bottom()
      end

      quickfix.notify(
        msg,
        level,
        { icon = icon, replace = quickfix.notification.id, timeout = 3000 }
      )

      quickfix.notification = {} -- reset and stop update_spinner
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
