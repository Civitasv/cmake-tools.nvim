# CMake Tools

<p align="center"><img src="./docs/images/demo.gif"/></p>

<h2 align="center">🔥CMake Tools for Neovim which is written in pure lua.🔥</h2>

> CREDIT:
>
> It is a fork from the brilliant [neovim-cmake](https://github.com/Shatur/neovim-cmake). Since I change too much of it, So I make a new repo to develop it.

The goal of this plugin is to offer a comprehensive, convenient, and powerful workflow for CMake-based projects in Neovim, comparable to the functionality provided by [vscode-cmake-tools](https://github.com/microsoft/vscode-cmake-tools) for Visual Studio Code.

## :sparkles: Installation

- Require Neovim (>=0.7).
- Require [plenary](https://github.com/nvim-lua/plenary.nvim).
- Install it like any other Neovim plugin.
  - [lazy.nvim](https://github.com/folke/lazy.nvim): `return { 'Civitasv/cmake-tools.nvim' }`
  - [packer.nvim](https://github.com/wbthomason/packer.nvim): `use 'Civitasv/cmake-tools.nvim'`
  - [vim-plug](https://github.com/junegunn/vim-plug): `Plug 'Civitasv/cmake-tools.nvim'`

## :balloon: Configuration

```lua
require("cmake-tools").setup {
  cmake_command = "cmake", -- this is used to specify cmake command path
  cmake_regenerate_on_save = true, -- auto generate when save CMakeLists.txt
  cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" }, -- this will be passed when invoke `CMakeGenerate`
  cmake_build_options = {}, -- this will be passed when invoke `CMakeBuild`
  cmake_build_directory = "", -- this is used to specify generate directory for cmake
  cmake_build_directory_prefix = "cmake_build_", -- when cmake_build_directory is set to "", this option will be activated
  cmake_soft_link_compile_commands = true, -- this will automatically make a soft link from compile commands file to project root dir
  cmake_compile_commands_from_lsp = false, -- this will automatically set compile commands file location using lsp, to use it, please set `cmake_soft_link_compile_commands` to false
  cmake_kits_path = nil, -- this is used to specify global cmake kits path, see CMakeKits for detailed usage
  cmake_variants_message = {
    short = { show = true }, -- whether to show short message
    long = { show = true, max_length = 40 } -- whether to show long message
  },
  cmake_dap_configuration = { -- debug settings for cmake
    name = "cpp",
    type = "codelldb",
    request = "launch",
    stopOnEntry = false,
    runInTerminal = true,
    console = "integratedTerminal",
  },
  cmake_always_use_terminal = false, -- if true, use terminal for generate, build, clean, install, run, etc, except for debug, else only use terminal for run, use quickfix for others
  cmake_quickfix_opts = { -- quickfix settings for cmake, quickfix will be used when `cmake_always_use_terminal` is false
    show = "always", -- "always", "only_on_error"
    position = "belowright", -- "bottom", "top"
    size = 10,
  },
  cmake_terminal_opts = { -- terminal settings for cmake, terminal will be used for run when `cmake_always_use_terminal` is false or true, will be used for all tasks except for debug when `cmake_always_use_terminal` is true
    name = "Main Terminal",
    prefix_name = "[CMakeTools]: ", -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
    split_direction = "horizontal", -- "horizontal", "vertical"
    split_size = 11,

    -- Window handling
    single_terminal_per_instance = true, -- Single viewport, multiple windows
    single_terminal_per_tab = true, -- Single viewport per tab
    keep_terminal_static_location = true, -- Static location of the viewport if avialable

    -- Running Tasks
    start_insert_in_launch_task = false, -- If you want to enter terminal with :startinsert upon using :CMakeRun
    start_insert_in_other_tasks = false, -- If you want to enter terminal with :startinsert upon launching all other cmake tasks in the terminal. Generally set as false
    focus_on_main_terminal = false, -- Focus on cmake terminal when cmake task is launched. Only used if cmake_always_use_terminal is true.
    focus_on_launch_terminal = false, -- Focus on cmake launch terminal when executable target in launched.
  }
}
```

Generally, the default is enough.

## :magic_wand: Docs

1. [basic usage](./docs/basic_usage.md)
2. [settings](./docs/settings.md)
3. [all commands](./docs/all_commands.md)
4. [cmake presets](./docs/cmake_presets.md)
5. [cmake kits](./docs/cmake_kits.md)
6. [cmake variants](./docs/cmake_variants.md)
7. [sessions](./docs/sessions.md)
8. [how to](./docs/howto.md)

## :muscle: Contribute

If you want to implement a missing feature, [consider making a PR](./docs/contribute.md).

## LICENCE

[GPL-3.0 License](https://www.gnu.org/licenses/gpl-3.0.html) © Civitasv

## Reference

1. [vscode-cmake-tools](https://github.com/microsoft/vscode-cmake-tools) is an amazing plugin for CMake-based project in Visual Studio Code, [MIT LICENSE](https://github.com/microsoft/vscode-cmake-tools/blob/main/LICENSE.txt).
2. Inspired by [neovim-cmake](https://github.com/Shatur/neovim-cmake) which is made by [Shatur](https://github.com/Shatur), [GPL-3.0 license](https://github.com/Shatur/neovim-cmake/blob/master/COPYING).
3. [plenary](https://github.com/nvim-lua/plenary.nvim), [MIT LICENSE](https://github.com/nvim-lua/plenary.nvim/blob/master/LICENSE).
