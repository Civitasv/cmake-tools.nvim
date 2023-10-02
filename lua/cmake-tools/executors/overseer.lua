local has_overseer, overseer = pcall(require, "overseer")
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

function overseer_executor.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
  opts = vim.tbl_extend("keep", {
    -- cmd = env_script .. " && " .. cmd, -- Temporarily disabling envScript for Overseer: Refer #158 and #159 for more details
    cmd = cmd,
    args = args,
    env = env,
    cwd = cwd,
  }, opts.new_task_opts)
  overseer_executor.job = overseer.new_task(opts)
  if on_exit ~= nil then
    overseer_executor.job:subscribe("on_exit", function(out)
      on_exit(out.exit_code)
    end)
  end
  if on_output ~= nil then
    overseer_executor.job:subscribe("on_output", function(_, data)
      local stdout = data[0]
      local stderr = data[1]
      on_output(stdout, stderr)
    end)
  end
  if opts.on_new_task ~= nil then
    opts.on_new_task(overseer_executor.job)
  end
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

---Check if the executor is installed and can be used
---@return string|boolean
function overseer_executor.is_installed()
  if not has_overseer then
    return "Overseer plugin is missing, please install it"
  end
  return true
end

return overseer_executor
