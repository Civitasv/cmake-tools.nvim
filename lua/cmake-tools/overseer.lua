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

  local ok, task = pcall(overseer.new_task, new_task_opts)
  if not ok then
    return log.error("Cannot create the overseer task: " .. tostring(task))
  end
  _overseer.job = task

  if on_exit ~= nil then
    _overseer.job:subscribe(
      "on_complete",
      vim.schedule_wrap(function(task_, status)
        on_exit(task_.exit_code or (status == "SUCCESS" and 0 or 1))
      end)
    )
  end
  if on_output ~= nil then
    _overseer.job:subscribe(
      "on_output_lines",
      vim.schedule_wrap(function(_, lines)
        for _, line in ipairs(lines) do
          on_output(line, nil)
        end
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
    local cmd = _overseer.job.cmd
    local name = _overseer.job.name or (type(cmd) == "table" and table.concat(cmd, " ") or cmd)
    log.error(
      "A CMake task is already running: `"
        .. name
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
