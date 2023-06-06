local const = {
  cmake_command = "cmake", -- cmake command path
  cmake_regenerate_on_save = true,
  cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" }, -- it will be activated when invoke `cmake.generate`
  cmake_build_options = {}, -- it will be activated when invoke `cmake.build`
  cmake_build_directory = "", -- cmake generate directory
  cmake_build_directory_prefix = "cmake_build_", -- when cmake_build_directory is "", this option will be activated
  cmake_soft_link_compile_commands = true, -- soft compile commands file to project root dir
  cmake_compile_commands_from_lsp = false, -- automatically set compile commands location using lsp
  cmake_kits_path = nil,
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
  cmake_always_use_terminal = false, -- if true, use terminal for generate, build, clean, install, run, else only use terminal for run, use quickfix for others
  cmake_quickfix_opts = {
    show = "always", -- "always", "only_on_error"
    position = "belowright", -- "bottom", "top"
    size = 10,
  },
  cmake_terminal_opts = {
    name = "Main Terminal",
    prefix_name = "[CMakeTools]: ", -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
    split_direction = "horizontal", -- "horizontal", "vertical"
    split_size = 11,

    -- Window handling
    single_terminal_per_instance = true, -- Single viewport, multiple windows
    single_terminal_per_tab = true, -- Single viewport per tab
    keep_terminal_static_location = true, -- Static location of the viewport if avialable

    -- Running Tasks
    launch_task_in_a_child_process = false, -- Set this to true to make sure that you do not execute multiple cmake tasks at-a-time and keep sending data to the terminal
    launch_executable_in_a_child_process = false, -- Same as above, but you will rarely ever need this
    start_insert_in_launch_task = false, -- If you want to enter terminal with :startinsert upon using :CMakeRun
    start_insert_in_other_tasks = false, -- If you want to enter terminal with :startinsert upon launching all other cmake tasks in the terminal. Generally set as false
    focus_on_main_terminal = false, -- Focus on cmake terminal when cmake task is launched. Only used if cmake_always_use_terminal is true.
    focus_on_launch_terminal = false, -- Focus on cmake launch terminal when executable target in launched.
  }
}

return const
