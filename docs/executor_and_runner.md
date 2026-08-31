# Executor And Runner

This plugin splits the cmake process to two parts, one for generating libraries and executable, one for executing the executable programs.

- For the former, we use *Executor*, including toggleterm, overseer.nvim, quickfix, and terminal.
- For the latter, we use *Runner*, also including toggleterm, overseer.nvim, quickfix, and terminal.

The *Executor* runs `CMakeGenerate`, `CMakeBuild`, `CMakeQuickBuild`, `CMakeClean` and
`CMakeInstall`, the *Runner* runs `CMakeRun`, `CMakeQuickRun` and the ctest commands. Both
are configured separately, so you can build into the quickfix list and run your program in
a terminal, which is what the defaults do.

## Configuration

```lua
require("cmake-tools").setup {
  cmake_executor = {
    name = "quickfix", -- the backend to use, this is the default
    opts = {}, -- options for that backend, merged over its `default_opts` entry
    default_opts = { ... }, -- the defaults of every backend, see the README
  },
  cmake_runner = {
    name = "terminal", -- the backend to use, this is the default
    opts = {},
    default_opts = { ... },
  },
}
```

`opts` is merged over `default_opts[name]` during `setup`, so you only need to list what
you want to change. Only the options of the selected backend are used, and the selection
itself cannot be changed at runtime.

Use `CMakeOpenExecutor`, `CMakeCloseExecutor` and `CMakeStopExecutor`, and the `...Runner`
variants, to control the window of the current backend.

## Which backend to choose

| | needs | terminal for the process | reports progress | exit code | `cmake_environment_setup_script` |
| --- | --- | --- | --- | --- | --- |
| `quickfix` | - | no | yes | yes | no |
| `terminal` | - | yes | no | yes | yes |
| `toggleterm` | [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) | yes | yes | yes | yes |
| `overseer` | [overseer.nvim](https://github.com/stevearc/overseer.nvim) | depends on the strategy | yes | yes | no |
| `vimux` | [vimux](https://github.com/preservim/vimux) | yes, a tmux pane | no | no | no |

- *terminal for the process*: a program that reads from stdin only works with those,
  `quickfix` runs the command as a plain job and does not forward your input to it.
- *reports progress*: whether the output is handed back to the plugin, which is what feeds
  the `[ 42%]` progress notifications while a build runs.
- *exit code*: vimux cannot observe the process and always reports success. The `terminal`
  backend appends a snippet that writes the real exit code to a temporary file.
- *environment setup script*: quickfix runs the command without a shell and cannot source
  it, for overseer it is disabled, see
  [#158](https://github.com/Civitasv/cmake-tools.nvim/issues/158) and
  [#159](https://github.com/Civitasv/cmake-tools.nvim/issues/159).

## Quickfix

The default executor. It runs the command as a job and appends every line to the quickfix
list, so build errors are navigable with `:cnext`.

```lua
opts = {
  show = "always", -- "always" | "only_on_error"
  position = "belowright", -- where to open the quickfix window
  size = 10, -- height of the quickfix window
  encoding = "utf-8", -- if it is not "utf-8", the output is converted with `vim.fn.iconv`
  auto_close_when_success = true, -- close the quickfix window when the command succeeded
},
```

## Terminal

The default runner. It reuses one terminal buffer, named `prefix_name .. name`, and sends
the command to it.

```lua
opts = {
  name = "Main Terminal",
  prefix_name = "[CMakeTools]: ", -- must be unique, the terminal is found again by this prefix
  split_direction = "horizontal", -- "horizontal" | "vertical"
  split_size = 11,

  -- Window handling
  single_terminal_per_instance = true, -- one terminal for the whole neovim instance
  single_terminal_per_tab = true, -- one terminal per tab
  keep_terminal_static_location = true, -- keep the terminal where it is
  auto_resize = true, -- resize the terminal if it already exists

  -- Running Tasks
  start_insert = false, -- enter insert mode when the command is sent
  focus = false, -- focus the terminal when the command is sent
  do_not_add_newline = false, -- do not hit enter, so you can review or edit the command first
  use_shell_alias = false, -- runner only, hide the command wrapper behind a shell alias,
                           -- so that you only see the output of your program (not on Windows)
},
```

The command is sent to a shell, which is why this backend supports
`cmake_environment_setup_script` and programs that expect input.

## Toggleterm

```lua
opts = {
  direction = "float", -- "vertical" | "horizontal" | "tab" | "float"
  close_on_exit = false, -- close the terminal when the process exits
  auto_scroll = true, -- scroll on new output
  scroll_on_error = false, -- scroll to the bottom on error
  auto_focus = true, -- focus the terminal when it is opened
  focus_on_error = false, -- focus it when the command failed
  singleton = true, -- close an already opened cmake terminal before opening a new one
},
```

## Overseer

The `overseer` executor and runner create a task with `overseer.new_task`, everything
you put in `new_task_opts` is passed to it unchanged.

```lua
opts = {
  new_task_opts = {
    strategy = nil, -- leave unset to use the overseer default
  },
  on_new_task = function(task)
    require("overseer").open({ enter = false, direction = "right" })
  end, -- gets the overseer.Task after it was created, before it is started
},
```

Overseer 2.0 removed the `toggleterm` and `terminal` strategies, so a configuration like

```lua
new_task_opts = {
  strategy = { "toggleterm", direction = "horizontal", quit_on_exit = "success" },
},
```

fails with `module 'overseer.strategy.toggleterm' not found`. Leave `strategy` unset to
use the overseer default (`jobstart`), or pick one of the strategies overseer still ships,
see the [overseer strategy docs](https://github.com/stevearc/overseer.nvim/blob/master/doc/strategies.md).

### Showing the output in a window

Overseer runs the task in a hidden buffer, its `default` components do not open it. To get
the build output in a split, attach the `open_output` component to the task:

```lua
new_task_opts = {
  components = {
    { "open_output", on_start = "always", direction = "horizontal", focus = false },
    "default",
  },
},
```

See `:help overseer-components` for the other parameters.

There is no equivalent for the `quit_on_exit = "success"` of the old toggleterm strategy,
none of the components closes the output window again.

If you used overseer only to get a toggleterm window, use the `toggleterm` executor and
runner instead, they open one directly:

```lua
cmake_executor = {
  name = "toggleterm",
  opts = { direction = "horizontal", close_on_exit = false, auto_scroll = true },
},
```

## Vimux

Runs the command in a [vimux](https://github.com/preservim/vimux) tmux pane, it takes no
options. Vimux cannot observe the process, so the command always counts as successful and
a `CMakeBuild` that failed still runs the target afterwards.
