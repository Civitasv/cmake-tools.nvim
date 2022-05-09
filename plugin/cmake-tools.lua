--- The cmake-tools plugin for neovim v0.7.0+.
-- This plugin is intended to support cmake integration in neovim.

local cmake_tools = require("cmake-tools")

---------------- Commands ------------------

--- CMake
vim.api.nvim_create_user_command(
  "CMake", -- name
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
    desc = "CMake build",
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

--- CMake debug
vim.api.nvim_create_user_command(
  "CMakeDebug", -- name
  cmake_tools.debug, -- command
  { -- opts
    nargs = "*",
    desc = "CMake debug",
  }
)

--- CMake select build type
vim.api.nvim_create_user_command(
  "CMakeSelectBuildType", -- name
  cmake_tools.select_build_type, -- command
  { -- opts
    nargs = 0,
    desc = "CMake select build type",
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

