local log = require("cmake-tools.log")
local Job = require("plenary.job")

local quickfix = {
  job = nil
}

function quickfix.scroll_to_bottom()
  vim.api.nvim_command("cbottom")
end

local function append_to_quickfix(error, data)
  local line = error and error or data
  vim.fn.setqflist({}, "a", { lines = { line } })
  -- scroll the quickfix buffer to bottom
  quickfix.scroll_to_bottom()
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

  quickfix.job = Job:new({
    command = cmd,
    args = next(env) and { "-E", "env", table.concat(env, " "), "cmake", unpack(args) } or args,
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
    return true
  end
  log.error(
    "A CMake task is already running: "
    .. quickfix.job.command
    .. " Stop it before trying to run a new CMake task."
  )
  return false
end

return quickfix
