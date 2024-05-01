---@class runner
local runner = {}

---Show the current running command
---@param opts table options for this adapter
---@return nil
function runner.show(opts) end

---Close the current running command
---@param opts table options for this adapter
---@return nil
function runner.close(opts) end

---Run a commond
---@param cmd string the executable to execute
---@param env_script string environment setup script
---@param env table environment variables
---@param args table arguments to the executable
---@param cwd string the directory to run in
---@param opts table options for this adapter
---@param on_exit nil|function extra arguments, f.e on_exit is a callback to be called when the process finishes
---@param on_output nil|function extra arguments, f.e on_output is a callback to be called when the process has new output
---@return nil
function runner.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output) end

---Checks if there is an active job
---@param opts table options for this adapter
---@return boolean
function runner.has_active_job(opts) end

---Stop the active job
---@param opts table options for this adapter
---@return nil
function runner.stop(opts) end

---Check if the runner is installed and can be used
-- if it is installed, return true
-- else return a diagnostics info string
---@return string|boolean
function runner.is_installed() end
