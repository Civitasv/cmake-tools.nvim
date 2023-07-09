# Session

cmake-tools.nvim now supports session.

It can autoload settings for Config:

```lua
local Config = {
  build_directory = nil,
  query_directory = nil,
  reply_directory = nil,
  generate_options = {},
  build_options = {},
  build_type = nil,
  build_target = nil,
  launch_target = nil,
  launch_args = {},
  kit = nil,
  configure_preset = nil,
  build_preset = nil,
}
```

For Linux, MacOS, Windows, WSL, it will save cache files to:

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

