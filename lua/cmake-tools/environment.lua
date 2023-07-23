local osys = require("cmake-tools.osys")
local utils = require("cmake-tools.utils")
local logger = require("cmake-tools.log")

local environment = {}

-- expected format:
--
-- {
--   inherit_build_environment = true/false -- for launch targets only
--   env = {
--      VERBOSE = 1,
--      SOME_PATH = "/tmp/test.txt",
--   }
-- }

-- parse and merge configured environment variables
function environment.get_build_environment(config)
  local env = {}

  local buildenv = nil
  if config.build_environment ~= nil then
    buildenv = loadstring(config.build_environment)()
  end

  if buildenv ~= nil and buildenv.env ~= nil then
    env = vim.tbl_deep_extend("force", env, buildenv.env)
  end

  return env
end

-- parse and merge configured environment variables
function environment.get_run_environment(config, target)
  local env = {}

  local runenv = nil
  if config.run_environments and config.run_environments[target] ~= nil then
    runenv = loadstring(config.run_environments[target])()
  end

  local buildenv = environment.get_build_environment(config)

  if runenv ~= nil then
    if runenv.inherit_build_environment ~= nil and runenv.inherit_build_environment == true then
      env = vim.tbl_deep_extend("force", env, buildenv)
    end
    if runenv.env ~= nil then
      env = vim.tbl_deep_extend("force", env, runenv.env)
    end
  else
    if buildenv ~= nil and buildenv.env ~= nil then
      env = vim.tbl_deep_extend("force", env, buildenv)
    end
  end
  return env
end

return environment
