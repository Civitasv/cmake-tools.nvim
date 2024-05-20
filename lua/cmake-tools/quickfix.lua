local log = require("cmake-tools.log")
local Job = require("plenary.job")

---@alias quickfix_show '"always"'|'"only_on_error"'
---@alias quickfix_position '"belowright"'|'"bottom"'|'"top"'
---@alias quickfix_opts_type {show:quickfix_show, position:quickfix_position, size:number}
--
---@class quickfix : executor, runner
local _quickfix = {
  job = nil,
}

function _quickfix.scroll_to_bottom()
  vim.api.nvim_command("cbottom")
end

local function append_to_quickfix(encoding, error, data)
  local line = error and error or data
  if encoding ~= "utf-8" then
    line = vim.fn.iconv(line, encoding, "utf-8")
  end

  vim.fn.setqflist({}, "a", { lines = { line } })
  -- scroll the quickfix buffer to bottom
  if _quickfix.check_scroll() then
    _quickfix.scroll_to_bottom()
  end
end

function _quickfix.show(opts)
  vim.api.nvim_command(opts.position .. " copen " .. opts.size)
  vim.api.nvim_command("wincmd p")
end

function _quickfix.close(opts)
  vim.api.nvim_command("cclose")
end

function _quickfix.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
  vim.fn.setqflist({}, " ", { title = cmd .. " " .. table.concat(args, " ") })
  if opts.show == "always" then
    _quickfix.show(opts)
  end

  -- NOTE: Unused env_script for quickfix.run() as plenary does not yet support running scripts

  env = vim.tbl_deep_extend("keep", env, vim.fn.environ())

  _quickfix.job = Job:new({
    command = cmd,
    args = args,
    cwd = cwd,
    env = env,
    on_stdout = vim.schedule_wrap(function(err, data)
      append_to_quickfix(opts.encoding, err, data)
      on_output(data, err)
    end),
    on_stderr = vim.schedule_wrap(function(err, data)
      append_to_quickfix(opts.encoding, err, data)
      on_output(data, err)
    end),
    on_exit = vim.schedule_wrap(function(_, code, signal)
      code = signal == 0 and code or 128 + signal
      local msg = "Exited with code " .. code

      append_to_quickfix(opts.encoding, msg)
      if code ~= 0 and opts.show == "only_on_error" then
        _quickfix.show(opts)
        _quickfix.scroll_to_bottom()
      end
      if code == 0 and opts.auto_close_when_success then
        _quickfix.close(opts)
      end
      if on_exit ~= nil then
        on_exit(code)
      end
    end),
  })

  _quickfix.job:start()
end

---Checks if there is an active job
---@param opts quickfix_opts_type options for this adapter
---@return boolean
function _quickfix.has_active_job(opts)
  if not _quickfix.job or _quickfix.job.is_shutdown then
    return false
  end
  log.error(
    "A CMake task is already running: "
      .. _quickfix.job.command
      .. " Stop it before trying to run a new CMake task."
  )
  return true
end

---Stop the active job
---@param opts quickfix_opts_type options for this adapter
---@return nil
function _quickfix.stop(opts)
  if not _quickfix.job or _quickfix.job.is_shutdown then
    return
  end
  _quickfix.job:shutdown(1, 9)

  for _, pid in ipairs(vim.api.nvim_get_proc_children(_quickfix.job.pid)) do
    vim.loop.kill(pid, 9)
  end
end

function _quickfix.check_scroll()
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

function _quickfix.is_installed()
  return true
end

return _quickfix
