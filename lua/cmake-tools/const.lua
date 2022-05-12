local const = {
  cmake_command = "cmake",
  cmake_build_directory = "build",
  cmake_build_type = "Debug",
  cmake_generate_options = { "-D", "CMAKE_EXPORT_COMPILE_COMMANDS=1" },
  cmake_build_options = {},
  cmake_console_position = "belowright", -- "bottom", "top"
  cmake_console_size = 10,
  cmake_show_console = "always", -- "always", "only_on_error"
  cmake_focus_on_console = false, -- true, false
  cmake_dap_configuration = { name = "cpp", type = "codelldb", request = "launch" },
  cmake_dap_open_command = require("dap").repl.open,
}

return const
