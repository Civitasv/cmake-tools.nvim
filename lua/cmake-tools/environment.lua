local osys = require("cmake-tools.osys")

local environment = {}

-- expected format:
--
-- {
--   inherit_base_environment = true/false -- for launch targets only
--   env = {
--      VERBOSE = 1,
--      SOME_PATH = "/tmp/test.txt",
--   }
-- }

-- terminal needs strings to be esacaped
-- for quickfix (plenary.job) dont escape strings because of how it's being passed to cmake.
-- We dont want additional " " in the env vars
local function unroll(env, escape)
  local res = {}

  if osys.iswin32 then
    escape = false -- windows wants env vars unescaped -> set VAL=TEST1 TEST2 ...
  end

  for k, v in pairs(env) do
    local var = k
    if type(v) == "string" then
      if escape then
        var = var .. '="' .. v .. '"'
      else
        var = var .. "=" .. v
      end
      table.insert(res, var)
    elseif type(v) == "number" then
      var = var .. "=" .. v
      table.insert(res, var)
    else
      -- unsupported type
    end
  end

  return res
end

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

function environment.get_build_environment(config, escape)
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

function environment.get_run_environment(config, target, escape)
  return environment.get_run_environment_table(config, target)
end

return environment
