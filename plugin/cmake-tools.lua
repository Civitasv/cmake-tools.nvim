--- The cmake-tools plugin for neovim v0.7.0+.
-- This plugin is intended to support cmake integration in neovim.

local cmake_tools = require("cmake-tools")
local has_nvim_dap, _ = pcall(require, "dap")

---------------- Commands ------------------

--- CMake
vim.api.nvim_create_user_command(
  "CMakeGenerate", -- name
  cmake_tools.generate, -- command
  { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake configure",
  }
)

--- CMake clean
vim.api.nvim_create_user_command(
  "CMakeClean", -- name
  cmake_tools.clean, -- command
  { -- opts
    nargs = 0,
    desc = "Clean CMake result",
  }
)

--- CMake build
vim.api.nvim_create_user_command(
  "CMakeBuild", -- name
  cmake_tools.build, -- command
  { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake build",
  }
)

--- CMake quick build
vim.api.nvim_create_user_command(
  "CMakeQuickBuild", -- name
  cmake_tools.quick_build, -- command
  { -- opts
    nargs = "?",
    desc = "CMake quick build",
  }
)

--- CMake install
vim.api.nvim_create_user_command(
  "CMakeInstall", -- name
  cmake_tools.install, -- command
  { -- opts
    nargs = "*",
    desc = "CMake install",
  }
)
--- CMake stop
vim.api.nvim_create_user_command(
  "CMakeStop", -- name
  cmake_tools.stop, -- command
  { -- opts
    desc = "CMake stop",
  }
)

--- CMake close
vim.api.nvim_create_user_command(
  "CMakeClose", -- name
  cmake_tools.close, -- command
  { -- opts
    desc = "Close CMake quickfix window",
  }
)

--- CMake open
vim.api.nvim_create_user_command(
  "CMakeOpen", -- name
  cmake_tools.open, -- command
  { -- opts
    desc = "Open CMake quickfix window",
  }
)

--- CMake run
vim.api.nvim_create_user_command(
  "CMakeRun", -- name
  cmake_tools.run, -- command
  { -- opts
    nargs = "*",
    desc = "CMake run",
  }
)

--- CMake quick run
vim.api.nvim_create_user_command(
  "CMakeQuickRun", -- name
  cmake_tools.quick_run, -- command
  { -- opts
    nargs = "*",
    desc = "CMake quick run",
  }
)

--- CMake launch args
vim.api.nvim_create_user_command(
  "CMakeLaunchArgs", -- name
  cmake_tools.launch_args, -- command
  { -- opts
    nargs = "*",
    desc = "CMake launch args",
  }
)

if has_nvim_dap then
  --- CMake debug
  vim.api.nvim_create_user_command(
    "CMakeDebug", -- name
    cmake_tools.debug, -- command
    { -- opts
      nargs = "*",
      desc = "CMake debug",
    }
  )

  --- CMake quick debug
  vim.api.nvim_create_user_command(
    "CMakeQuickDebug", -- name
    cmake_tools.quick_debug, -- command
    { -- opts
      nargs = "*",
      desc = "CMake quick debug",
    }
  )
end

--- CMake select build type
vim.api.nvim_create_user_command(
  "CMakeSelectBuildType", -- name
  cmake_tools.select_build_type, -- command
  { -- opts
    nargs = 0,
    desc = "CMake select build type",
  }
)

--- CMake select kit
vim.api.nvim_create_user_command(
  "CMakeSelectKit", -- name
  cmake_tools.select_kit, -- command
  { -- opts
    nargs = 0,
    desc = "CMake select cmake kit",
  }
)

--- CMake select configure preset
vim.api.nvim_create_user_command(
  "CMakeSelectConfigurePreset", -- name
  cmake_tools.select_configure_preset, -- command
  { -- opts
    nargs = 0,
    desc = "CMake select cmake configure preset",
  }
)

--- CMake select build preset
vim.api.nvim_create_user_command(
  "CMakeSelectBuildPreset", -- name
  cmake_tools.select_build_preset, -- command
  { -- opts
    nargs = 0,
    desc = "CMake select cmake kit",
  }
)
--- CMake select build target
vim.api.nvim_create_user_command(
  "CMakeSelectBuildTarget", -- name
  cmake_tools.select_build_target, -- command
  { -- opts
    nargs = 0,
    desc = "CMake select build target",
  }
)

--- CMake select launch target
vim.api.nvim_create_user_command(
  "CMakeSelectLaunchTarget", -- name
  cmake_tools.select_launch_target, -- command
  { -- opts
    nargs = 0,
    desc = "CMake select launch target",
  }
)

--- CMake quick run
vim.api.nvim_create_user_command(
  "CMakeShowTargetFiles", -- name
  cmake_tools.show_target_files, -- command
  { -- opts
    nargs = "*",
    desc = "CMake show cmake model files or target",
  }
)
