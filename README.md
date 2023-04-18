# CMake Tools for Neovim

https://user-images.githubusercontent.com/37768049/211132987-c620fc47-d5a0-49e1-8e7d-5da9ac528428.mp4

> CREDIT:
>
> It is a fork from the brilliant [neovim-cmake](https://github.com/Shatur/neovim-cmake). Since I change too much of it, So I make a new repo to develop it.

🔥CMake Tools for Neovim written in pure lua that requires Neovim 0.7+.🔥

The goal of this plugin is to provide a full-featured, convenient, and powerfull workflow for CMake-based projects in Neovim, which just like [vscode-cmake-tools](https://github.com/microsoft/vscode-cmake-tools) for Visual Studio Code.

It uses [CMake file api](https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html) to generate CMake file structure.

It uses terminal to execute targets.

(optional) It uses [nvim-dap](https://github.com/mfussenegger/nvim-dap) to debug.

## Notable Features

### CMake Presets

CMake Presets is a "standard" way in cmake to share settings with other people.

Read more about CMake presets from [CMake docs](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#macro-expansion).

Attention: If `CMake[User]Presets.json` is provided, then `CMakeKits.json` or `CMakeVariants.[json|yaml]` won't have any effect.

### CMake Kits

CMake Kits define rules about how to build code. Typically, a kit can include:

- A set of compilers.
- A toolchain file.

Example:

```json
{
  "name": "My Compiler Kit",
  
  <!-- For windows if CMakeKits are used as there are default msvc compilers. Ignore if CMakeUserPrests are used. -->
  "generator":"Ninja", 
  
  "compilers": {
    "C": "/usr/bin/gcc",
    "CXX": "/usr/bin/g++",
    "Fortran": "/usr/bin/gfortran"
  }
}
```

Read more about cmake kits from [vscode-cmake-tools docs](https://github.com/microsoft/vscode-cmake-tools/blob/main/docs/kits.md).

**And currently some features are not implemented, see details at [TODO](#todo) section. PR is welcome!**

### CMake Variants

Thanks @toolcreator for supporting CMake Variants which raised by VsCode's CMake Tools.

CMake Variants is a concept of vscode-cmake-tools. It's used to group together and combine a common set of build options.

Read more about cmake variants from [vscode-cmake-tools docs](https://github.com/microsoft/vscode-cmake-tools/blob/main/docs/variants.md).

## Installation

- Require Neovim (>=0.7)
- Require [plenary](https://github.com/nvim-lua/plenary.nvim)
- Install it like any other Neovim plugin.
  - [packer.nvim](https://github.com/wbthomason/packer.nvim): `use 'Civitasv/cmake-tools.nvim'`
  - [vim-plug](https://github.com/junegunn/vim-plug): `Plug 'Civitasv/cmake-tools.nvim'`

## Usage

| Command                    | Description                                                                                                                                                                                                                                                                                                            |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CMakeGenerate\[!\]         | Generate native makefiles and workspaces that can be used next. Additional arguments will be passed to CMake. eg. Use `CMakeGenerate -G MinGW\ Makefiles` to specify another generator.                                                                                                                                |
| CMakeBuild                 | Build target, if not generate makefiles yet, it will automatically invoke `CMake`, if not select build target, it will automatically invoke `CMakeSelectBuildTarget` . Additional arguments will be passed to CMake.                                                                                                   |
| CMakeRun                   | Run launch target, if not generate makefiles yet, it will automatically invoke `CMakeGenerate`, if not select launch target, it will automatically invoke `CMakeSelectLaunchTarget`, if not built, it will automatically invoke `CMakeBuild`. Additional arguments will be passed to `CMakeGenerate` and `CMakeBuild`. |
| CMakeDebug                 | Use nvim-dap to debug launch target, works like CMakeRun                                                                                                                                                                                                                                                               |
| CMakeSelectBuildType       | Select build type, include "Debug", "Release", "RelWithDebInfo", "MinSizeRel" for default. cmake-tools.nvim also support cmake variants, when "cmake-variants.yaml" or "cmake-variants.json" is provided, it will read configuration from it                                                                           |
| CMakeSelectBuildTarget     | Select build target, include executable and library targets                                                                                                                                                                                                                                                            |
| CMakeSelectLaunchTarget    | Select launch target, only include executable targets                                                                                                                                                                                                                                                                  |
| CMakeSelectKit             | Select kit defined from CMakeKits.json                                                                                                                                                                                                                                                                                 |
| CMakeSelectConfigurePreset | Select configure preset, if CMake[User]Presets.json is provided                                                                                                                                                                                                                                                        |
| CMakeSelectBuildPreset     | Select build preset, if CMake[User]Presets.json is provided                                                                                                                                                                                                                                                            |                                          |
| CMakeOpen                  | Open CMake console                                                                                                                                                                                                                                                                                                     |
| CMakeClose                 | Close CMake console                                                                                                                                                                                                                                                                                                    |
| CMakeInstall               | Install CMake targets. Additional arguments will be passed to CMake.                                                                                                                                                                                                                                                   |
| CMakeClean                 | Clean target                                                                                                                                                                                                                                                                                                           |
| CMakeStop                  | Stop CMake process                                                                                                                                                                                                                                                                                                     |

## Setup

### Example

```lua
require("cmake-tools").setup {
  cmake_command = "cmake",
  cmake_build_directory = "",
  cmake_build_directory_prefix = "cmake_build_", -- when cmake_build_directory is "", this option will be activated
  cmake_generate_options = { "-D", "CMAKE_EXPORT_COMPILE_COMMANDS=1" },
  cmake_soft_link_compile_commands = true, -- if softlink compile commands json file
  cmake_build_options = {},
  cmake_console_size = 10, -- cmake output window height
  cmake_console_position = "belowright", -- "belowright", "aboveleft", ...
  cmake_show_console = "always", -- "always", "only_on_error"
  cmake_dap_configuration = { name = "cpp", type = "codelldb", request = "launch" }, -- dap configuration, optional
  cmake_variants_message = {
    short = { show = true },
    long = { show = true, max_length = 40 }
  }
}
```

The option `cmake_build_directory_prefix` will be activated only when `cmake_build_directory` is set to "".

See detailed user scenario from issue [#21](https://github.com/Civitasv/cmake-tools.nvim/issues/21).

## Using Multiple compilers

When using multiple compilers, you can specify this in your `CMakeKits.json` or `cmake-kits.json` file in your root directory. (See the Lualine config below to select the different comiplers from the GUI)

```json
[
  {
    "name": "Clang_14.0.6_x86_64-w64-windows-gnu",
    "generator":"Ninja",
    "compilers": {
      "C": "path/to/C/Compiler",
      "CXX": "path/to/CXX/Compiler"
    }
  },
  {
    "name": "Clang_15.0.7_x86_64-pc-windows-msvc",
    "generator":"Ninja",
    "compilers": {
      "C": "path/to/C/Compiler",
      "CXX": "path/to/CXX/Compiler"
    }
  },
  {
    "name": "VS 17 2022 amd64",
    "generator": "Visual Studio 17 2022",
    "host_architecture": "x64",
    "target_architecture": "x64",
    "compilers": {
      "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx64/x64/cl.exe",
      "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin//Hostx64/x64/cl.exe"
    }
  },
]
```

## MSVC Support without kit scans

Currently, we do not have an implementation of `vswhere` in lua for kit scanning. However, architectures and hosts and generators can be set as:

```json
{
  "name": "VS 17 2022 amd64",
  "generator": "Visual Studio 17 2022",
  "host_architecture": "x64",
  "target_architecture": "x64",
  "compilers": {
    "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx64/x64/cl.exe",
    "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin//Hostx64/x64/cl.exe"
    }
},

```

For MSVC config in their standard location within `Program Files` and `Program Files (x86)`. This is a workaround for till auto kit scanning is implemented. (**Tweaks to the compiler location might be necessary** if installation locations are different from what is shown below.)

All MSVC Config Examples:

<details>
<Summary>Click to expand MSVC Configs</Summary>

```json
{
  "name": "VS 16 2019 amd64",
  "generator": "Visual Studio 16 2019",
  "host_architecture": "x64",
  "target_architecture": "x64",
  "compilers": {
    "C": "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Tools/MSVC/14.29.30133/Hostx64/x64/cl.exe",
    "CXX": "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x64/cl.exe"
    }
},
{
  "name": "VS 16 2019 amd64_x86",
  "generator": "Visual Studio 16 2019",
  "host_architecture": "x64",
  "target_architecture": "win32",
  "compilers": {
    "C": "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Tools/MSVC/14.29.30133/Hostx64/x86/cl.exe",
    "CXX": "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x86/cl.exe"
    }
},
{
  "name": "VS 16 2019 x86",
  "generator": "Visual Studio 16 2019",
  "host_architecture": "x86",
  "target_architecture": "win32",
  "compilers": {
    "C": "C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.29.30133/bin/Hostx86/x86/cl.exe",
    "CXX": "C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.29.30133/bin/Hostx86/x86/cl.exe"
    }
},
{
  "name": "VS 16 2019 x86_amd64",
  "generator": "Visual Studio 16 2019",
  "host_architecture": "x86",
  "target_architecture": "x64",
  "compilers": {
    "C": "C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.29.30133/bin/Hostx86/x64/cl.exe",
    "CXX": "C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.29.30133/bin/Hostx86/x64/cl.exe"
    }
},
{
  "name": "VS 17 2022 amd64",
  "generator": "Visual Studio 17 2022",
  "host_architecture": "x64",
  "target_architecture": "x64",
  "compilers": {
    "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx64/x64/cl.exe",
    "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin//Hostx64/x64/cl.exe"
    }
},
{
  "name": "VS 17 2022 amd64_arm64",
  "generator": "Visual Studio 17 2022",
  "host_architecture": "x64",
  "target_architecture": "arm64",
  "compilers": {
    "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx64/x86/cl.exe",
    "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx64/x86/cl.exe"
    }
},
{
  "name": "VS 17 2022 amd64_x86",
  "generator": "Visual Studio 17 2022",
  "host_architecture": "x64",
  "target_architecture": "win32",
  "compilers": {
    "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx64/arm64/cl.exe",
    "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx64/arm64/cl.exe"
    }
},
{
  "name": "VS 17 2022 x86",
  "generator": "Visual Studio 17 2022",
  "host_architecture": "x86",
  "target_architecture": "win32",
  "compilers": {
    "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx86/x86/cl.exe",
    "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx86/x86/cl.exe"
    }
},
{
  "name": "VS 17 2022 x86_amd64",
  "generator": "Visual Studio 17 2022",
  "host_architecture": "x86",
  "target_architecture": "x64",
  "compilers": {
    "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx86/x64/cl.exe",
    "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx86/x64/cl.exe"
    }
},
{
  "name": "VS 17 2022 x86_arm64",
  "generator": "Visual Studio 17 2022",
  "host_architecture": "x86",
  "target_architecture": "arm64",
  "compilers": {
    "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx86/arm64/cl.exe",
    "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx86/arm64/cl.exe"
    }
}

```

</details>

## Windows : MinGw / GCC / Clang / Clang-cl support

Exmaples of clang, gcc, clang-cl, and gcc support in windows. **You must specify the generator.** For example:

```json
{
  "name": "Clang_14.0.6_x86_64-w64-windows-gnu",
  "generator":"Ninja",
  "compilers": {
    "C": "C:/mingw64/bin/clang.exe",
    "CXX": "C:/mingw64/bin/clang++.exe"
  }
},
{
  "name": "GCC_12.2.0_15.0.7_x86_64-windows-msvc",
  "generator":"MinGW Makefiles",
  "compilers": {
    "C": "C:/mingw64/bin/gcc.exe",
    "CXX": "C:/mingw64/bin/g++.exe"
  }
}

```
More MinGW/Ninja/GCC/Clang/Clang-cl Examples

<details>
<Summary>Click to expand More Examples</Summary>

```json
{
  "name": "Clang_14.0.6_x86_64-w64-windows-gnu",
  "generator":"Ninja",
  "compilers": {
    "C": "C:/mingw64/bin/clang.exe",
    "CXX": "C:/mingw64/bin/clang++.exe"
 }
},
{
  "name": "Clang-cl 14.0.6 x86_64-pc-windows-msvc",
  "generator":"Ninja",
  "compilers": {
    "C": "C:/mingw64/bin/clang-cl.exe",
    "CXX": "C:/mingw64/bin/clang-cl.exe"
  }
},
{
  "name": "Clang_15.0.7_x86_64-pc-windows-msvc",
  "generator":"Ninja",
  "compilers": {
    "C": "C:/Program Files/LLVM/bin/clang.exe",
    "CXX": "C:/Program Files/LLVM/bin/clang++.exe"
  }
},
{
  "name": "Clang_cl_15.0.7_x86_64-pc-windows-msvc",
  "generator":"Ninja",
  "compilers": {
    "C": "C:/Program Files/LLVM/bin/clang-cl.exe",
    "CXX": "C:/Program Files/LLVM/bin/clang-cl.exe"
  }
},
{
  "name": "GCC_12.2.0_15.0.7_x86_64-windows-msvc",
  "generator":"MinGW Makefiles",
  "compilers": {
    "C": "C:/mingw64/bin/gcc.exe",
    "CXX": "C:/mingw64/bin/g++.exe"
  }
},
{
  "name": "GCC_6.3.0_mingw32",
  "generator":"Ninja",
  "compilers": {
    "C": "C:/MinGW/bin/mingw32-gcc.exe",
    "CXX": "C:/MinGW/bin/mingw32-g++.exe"
  }
},
{
  "name": "GCC_8.3.0_x86_64-mingw32",
  "generator":"Ninja",
  "compilers": {
    "C": "C:/Strawberry/c/bin/gcc.exe",
    "CXX": "C:/Strawberry/c/bin/g++.exe"
  }
},
{
  "name": "GCC_9.2.0_x86_64-mingw32",
  "generator":"Ninja",
  "compilers": {
    "C": "C:/MinGW/bin/gcc.exe",
    "CXX": "C:/MinGW/bin/g++.exe"
  }
},

```

</details>

## How to make cmake-tools work exactly like it in exmaple video?

### lualine

I've added cmake-tools status in lualine, including `Build(when clicked, will invoke CMakeBuild)`, `Current Selected Build Target(when clicked, will invoke CMakeSelectBuildTarget)`, `Debug(when clicked, will invoke CMakeDebug)`, `Run(when clicked, will invoke CMakeRun)`, `Current Selected Launch Target(when clicked, will invoke CMakeSelectLaunchTarget)`.

When CMake[User]Presets.json is presented, also including `configure preset`, `build preset`.

Else, also including `variant(build type)`, `kit`.

<details>
  <summary>Full Configuration is as follows: (<i>click to expand</i>)</summary>
  <!-- have to be followed by an empty line! -->

```lua
local status_ok, lualine = pcall(require, "lualine")
if not status_ok then
  return
end

local cmake = require("cmake-tools")
local icons = require("user.icons")

-- Credited to [evil_lualine](https://github.com/nvim-lualine/lualine.nvim/blob/master/examples/evil_lualine.lua)
local conditions = {
  buffer_not_empty = function()
    return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
  end,
  hide_in_width = function()
    return vim.fn.winwidth(0) > 80
  end,
  check_git_workspace = function()
    local filepath = vim.fn.expand("%:p:h")
    local gitdir = vim.fn.finddir(".git", filepath .. ";")
    return gitdir and #gitdir > 0 and #gitdir < #filepath
  end,
}

local colors = {
  bg       = "#202328",
  fg       = "#bbc2cf",
  yellow   = "#ECBE7B",
  cyan     = "#008080",
  darkblue = "#081633",
  green    = "#98be65",
  orange   = "#FF8800",
  violet   = "#a9a1e1",
  magenta  = "#c678dd",
  blue     = "#51afef",
  red      = "#ec5f67",
}

local config = {
  options = {
    icons_enabled = true,
    component_separators = "",
    section_separators = "",
    disabled_filetypes = { "alpha", "dashboard", "Outline" },
    always_divide_middle = true,
    theme = {
      -- We are going to use lualine_c an lualine_x as left and
      -- right section. Both are highlighted by c theme .  So we
      -- are just setting default looks o statusline
      normal = { c = { fg = colors.fg, bg = colors.bg } },
      inactive = { c = { fg = colors.fg, bg = colors.bg } },
    },
  },
  sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_y = {},
    lualine_z = {},
    -- c for left
    lualine_c = {},
    -- x for right
    lualine_x = {},
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_y = {},
    lualine_z = {},
    lualine_c = { "filename" },
    lualine_x = { "location" },
  },
  tabline = {},
  extensions = {},
}

-- Inserts a component in lualine_c at left section
local function ins_left(component)
  table.insert(config.sections.lualine_c, component)
end

-- Inserts a component in lualine_x ot right section
local function ins_right(component)
  table.insert(config.sections.lualine_x, component)
end

ins_left {
  function()
    return icons.ui.Line
  end,
  color = { fg = colors.blue }, -- Sets highlighting of component
  padding = { left = 0, right = 1 }, -- We don't need space before this
}

ins_left {
  -- mode component
  function()
    return icons.ui.Evil
  end,
  color = function()
    -- auto change color according to neovims mode
    local mode_color = {
      n = colors.red,
      i = colors.green,
      v = colors.blue,
      [""] = colors.blue,
      V = colors.blue,
      c = colors.magenta,
      no = colors.red,
      s = colors.orange,
      S = colors.orange,
      [""] = colors.orange,
      ic = colors.yellow,
      R = colors.violet,
      Rv = colors.violet,
      cv = colors.red,
      ce = colors.red,
      r = colors.cyan,
      rm = colors.cyan,
      ["r?"] = colors.cyan,
      ["!"] = colors.red,
      t = colors.red,
    }
    return { fg = mode_color[vim.fn.mode()] }
  end,
  padding = { right = 1 },
}

ins_left {
  -- filesize component
  "filesize",
  cond = conditions.buffer_not_empty,
}

ins_left {
  "filename",
  cond = conditions.buffer_not_empty,
  color = { fg = colors.magenta, gui = "bold" },
}

ins_left { "location" }

ins_left {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  symbols = { error = icons.diagnostics.Error, warn = icons.diagnostics.Warning, info = icons.diagnostics.Information },
  diagnostics_color = {
    color_error = { fg = colors.red },
    color_warn = { fg = colors.yellow },
    color_info = { fg = colors.cyan },
  },
}

ins_left {
  function()
    local c_preset = cmake.get_configure_preset()
    return "CMake: [" .. (c_preset and c_preset or "X") .. "]"
  end,
  icon = icons.ui.Search,
  cond = function()
    return cmake.is_cmake_project() and cmake.has_cmake_preset()
  end,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeSelectConfigurePreset")
      end
    end
  end
}

ins_left {
  function()
    local type = cmake.get_build_type()
    return "CMake: [" .. (type and type or "") .. "]"
  end,
  icon = icons.ui.Search,
  cond = function()
    return cmake.is_cmake_project() and not cmake.has_cmake_preset()
  end,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeSelectBuildType")
      end
    end
  end
}

ins_left {
  function()
    local kit = cmake.get_kit()
    return "[" .. (kit and kit or "X") .. "]"
  end,
  icon = icons.ui.Pencil,
  cond = function()
    return cmake.is_cmake_project() and not cmake.has_cmake_preset()
  end,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeSelectKit")
      end
    end
  end
}

ins_left {
  function()
    return "Build"
  end,
  icon = icons.ui.Gear,
  cond = cmake.is_cmake_project,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeBuild")
      end
    end
  end
}

ins_left {
  function()
    local b_preset = cmake.get_build_preset()
    return "[" .. (b_preset and b_preset or "X") .. "]"
  end,
  icon = icons.ui.Search,
  cond = function()
    return cmake.is_cmake_project() and cmake.has_cmake_preset()
  end,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeSelectBuildPreset")
      end
    end
  end
}

ins_left {
  function()
    local b_target = cmake.get_build_target()
    return "[" .. (b_target and b_target or "X") .. "]"
  end,
  cond = cmake.is_cmake_project,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeSelectBuildTarget")
      end
    end
  end
}

ins_left {
  function()
    return icons.ui.Debug
  end,
  cond = cmake.is_cmake_project,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeDebug")
      end
    end
  end
}

ins_left {
  function()
    return icons.ui.Run
  end,
  cond = cmake.is_cmake_project,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeRun")
      end
    end
  end
}

ins_left {
  function()
    local l_target = cmake.get_launch_target()
    return "[" .. (l_target and l_target or "X") .. "]"
  end,
  cond = cmake.is_cmake_project,
  on_click = function(n, mouse)
    if (n == 1) then
      if (mouse == "l") then
        vim.cmd("CMakeSelectLaunchTarget")
      end
    end
  end
}

-- Insert mid section. You can make any number of sections in neovim :)
-- for lualine it's any number greater then 2
ins_left {
  function()
    return "%="
  end,
}

-- Add components to right sections
ins_right {
  "o:encoding", -- option component same as &encoding in viml
  fmt = string.upper, -- I'm not sure why it's upper case either ;)
  cond = conditions.hide_in_width,
  color = { fg = colors.green, gui = "bold" },
}

ins_right {
  "fileformat",
  fmt = string.upper,
  icons_enabled = false,
  color = { fg = colors.green, gui = "bold" },
}

ins_right {
  function()
    return vim.api.nvim_buf_get_option(0, "shiftwidth")
  end,
  icons_enabled = false,
  color = { fg = colors.green, gui = "bold" },
}

ins_right {
  "branch",
  icon = icons.git.Branch,
  color = { fg = colors.violet, gui = "bold" },
}

ins_right {
  "diff",
  -- Is it me or the symbol for modified us really weird
  symbols = { added = icons.git.Add, modified = icons.git.Mod, removed = icons.git.Remove },
  diff_color = {
    added = { fg = colors.green },
    modified = { fg = colors.orange },
    removed = { fg = colors.red },
  },
  cond = conditions.hide_in_width,
}

ins_right {
  function()
    local current_line = vim.fn.line(".")
    local total_lines = vim.fn.line("$")
    local chars = { "__", "▁▁", "▂▂", "▃▃", "▄▄", "▅▅", "▆▆", "▇▇", "██" }
    local line_ratio = current_line / total_lines
    local index = math.ceil(line_ratio * #chars)
    return chars[index]
  end,
  color = { fg = colors.orange, gui = "bold" }
}

ins_right {
  function()
    return "▊"
  end,
  color = { fg = colors.blue },
  padding = { left = 1 },
}

-- Now don't forget to initialize lualine
lualine.setup(config)
```

</details>

### Telescope Select UI

I use the [ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim) extension for telescope.

<details>

<summary>Configuration is as follows: (<i>click to expand</i>)</summary>

```lua
extensions = {
  ["ui-select"] = {
    require("telescope.themes").get_dropdown {
      -- even more opts
      width = 0.8,
      previewer = false,
      prompt_title = false,
      borderchars = {
        { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
        prompt = { "─", "│", " ", "│", "┌", "┐", "│", "│" },
        results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
        preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
      },
    }
  },
}
telescope.load_extension("ui-select")
```

</details>

## TODO

### CMake Presets

1. Support test preset.
2. Support package preset.
3. Support workflow preset.
4. Support condition.
5. Some macros not supported yet, see https://github.com/Civitasv/cmake-tools.nvim/blob/20fe7cad58703b579ec894ae150ead9ffd12cbc2/lua/cmake-tools/presets.lua#L142-L158.

### CMake Kit

0. Support Kits scan. <!-- 1. Support Visual Studio. -->
1. Support option `preferredGenerator`.
2. Support option `cmakeSettings`.
3. Support option `environmentSetupScript`.

### Others

1. Add help.txt

## LICENCE

[GPL-3.0 License](https://www.gnu.org/licenses/gpl-3.0.html) © Civitasv

## Reference

1. [vscode-cmake-tools](https://github.com/microsoft/vscode-cmake-tools) is an amazing plugin for CMake-based project in Visual Studio Code, [MIT LICENSE](https://github.com/microsoft/vscode-cmake-tools/blob/main/LICENSE.txt).
2. Inspired by [neovim-cmake](https://github.com/Shatur/neovim-cmake) which is made by [Shatur](https://github.com/Shatur), [GPL-3.0 license](https://github.com/Shatur/neovim-cmake/blob/master/COPYING).
3. [plenary](https://github.com/nvim-lua/plenary.nvim), [MIT LICENSE](https://github.com/nvim-lua/plenary.nvim/blob/master/LICENSE).
