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

---Show the current executing command
---@param opts quickfix_opts_type options for this adapter
---@return nil
function quickfix.show(opts)
  vim.api.nvim_command(opts.position .. " copen " .. opts.size)
  vim.api.nvim_command("wincmd p")
end

---Close the current executing command
---@param opts quickfix_opts_type options for this adapter
---@return nil
function quickfix.close(opts)
  vim.api.nvim_command("cclose")
end

---Run a commond
---@param cmd string the executable to execute
---@param env table environment variables
---@param args table arguments to the executable
---@param opts quickfix_opts_type options for this adapter
---@param on_success nil|function extra arguments, f.e on_success is a callback to be called when the process finishes
---@return nil
function quickfix.run(cmd, env, args, opts, on_success)
  vim.fn.setqflist({}, " ", { title = cmd .. " " .. table.concat(args, " ") })
  if opts.show == "always" then
    quickfix.show(opts)
  end

  quickfix.job = Job:new({
    command = cmd,
    args = next(env) and { "-E", "env", table.concat(env, " "), "cmake", unpack(args) } or args,
    cwd = vim.loop.cwd(),
    on_stdout = vim.schedule_wrap(append_to_quickfix),
    on_stderr = vim.schedule_wrap(append_to_quickfix),
    on_exit = vim.schedule_wrap(function(_, code, signal)
      append_to_quickfix("Exited with code " .. (signal == 0 and code or 128 + signal))
      if code == 0 and signal == 0 then
        if on_success ~= nil then
          on_success()
        end
      elseif opts.show == "only_on_error" then
        quickfix.show(opts)
        quickfix.scroll_to_bottom()
      end
    end),
  })

  quickfix.job:start()
  --return quickfix.job
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

return quickfix
