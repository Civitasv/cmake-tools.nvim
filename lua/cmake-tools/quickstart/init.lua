local cmake = require("cmake-tools")
local etlua = require("cmake-tools.quickstart.etlua")
local locals = {
  project_version = "0.0.1",
  project_name = "project",
  type = "exec",
  language = "cpp",
}
local types = { executable = "exec", library = "lib" }
local types_list = {}
local languages = { Cpp = "cpp", C = "c" }
local languages_list = {}
for k, _ in pairs(types) do
  table.insert(types_list, k)
end
for k, _ in pairs(languages) do
  table.insert(languages_list, k)
end

local base_path = string.sub(debug.getinfo(1).source, 2, string.len("/init.lua") * -1)
-- local base_path = debug.getinfo(2, "S").source:sub(2)
local generate_cmakelists_file = function()
  local file_name = base_path
    .. "templates/"
    .. locals.type
    .. "/"
    .. locals.language
    .. "/CMakeLists.txt.etlua"
  local file = io.open(file_name, "r")
  if not file then
    error("could not find file: " .. file_name)
    return
  end
  local template = etlua.compile(file:read("*a"))
  local main_file_path = vim.loop.cwd() .. "/CMakeLists.txt"
  file = io.open(main_file_path, "w")
  if not file then
    error("could not create the file: " .. main_file_path)
  end
  file:write(template(locals))
  file:close()
end

local generate_main_file = function()
  local file_name = base_path
    .. "templates/"
    .. locals.type
    .. "/"
    .. locals.language
    .. "/main.etlua"
  local file = io.open(file_name, "r")
  if not file then
    error("could not find file: " .. file_name)
    return
  end
  local template = etlua.compile(file:read("*a"))
  local main_file_name = "main"
  if locals.type == "lib" then
    main_file_name = locals.project_name
  end
  local main_file_path = vim.loop.cwd() .. "/" .. main_file_name .. "." .. locals.language

  file = io.open(main_file_path, "w")
  if not file then
    error("could not create the file: " .. main_file_path)
  end
  file:write(template(locals))
  file:close()
end

local choose_language_type = function()
  vim.ui.select(
    languages_list,
    { prompt = "Select language" },
    vim.schedule_wrap(function(_, idx)
      if not idx then
        return
      end
      locals["language"] = languages[languages_list[idx]]
      generate_cmakelists_file()
      generate_main_file()
    end)
  )
end

local choose_template_type = function()
  vim.ui.select(
    types_list,
    { prompt = "Select project type" },
    vim.schedule_wrap(function(_, idx)
      if not idx then
        return
      end
      locals.type = types[types_list[idx]]
      choose_language_type()
    end)
  )
end

---comment
---@param _ any params passed from calling command from vim user command
local quick_start = function(_)
  if cmake.is_cmake_project() then
    print("Project already contains CMakeLists.txt")
    return
  end
  vim.ui.input(
    { prompt = "Enter the name of the project" },
    vim.schedule_wrap(function(input)
      if not input then
        return
      end
      locals.project_name = input
      choose_template_type()
    end)
  )
end
-- TODO: possible handling of windows paths
return { quick_start = quick_start }
