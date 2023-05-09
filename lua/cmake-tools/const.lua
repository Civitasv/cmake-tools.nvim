local const = {
  cmake_build_directory = "",                                       -- cmake generate directory
  cmake_build_directory_prefix = "cmake_build_",                    -- when cmake_build_directory is "", this option will be activated
  cmake_command = "cmake",                                          -- cmake command path
  cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" }, -- it will be activated when invoke `cmake.generate`
  cmake_soft_link_compile_commands = true,
  cmake_compile_commands_from_preset = false,
  cmake_build_options = {},              -- it will be activated when invoke `cmake.build`
  cmake_console_position = "belowright", -- "bottom", "top"
  cmake_console_size = 10,
  cmake_show_console = "always",         -- "always", "only_on_error"
  cmake_variants_message = {
    short = { show = true },
    long = { show = true, max_length = 40 }
  },
  cmake_dap_configuration = {
    name = "cpp",
    type = "codelldb",
    request = "launch",
    stopOnEntry = false,
    runInTerminal = true,
    console = "integratedTerminal",
  },
}

return const
