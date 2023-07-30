local overseer = require("overseer")
local log = require("cmake-tools.log")

---@class overseer_exec : executor
local overseer_executor = {
  job = nil,
}

function overseer_executor.show(opts)
  overseer.open()
end

function overseer_executor.close(opts)
  overseer.close()
end

function overseer_executor.run(cmd, env, args, opts, on_exit, on_output)
  opts = {
    cmd = cmd,
    args = args,
    env = env,
    cwd = vim.fn.getcwd(),
    strategy = opts.strategy,
  }
  overseer_executor.job = overseer.new_task(opts)
  overseer_executor.job:subscribe("on_exit", on_exit)
  overseer_executor.job:subscribe("on_output", on_output)
  overseer_executor.job:start()
end

function overseer_executor.has_active_job(opts)
  if overseer_executor.job ~= nil and overseer_executor.job:is_running() then
    log.error(
      "A CMake task is already running: "
        .. overseer_executor.job.command
        .. " Stop it before trying to run a new CMake task."
    )
    return true
  end
  return false
end

function overseer_executor.stop(opts)
  overseer_executor.job:stop()
end

return overseer_executor
