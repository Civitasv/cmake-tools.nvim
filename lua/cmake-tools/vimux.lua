local terminal = require("cmake-tools.terminal")
local osys = require("cmake-tools.osys")
local utils = require("cmake-tools.utils")
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
  local full_cmd = _vimux.prepare_cmd_for_run(cmd, env, args, cwd)
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

function _vimux.prepare_cmd_for_run(cmd, env, args, cwd)
  local full_cmd = ""

  -- Launch form executable's build directory by default
  full_cmd = "cd " .. utils.transform_path(cwd) .. " &&"

  if osys.iswin32 then
    for k, v in pairs(env) do
      full_cmd = full_cmd .. " set " .. k .. "=" .. v .. "&&"
    end
  else
    for k, v in pairs(env) do
      full_cmd = full_cmd .. " " .. k .. "=" .. v .. ""
    end
  end

  full_cmd = full_cmd .. " " .. utils.transform_path(cmd)

  if osys.islinux or osys.iswsl or osys.ismac then
    full_cmd = " " .. full_cmd -- adding a space in front of the command prevents bash from recording the command in the history (if configured)
  end

  -- Add args to the cmd
  for _, arg in ipairs(args) do
    full_cmd = full_cmd .. " " .. arg
  end

  if osys.iswin32 then -- wrap in sub process to prevent env vars from being persited
    full_cmd = 'cmd /C "' .. full_cmd .. '"'
  end

  return full_cmd
end

return _vimux
