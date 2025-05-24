local Job = require("plenary.job")
local utils = require("cmake-tools.utils")
local const = require("cmake-tools.const")

local ctest = {
  job = nil,
}

function ctest.list_all_tests(build_dir, callback)
  local result = {}

  ctest.job = Job:new({
    command = "ctest",
    args = { "--test-dir", build_dir, "--show-only=json-v1" },
    on_exit = function(j, _, _)
      vim.schedule(function()
        local json_data = ""

        for _, v in pairs(j:result()) do
          json_data = json_data .. v
        end

        result = vim.fn.json_decode(json_data)

        local tests = {}
        for _, item in ipairs(result.tests) do
          table.insert(tests, item["name"])
        end
        callback(tests)
      end)
    end,
  })

  ctest.job:start()
end

function ctest.run(ctest_command, test_name, build_dir, env, config, opt)
  local cmd = ctest_command
  opt = opt or {}

  local args = { "--test-dir", utils.transform_path(build_dir), "-R", test_name, opt.args }
  utils.run(cmd, config.env_script, env, args, config.cwd, config.runner, nil)
end

function ctest.stop()
  if not ctest.job or ctest.job.is_shut_down then
    return
  end
  ctest.job:shutdown(1, 9)

  for _, pid in ipairs(vim.api.nvim_get_proc_children(ctest.job.pid)) do
    vim.loop.kill(pid, 9)
  end
end

return ctest
