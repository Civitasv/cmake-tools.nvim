local has_overseer, overseer = pcall(require, "overseer")
local log = require("cmake-tools.log")

---@class _overseer : executor, runner
local _overseer = {
  job = nil,
}

function _overseer.show(opts)
  overseer.open()
end

function _overseer.close(opts)
  overseer.close()
end

function _overseer.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
  local new_task_opts = vim.tbl_extend("keep", {
    -- cmd = env_script .. " && " .. cmd, -- Temporarily disabling envScript for Overseer: Refer #158 and #159 for more details
    cmd = cmd,
    args = args,
    env = env,
    cwd = cwd,
  }, opts.new_task_opts)
  _overseer.job = overseer.new_task(new_task_opts)
  if on_exit ~= nil then
    _overseer.job:subscribe(
      "on_exit",
      vim.schedule_wrap(function(out)
        on_exit(out.exit_code)
      end)
    )
  end
  if on_output ~= nil then
    _overseer.job:subscribe(
      "on_output",
      vim.schedule_wrap(function(_, data)
        local stdout = data[0]
        local stderr = data[1]
        on_output(stdout, stderr)
      end)
    )
  end
  if opts.on_new_task ~= nil then
    opts.on_new_task(_overseer.job)
  end
  _overseer.job:start()
end

function _overseer.has_active_job(opts)
  if _overseer.job ~= nil and _overseer.job:is_running() then
    log.error(
      "A CMake task is already running: `"
        .. (_overseer.job.name or _overseer.job.cmd)
        .. "` Stop it before trying to run a new CMake task."
    )
    return true
  end
  return false
end

function _overseer.stop(opts)
  if _overseer.job ~= nil and _overseer.job:is_running() then
    _overseer.job:stop()
  end
end

---Check if the executor is installed and can be used
---@return string|boolean
function _overseer.is_installed()
  if not has_overseer then
    return "Overseer plugin is missing, please install it"
  end
  return true
end

return _overseer
