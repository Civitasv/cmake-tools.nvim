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

On every platform (Linux, macOS, Windows, WSL, BSD) it saves one session file
per project to:

```lua
local session_dir = vim.fn.stdpath("data") .. "/cmake_tools_nvim/"
```

Run `:echo stdpath("data")` to see the resolved location, e.g.
`~/.local/share/nvim` on Linux or `~/AppData/Local/nvim-data` on Windows.
