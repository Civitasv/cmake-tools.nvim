local Types = require("cmake-tools.types")
local log = require("cmake-tools.log")

local M = {}

function M.get_files_from_target(target)
  local cmake = require("cmake-tools")
  local config = cmake.get_config()

  local info = config:get_code_model_target_info(target)

  local files = {}

  if info.sourceGroups then
    for _, v in ipairs(info.sourceGroups) do
      -- ignore cerain files such as .o/.obj files and cmake rules
      if not (v.name == "CMake Rules" or v.name == "Object Libraries") and v.sourceIndexes then
        for _, srcIdx in ipairs(v.sourceIndexes) do
          table.insert(files, info.sources[srcIdx + 1].path) -- +1 because lua is 1 indexed
        end
      end
    end
  end

  return files
end

function M.get_source_files()
  local files = {}
  local cmake = require("cmake-tools")
  local config = cmake.get_config()

  local targets = config:get_codemodel_targets()

  if targets.code ~= Types.SUCCESS then
    return files
  end

  for _, target in pairs(targets.data) do
    for _, v in pairs(M.get_files_from_target(target)) do
      files[v] = 1
    end
  end

  -- convert set to list
  local result = {}
  for k, _ in pairs(files) do
    table.insert(result, k)
  end
  return result
end

function M.get_cmake_files()
  local files = {}
  local cmake = require("cmake-tools")
  local config = cmake.get_config()

  local cmakeFiles = config:get_cmake_files()

  if cmakeFiles.code ~= Types.SUCCESS then
    return files
  end

  for _, v in pairs(cmakeFiles.data) do
    -- ignore standard cmake files such as "CMakeCommonLanguageInclude"
    -- ignore generated files such as "CMakeCXXCompiler"
    if
      not ((v.isCMake and v.isCMake == true) or (v.isGenerated and v.isGenerated == true))
      and v.path
    then
      -- use files as keys to prevent duplicates (there can be quite a few when using package managers)
      files[v.path] = 1
    end
  end

  -- convert set to list
  local result = {}
  for k, _ in pairs(files) do
    table.insert(result, k)
  end

  return result
end

function M.show_target_files(target)
  local cmake = require("cmake-tools")
  local has_telescope, _ = pcall(require, "telescope")
  if not has_telescope then
    return
  end
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local make_entry = require("telescope.make_entry")
  local conf = require("telescope.config").values
  local config = cmake.get_config()

  log.info(vim.inspect(target))

  local targets = config:get_codemodel_targets()
  for _, v in pairs(targets.data) do
    if v.name == target then
      pickers
        .new({}, {
          prompt_title = target,
          finder = finders.new_table({
            results = M.get_files_from_target(v),
            entry_maker = make_entry.gen_from_file({}),
          }),
          sorter = conf.file_sorter({}),
          previewer = conf.file_previewer({}),
        })
        :find()
      return
    end
  end

  log.warn("Target not found in CodeModel")
end

return M
