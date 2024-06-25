# How to

## Automatically set your compile_commands.json

There are two ways:

- Use softlink: firstly, you should set `cmake_soft_link_compile_commands` to true, then, this plugin will automatically make a softlink to compile_commands.json after generation.
- Use lsp: If you're using clangd or ccls configured through [lspconfig](https://github.com/neovim/nvim-lspconfig) you can
  set your compilation database directory to your active build directory by calling a hook in your on_new_config callback provided by lspconfig.

```lua
require('lspconfig').clangd.setup{
    on_new_config = function(new_config, new_cwd)
        local status, cmake = pcall(require, "cmake-tools")
        if status then
            cmake.clangd_on_new_config(new_config)
        end
    end,
}
```

## Mimic UI of cmake-tools toolbar in visual-studio-code

We provide a list of getters for you.

```lua
cmake.is_cmake_project() -- return if current project is a cmake project
cmake.has_cmake_preset() -- return if there exists cmake presets configuration
cmake.get_build_target() -- return current build target
cmake.get_build_target_path() -- reurn full path of current build target
cmake.get_launch_target() -- return current launch target
cmake.get_launch_target_path() -- return full path of current launch target
cmake.get_launch_args() -- return args used by current launch target
cmake.get_build_type() -- return current build type
cmake.get_kit() -- return current using kit
cmake.get_configure_preset() -- return current using configure preset
cmake.get_build_preset() -- return current using build preset
cmake.get_build_directory() -- return current using build directory
cmake.get_launch_targets() -- return all launch targets
cmake.get_build_targets() -- return all build targets
cmake.get_generate_options() -- return generate options used by cmake
cmake.get_build_options() -- return build options used by cmake
```

With these helper functions, I've mimic the UI using lualine.

<details>
  <summary>Full Configuration is as follows: (<i>click to expand</i>)</summary>
  <!-- have to be followed by an empty line! -->

```lua
return {
  "nvim-lualine/lualine.nvim", -- status line
  config = function()
    local lualine = require("lualine")

    local cmake = require("cmake-tools")

    -- you can find the icons from https://github.com/Civitasv/runvim/blob/master/lua/config/icons.lua
    local icons = require("config.icons")

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
      normal = {
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
      },
      nightfly = {
        bg       = "#011627",
        fg       = "#acb4c2",
        yellow   = "#ecc48d",
        cyan     = "#7fdbca",
        darkblue = "#82aaff",
        green    = "#21c7a8",
        orange   = "#e3d18a",
        violet   = "#a9a1e1",
        magenta  = "#ae81ff",
        blue     = "#82aaff ",
        red      = "#ff5874",
      },
      light = {
        bg       = "#f6f2ee",
        fg       = "#3d2b5a",
        yellow   = "#ac5402",
        cyan     = "#287980",
        darkblue = "#2848a9",
        green    = "#396847",
        orange   = "#a5222f",
        violet   = "#8452d5",
        magenta  = "#6e33ce",
        blue     = "#2848a9",
        red      = "#b3434e",
      },
      catppuccin_mocha = {
        bg       = "#1E1E2E",
        fg       = "#CDD6F4",
        yellow   = "#F9E2AF",
        cyan     = "#7fdbca",
        darkblue = "#89B4FA",
        green    = "#A6E3A1",
        orange   = "#e3d18a",
        violet   = "#a9a1e1",
        magenta  = "#ae81ff",
        blue     = "#89B4FA",
        red      = "#F38BA8",
      }
    }

    colors = colors.light;

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
  end
}
```

</details>

it looks like:

![lualine UI](./images/2023-06-06-22-02-06.png)

Calling `:lua RunPerf()` will then run `perf record --call-graph dwarf {target} {launch_args}`.

## Fix errors in quickfix list (Windows/msvc)

If the errors and warnings are not being parsed correctly from the build output then navigation via the quickfix list will not function. It is possible that additional errorformats (`:h errorformat`) are required. Adding the following to your init.lua, or other suitable lua file, will enable quickfix support for MSBuild and cl.exe:
```lua
-- MSBuild:
vim.opt.errorformat:append([[\ %#%f(%l\,%c):\ %m]])
-- cl.exe:
vim.opt.errorformat:append([[\ %#%f(%l)\ :\ %#%t%[A-z]%#\ %m]])
```

## Experimental: Additional command runners (executors)

By default, this plugin uses quickfix console for generate, build, clean, install, and others about cmake, and only uses terminal for run specific target.
But if you want you can use specific executors.

### Use overseer

If you want to use overseer to run cmake operations, set `cmake_executor={name="overseer", opts={}}` where opts is the overseer specific arguments as presented in the readme.

### Always use terminal

If you want to always use terminal(for example, you want to record all commands and corresponding output), there is a way. You need set `cmake_executor` to `{name="terminal"}`, then, all commands will be executed in the terminal.

---

## Integrations

### NvimTree

For users that are using nvim-tree, to keep the size of terminal constant, you should add the following configuration for nvim-tree.

```lua
require("nvim-tree").setup {
    --
    view = {
      preserve_window_proportions = true,
      ---
    },
}
```

### Terminal type buffer filtering (HardTime.nvim)

When focused on a terminal buffer (not for quickfix-lists, except run terminal), you can check the filetype with `:set ft`. It should display `cmake_tools_terminal`.
This can be useful for users of plugins like [hardtime.nvim](https://github.com/m4xshen/hardtime.nvim) you can specify the CMake terminal buffers like:
(Scrolling becomes much easier without having to resort to vim motions like `CTRL H` + `zz` or `CTRL L` + `zz`) in order to scroll the buffer

```lua
{
    "m4xshen/hardtime.nvim",
    event = "VeryLazy",
    opts = { disabled_filetypes = { "cmake_tools_terminal" },
    }
},
```

### Telescope

`cmake-tools` provides Telescope integration.

`Telescope cmake_tools` shows files associated with the cmake project. Ignoring some files such as objects files or cmake rules. (Combines both `sources` and `cmake_files`).

`Telescope cmake_tools sources` shows only source files and files directly added to targets.

`Telescope cmake_tools cmake_files` shows files associated with the cmake-model (CMakeLists files and similar).

Additionaly `CMakeShowTargetFiles` can be used to only show files associated with a specific target.
