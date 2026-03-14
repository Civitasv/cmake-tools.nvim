local Job = require("plenary.job")
local utils = require("cmake-tools.utils")

local ctest = {
  job = nil,
}

function ctest.list_all_tests(build_dir, preset_name, callback)
  local result = {}

  local args
  if preset_name then
    args = { "--preset", preset_name, "--show-only=json-v1" }
  else
    args = { "--test-dir", build_dir, "--show-only=json-v1" }
  end

  ctest.job = Job:new({
    command = "ctest",
    args = args,
    on_exit = function(j, _, _)
      vim.schedule(function()
        local json_data = ""

        for _, v in pairs(j:result()) do
          json_data = json_data .. v
        end

        result = vim.fn.json_decode(json_data)

        local tests = {}
        for _, item in ipairs(result.tests) do
          local labels = {}
          if item["properties"] then
            for _, prop in ipairs(item["properties"]) do
              if prop["name"] == "LABELS" then
                labels = prop["value"] or {}
                break
              end
            end
          end
          table.insert(tests, { name = item["name"], labels = labels })
        end
        callback(tests)
      end)
    end,
  })

  ctest.job:start()
end

--- Collect all labels from test objects with counts
--- @param tests { name: string, labels: string[] }[]
--- @return { label: string, count: number }[] sorted list of labels with their test counts
function ctest.get_all_labels(tests)
  local label_counts = {}
  for _, test in ipairs(tests) do
    for _, label in ipairs(test.labels) do
      label_counts[label] = (label_counts[label] or 0) + 1
    end
  end

  local labels = {}
  for label, count in pairs(label_counts) do
    table.insert(labels, { label = label, count = count })
  end
  table.sort(labels, function(a, b)
    return a.label < b.label
  end)
  return labels
end

function ctest.run(ctest_command, env, config, opt)
  opt = opt or {}

  local args = {}
  if opt.preset then
    vim.list_extend(args, { "--preset", opt.preset })
  else
    vim.list_extend(args, { "--test-dir", utils.transform_path(opt.build_dir) })
  end

  if opt.label then
    vim.list_extend(args, { "-L", opt.label })
  elseif opt.test_name then
    vim.list_extend(args, { "-R", opt.test_name })
  end

  if opt.args then
    table.insert(args, opt.args)
  end

  utils.run(ctest_command, config.env_script, env, args, config.cwd, config.runner, nil)
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
