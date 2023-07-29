local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local make_entry = require("telescope.make_entry")
local conf = require("telescope.config").values
local telescope = require("cmake-tools.telescope")

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
      local src = telescope.get_cmake_files()
      for _, v in ipairs(telescope.get_source_files()) do
        table.insert(src, v)
      end
      return src
    end),
    cmake_files = create_picker("CMake - CMake Files", telescope.get_cmake_files),
    cmake_sources = create_picker("CMake - Source Files", telescope.get_source_files),
  },
})
