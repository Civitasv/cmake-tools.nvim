local terminal = require("cmake-tools.terminal")

---@class vimux : terminal
local _vimux = {
  id = nil,
}

function _vimux.show(opts)
  vim.fn.VimuxInspectRunner()
end

function _vimux.close(opts)
  vim.fn.VimuxCloseRunner()
end

function _vimux.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
  local full_cmd = terminal.prepare_cmd_for_run(cmd, env, args, cwd)
  vim.fn.VimuxRunCommand(full_cmd)
  terminal.handle_exit(opts, on_exit, opts.close_on_exit)
end

function _vimux.has_active_job(opts)
  return false
end

function _vimux.stop(opts)
  vim.fn.VimuxSendKeys("C-c")
end

---Check if the executor is installed and can be used
---@return string|boolean
function _vimux.is_installed()
  if not vim.fn.exists(":VimuxRunCommand") then
    return "Vimux plugin is missing, please install it"
  end
  return true
end

return _vimux
