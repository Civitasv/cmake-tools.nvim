local has_dap, dap = pcall(require, "dap")
local dap_repl_open = nil

if has_dap
then
  dap_repl_open = dap.repl.open
end

local const = {
  cmake_command = "/usr/bin/cmake",
  cmake_build_directory = "",
  cmake_build_directory_prefix = "cmake_build_", -- when cmake_build_directory is "", this option will be activated
  cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
  cmake_build_options = {},
  cmake_console_position = "belowright", -- "bottom", "top"
  cmake_console_size = 10,
  cmake_show_console = "always", -- "always", "only_on_error"
  cmake_focus_on_console = false, -- true, false
  cmake_dap_configuration = { name = "cpp", type = "codelldb", request = "launch" },
  cmake_dap_open_command = dap_repl_open,
  cmake_variants_message = {
    short = { show = true },
    long = { show = true, max_length = 40 }
  }
}

return const
