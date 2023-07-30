# Settings

`cmake-tools` allows for various project and target specific settings to be specified.

`CMakeSettings` is used for general settings.

`CMakeTargetSettings` is used for settings of a specific target.

To configure these settings a lua buffer is used. Upon executing `CMakeSettings` or `CMakeTargetSettings` popup will open.
In this popup you are able edit the current settings.

The popup window autosaves and can be closed with `q` or `<esc>`

Example for `CMakeSettings`

```lua
return {
  env = {
    VERBOSE = 1,
  },
  working_dir = "${dir.binary}"
}
```

Example for `CMakeTargetSettings`

```lua
return {
  inherit_base_environment = true,
  args = {}
  env = {
    log_level = "trace"
  }
}
```

## variables

The popup window will show available variables and their values.

```lua
local vars = {
  dir = {
    binary = "",
    build = ""
  }
```

These can be used for substitution (see [working_directory](#working_directory)) or directly as lua variables.

## Settings

Following settings are available:

### `env`

Specify environment variables for various tasks.
Strings and numbers are supported.

```lua
env = {
  VERBOSE = 1,
  log_level = "trace"
}
```

| Command               | Supported          | Details                 |
|--------------         | --------------     |  --------------         |
| `CMakeSettings`       | :white_check_mark: | environment varaibles for executing cmake commands. These are per default inherit to targets.  |
| `CMakeTargetSettings` | :white_check_mark: | environment variables for running and debugging targets.    |

### `inherit_base_environment`

```lua
  inherit_base_environment = true -- true|false
```

| Command               | Supported          | Details                 |
|--------------         | --------------     |  --------------         |
| `CMakeSettings`       | :x:                | |
| `CMakeTargetSettings` | :white_check_mark: | Will inherit env various from base settings if set to `true` |

### `args`

Specify additional command line arguments.

```lua
  args = { "arg1", "args2=value" }
```

| Command               | Supported          | Details                 |
|--------------         | --------------     |  --------------         |
| `CMakeSettings`       | :x:                | |
| `CMakeTargetSettings` | :white_check_mark: | command line arguments passed to executable when running or debugging |

### `working_directory`

Specify the working directory in which run and debug commands are executed. Supports substitution commands (`${}`).

```lua
  working_directory = "${dir.binary}"
```

| Command               | Supported          | Details                 |
|--------------         | --------------     |  --------------         |
| `CMakeSettings`       | :white_check_mark: | Defines the working directory for all targets unless overwritten. |
| `CMakeTargetSettings` | :white_check_mark: | Sets the working directory just for this target. No default value - Has to be added manually. |
