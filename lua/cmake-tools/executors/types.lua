---@class executor
local executor = {}

---Show the current executing command
---@param opts table options for this adapter
---@return nil
function executor.show(opts) end

---Close the current executing command
---@param opts table options for this adapter
---@return nil
function executor.close(opts) end

---Run a commond
---@param cmd string the executable to execute
---@param env table environment variables
---@param args table arguments to the executable
---@param opts table options for this adapter
---@param on_success nil|function extra arguments, f.e on_success is a callback to be called when the process finishes
---@return nil
function executor.run(cmd, env, args, opts, on_success) end

---Checks if there is an active job
---@param opts table options for this adapter
---@return boolean
function executor.has_active_job(opts) end

---Stop the active job
---@param opts table options for this adapter
---@return nil
function executor.stop(opts) end
