local Job = require("plenary.job")

local ctest = {}

function ctest.list_all_tests(build_dir)
  local result = {}

  local job = Job:new({
    command = "ctest",
    args = { "--test-dir", build_dir, "--show-only=json-v1" },
    on_exit = function(j, _, _)
      result = vim.inspect(j:result())
    end,
  }):sync()

  return result
end

return ctest
