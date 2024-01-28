local has_toggleterm, toggleterm = pcall(require, "toggleterm")
local log = require("cmake-tools.log")

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
  _toggleterm.cmd = cmd .. " " .. table.concat(args, " ")
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
      on_output(nil, data)
    end, -- callback for processing output on stderr
    on_exit = function(t, job, exit_code, name)
      on_exit(exit_code)
    end, -- function to run when terminal process exits
  })
  _toggleterm.term:toggle()
  _toggleterm.chan_id = _toggleterm.term.chan_id
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
  vim.fn.jobstop(_toggleterm.chan_id)
  _toggleterm.chan_id = nil
  _toggleterm.cmd = nil
  _toggleterm.term:close()
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
