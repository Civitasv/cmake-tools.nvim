# Session

cmake-tools.nvim now supports session.

It can autoload settings for Config:

```lua
return {
  build_directory = "",
  base_settings = {
    build_dir = "",
    build_options = { "-j4" },
    env = {},
    generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
    working_dir = "${dir.binary}"
  },
  build_target = "",
  build_type = "Debug",
  cwd = "",
  env_script = " ",
  kit = "Clang 14.0.3 arm64-apple-darwin22.5.0",
  target_settings = {},
  variant = {
    buildType = "Debug"
  }
}
```

For Linux, macOS, Windows, WSL, it will save cache files to:

```lua
local session = {
  dir = {
    unix = vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/",
    mac = vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/",
    win = vim.fn.expand("~") .. "/AppData/Local/cmake_tools_nvim/"
  }
}
```

per project.
