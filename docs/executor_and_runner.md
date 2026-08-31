# Executor And Runner

This plugin splits the cmake process to two parts, one for generating libraries and executable, one for executing the executable programs.

- For the former, we use *Executor*, including toggleterm, overseer.nvim, quickfix, and terminal.
- For the latter, we use *Runner*, also including toggleterm, overseer.nvim, quickfix, and terminal.

## Overseer

The `overseer` executor and runner create a task with `overseer.new_task`, everything
you put in `new_task_opts` is passed to it unchanged.

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

