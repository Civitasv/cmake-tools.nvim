local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local make_entry = require("telescope.make_entry")
local conf = require("telescope.config").values
local file_picker = require("cmake-tools.file_picker")

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
      local src = file_picker.get_cmake_files()
      for _, v in ipairs(file_picker.get_source_files()) do
        table.insert(src, v)
      end
      return src
    end),
    cmake_files = create_picker("CMake - CMake Files", file_picker.get_cmake_files),
    sources = create_picker("CMake - Source Files", file_picker.get_source_files),
  },
})
