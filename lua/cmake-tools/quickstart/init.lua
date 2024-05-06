local etlua = require("cmake-tools.quickstart.etlua")
local locals = {
  project_name = "",
  type = "exec",
}
local get_template_type = function()
  local types = { "exec", "lib" }
  vim.ui.select(
    types,
    { prompt = "select test to run" },
    vim.schedule_wrap(function(_, idx)
      if not idx then
        return
      end
      locals.type = types[idx]
      print(locals)
    end)
  )
end
local quick_start = function(opt)
  vim.ui.input(
    { prompt = "Enter the name of the project" },
    vim.schedule_wrap(function(input)
      if not input then
        return
      end
      locals.project_name = input
      get_template_type()
    end)
  )
end

local generate = function()
  local file = io.open("templates/exec/cxx/CMakeLists.txt.etlua", "r")
  local template = etlua.compile(file:read("*a"))
  file:close()
  print(template({
    project_name = "leafo",
    project_version = "0.1.0",
  }))
end
return { quick_start = quick_start }
