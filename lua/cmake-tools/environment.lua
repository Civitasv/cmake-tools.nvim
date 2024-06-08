local osys = require("cmake-tools.osys")

local environment = {}

-- parse and merge configured environment variables
function environment.get_build_environment_table(config)
  local env = {}

  local buildenv = nil
  if config.base_settings ~= nil then
    buildenv = config.base_settings
  end

  if buildenv ~= nil and buildenv.env ~= nil then
    env = vim.tbl_deep_extend("force", env, buildenv.env)
  end

  return env
end

function environment.get_build_environment(config)
  local env = environment.get_build_environment_table(config)
  return env
end

-- parse and merge configured environment variables
function environment.get_run_environment_table(config, target)
  local env = {}

  local runenv = nil
  if config.target_settings and config.target_settings[target] ~= nil then
    runenv = config.target_settings[target]
  end

  local buildenv = environment.get_build_environment_table(config)

  if runenv ~= nil then
    if runenv.inherit_base_environment ~= nil and runenv.inherit_base_environment == true then
      env = vim.tbl_deep_extend("force", env, buildenv)
    end
    if runenv.env ~= nil then
      env = vim.tbl_deep_extend("force", env, runenv.env)
    end
  else
    env = vim.tbl_deep_extend("force", env, buildenv)
  end

  return env
end

function environment.get_run_environment(config, target)
  return environment.get_run_environment_table(config, target)
end

return environment
