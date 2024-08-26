local has_toggleterm, toggleterm = pcall(require, "toggleterm")
local osys = require("cmake-tools.osys")
local log = require("cmake-tools.log")
local utils = require("cmake-tools.utils")

if not has_toggleterm then
  return
end

local _terminal = require("toggleterm.terminal")

---@class _toggleterm : executor, runner
local _toggleterm = {
  chan_id = nil,
  term = nil,
  cmd = nil,
}

function _toggleterm.show(opts)
  _toggleterm.term:open()
end

function _toggleterm.close(opts)
  _toggleterm.term:close()
end

function _toggleterm.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
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

  _toggleterm.cmd = full_cmd
  if opts.singleton and _toggleterm.term then
    _toggleterm.term:close()
  end
  _toggleterm.term = _terminal.Terminal:new({
    --[[ env = {},             -- key:value table with environmental variables passed to jobstart() ]]
    cmd = _toggleterm.cmd,
    dir = cwd, -- the directory for the terminal
    direction = opts.direction, -- the layout for the terminal, same as the main config options
    close_on_exit = opts.close_on_exit, -- close the terminal window when the process exits
    auto_scroll = opts.auto_scroll, -- automatically scroll to the bottom on terminal output
    -- callbacks for processing the output
    on_stdout = function(t, job, data, name)
      on_output(data)
    end, -- callback for processing output on stdout
    on_stderr = function(t, job, data, name)
      if opts.scroll_on_error then
        _toggleterm.term:scroll_bottom()
      end
      on_output(nil, data)
    end, -- callback for processing output on stderr
    on_exit = function(t, job, exit_code, name)
      on_exit(exit_code)
      if exit_code ~= 0 then -- operation failed
        if opts.scroll_on_error then
          _toggleterm.term:scroll_bottom()
        end
        if opts.focus_on_error then
          vim.cmd("wincmd p")
        end
      end
      _toggleterm.chan_id = nil
      _toggleterm.cmd = nil
    end, -- function to run when terminal process exits
  })
  if not _toggleterm.term:is_open() then
    _toggleterm.term:open()
    if not opts.auto_focus then -- focus back on editor
      vim.cmd("wincmd p")
      vim.cmd("stopinsert!")
    end
  end
  _toggleterm.chan_id = _toggleterm.term.job_id
end

function _toggleterm.has_active_job(opts)
  if _toggleterm.chan_id ~= nil then
    log.error(
      "A CMake task is already running: "
        .. _toggleterm.cmd
        .. " Stop it before trying to run a new CMake task."
    )
    return true
  end
  return false
end

function _toggleterm.stop(opts)
  if _toggleterm.chan_id then
    vim.fn.jobstop(_toggleterm.chan_id)
    _toggleterm.chan_id = nil
    _toggleterm.cmd = nil
    _toggleterm.term:close()
  end
end

---Check if the executor is installed and can be used
---@return string|boolean
function _toggleterm.is_installed()
  if not has_toggleterm then
    return "toggleterm plugin is missing, please install it"
  end
  return true
end

return _toggleterm
