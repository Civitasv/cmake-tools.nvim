local overseer = require("overseer")
local log = require("cmake-tools.log")

---@class overseer_exec : executor
local overseer_executor = {
  job = nil,
}

---Show the current executing command
---@param opts table options for this adapter
---@return nil
function overseer_executor.show(opts)
  overseer.open()
end

---Close the current executing command
---@param opts table options for this adapter
---@return nil
function overseer_executor.close(opts)
  overseer.close()
end

---Run a commond
---@param cmd string the executable to execute
---@param env table environment variables
---@param args table arguments to the executable
---@param opts table options for this adapter
---@param on_success nil|function extra arguments, f.e on_success is a callback to be called when the process finishes
---@return nil
function overseer_executor.run(cmd, env, args, opts, on_success)
  opts = {
    cmd = cmd,
    args = args,
    env = env,
    cwd = vim.fn.getcwd(),
    strategy = opts.strategy,
  }
  overseer_executor.job = overseer.new_task(opts)
  overseer_executor.job:subscribe("on_complete", on_success)
  --overseer_executor.job:subscribe("on_output", on_output)
  overseer_executor.job:start()
end

---Checks if there is an active job
---@param opts table options for this adapter
---@return boolean
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

---Stop the active job
---@param opts table options for this adapter
---@return nil
function overseer_executor.stop(opts)
  overseer_executor.job:stop()
end

return overseer_executor
