local Job = require("plenary.job")
local utils = require("cmake-tools.utils")
local const = require("cmake-tools.const")
local terminal = require("cmake-tools.terminal")

local ctest = {}

function ctest.list_all_tests(build_dir)
  local result = {}

  Job:new({
    command = "ctest",
    args = { "--test-dir", build_dir, "--show-only=json-v1" },
    on_exit = function(j, _, _)
      local json_data = ""

      for _, v in pairs(j:result()) do
        json_data = json_data .. v
      end

      result = json_data
    end,
  }):sync()

  result = vim.fn.json_decode(result)

  local tests = {}
  for _, item in ipairs(result.tests) do
    table.insert(tests, item["name"])
  end

  return tests
end

function ctest.run(ctest_command, test_name, build_dir, env, config)
  local cmd = ctest_command
  local args = { "--test-dir", build_dir, "-R", test_name }
  if config.runner.name == "terminal" then
    cmd = terminal.prepare_cmd_for_run(cmd, args, config.cwd, nil, env)
    utils.run(
      cmd,
      config.env_script,
      {},
      {},
      config.cwd,
      config.runner,
      nil,
      const.cmake_notifications
    )
  else
    utils.run(
      cmd,
      config.env_script,
      env,
      args,
      config.cwd,
      config.runner,
      nil,
      const.cmake_notifications
    )
  end
end

return ctest
