local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local make_entry = require("telescope.make_entry")
local conf = require("telescope.config").values
local Types = require("cmake-tools.types")

local function get_files_from_target(target)
  local cmake = require("cmake-tools")
  local config = cmake.get_config()

  local info = config:get_code_model_target_info(target)

  local files = {}

  for _, v in ipairs(info.sourceGroups) do
    -- ignore cerain files such as .o/.obj files and cmake rules

    if v.name == "CMake Rules" then
      goto skip
    end

    if v.name == "Object Libraries" then
      goto skip
    end

    for _, srcIdx in ipairs(v.sourceIndexes) do
      table.insert(files, info.sources[srcIdx + 1].path) -- +1 because lua is 1 indexed
    end

    ::skip::
  end

  return files
end

local function get_source_files()
  local files = {}
  local cmake = require("cmake-tools")
  local config = cmake.get_config()

  local targets = config:get_codemodel_targets()

  if targets.code ~= Types.SUCCESS then
    return files
  end

  -- vim.notify(vim.inspect(targets))
  for _, target in pairs(targets.data) do
    -- vim.notify(vim.inspect(v))
    -- if v.name then

    -- files = vim.tbl_extend("keep", files, get_files_from_target(v))
    for _, v in pairs(get_files_from_target(target)) do
      files[v] = 1
    end
    -- end
    -- break
  end

  -- convert set to list
  local result = {}
  for k, _ in pairs(files) do
    table.insert(result, k)
  end
  return result
end

local function get_cmake_files()
  local files = {}
  local cmake = require("cmake-tools")
  local config = cmake.get_config()

  local cmakeFiles = config:get_cmakeFiles()

  if cmakeFiles.code ~= Types.SUCCESS then
    return files
  end

  for _, v in pairs(cmakeFiles.data) do
    if v.isCMake and v.isCMake == true then
      -- ignore standard cmake files such as "CMakeCommonLanguageInclude"
      goto skip
    end

    if v.isGenerated and v.isGenerated == true then
      -- ignore generated files such as "CMakeCXXCompiler"
      goto skip
    end

    if v.path then
      -- use files as keys to prevent duplicates (there can be quite a few when using package managers)
      files[v.path] = 1
    end

    ::skip::
  end

  -- convert set to list
  local result = {}
  for k, _ in pairs(files) do
    table.insert(result, k)
  end

  return result
end

local function create_picker(title, fn)
  return function(opts)
    opts = opts or {}
    opts.cwd = opts.cwd or vim.fn.getcwd()

    pickers
      .new(opts, {
        prompt_title = title,
        finder = finders.new_table({
          results = fn(),
          entry_maker = make_entry.gen_from_file(opts),
        }),
        sorter = conf.file_sorter(opts),
        previewer = conf.file_previewer(opts),
      })
      :find()
  end
end

return require("telescope").register_extension({
  exports = {
    cmake_tools = create_picker("CMake - Source Files", function()
      local src = get_cmake_files()
      for _, v in ipairs(get_source_files()) do
        table.insert(src, v)
      end
      return src
    end),
    cmake_files = create_picker("CMake - CMake Files", get_cmake_files),
    cmake_sources = create_picker("CMake - Source Files", get_source_files),
  },
})
