-- External konsole runner for cmake-tools
local M = {}

function M.is_installed()
  -- Check if konsole is available
  return vim.fn.executable("konsole") == 1
end

function M.run(cmd, env_script, env, args, cwd, opts, on_exit, on_output)
  -- Build the command with environment variables and arguments
  local env_str = ""
  for k, v in pairs(env) do
    env_str = env_str .. string.format("%s=%s ", k, vim.fn.shellescape(v))
  end
  
  local args_str = ""
  for _, arg in ipairs(args) do
    args_str = args_str .. " " .. vim.fn.shellescape(arg)
  end
  
  -- Change to the working directory and run the command
  local full_cmd = string.format("cd %s && %s%s%s", 
    vim.fn.shellescape(cwd),
    env_str,
    cmd,
    args_str
  )
  
  -- Launch in konsole with --hold to keep window open after program exits
  local konsole_cmd = string.format("konsole --hold -e sh -c %s >/dev/null 2>&1 &", 
    vim.fn.shellescape(full_cmd)
  )
  
  vim.fn.jobstart(konsole_cmd, { 
    detach = true,
  })
  
  -- Call on_exit immediately with success code since we can't track external process
  if on_exit then
    on_exit(0, 0)
  end
end

-- Required stub functions for runner interface
function M.has_active_job(opts)
  return false
end

function M.show(opts)
  -- Nothing to show for external runner
end

function M.close()
  -- Nothing to close
end

function M.stop()
  -- Can't stop external processes easily
end

return M
