-- cmake-tools's API
local has_nvim_dap, dap = pcall(require, "dap")
local has_telescope, telescope = pcall(require, "telescope")
local utils = require("cmake-tools.utils")
local Types = require("cmake-tools.types")
local const = require("cmake-tools.const")
local Config = require("cmake-tools.config")
local variants = require("cmake-tools.variants")
local kits = require("cmake-tools.kits")
local presets = require("cmake-tools.presets")
local log = require("cmake-tools.log")
local terminal = require("cmake-tools.executors.terminal")
local _session = require("cmake-tools.session")
local window = require("cmake-tools.window")
local environment = require("cmake-tools.environment")
local file_picker = require("cmake-tools.file_picker")

local config = Config:new(const)

local cmake = {}

local full_cmd = ""

local base_settings_default = {
  env = {},
}

local target_settings_default = {
  args = {},
  inherit_base_environment = true,
  env = {},
}

--- Setup cmake-tools
function cmake.setup(values)
  if has_telescope then
    telescope.load_extension("cmake_tools")
  end
  const = vim.tbl_deep_extend("force", const, values)
  if const.cmake_executor.name == "terminal" then
    const.cmake_executor = const.cmake_terminal
    log.info("Cannot use cmake-tools notifications in terminal mode")
    const.cmake_notifications.enabled = false
  else
    const.cmake_executor.opts = vim.tbl_deep_extend(
      "force",
      const.cmake_executor.default_opts[const.cmake_executor.name],
      const.cmake_executor.opts or {}
    )
  end
  config = Config:new(const)

  -- auto reload previous session
  if cmake.is_cmake_project() then
    local old_config = _session.load()
    if next(old_config) ~= nil then
      config:update_build_dir(old_config.build_directory)
      config.build_type = old_config.build_type
      config.build_target = old_config.build_target
      config.launch_target = old_config.launch_target
      config.kit = old_config.kit
      config.configure_preset = old_config.configure_preset
      config.build_preset = old_config.build_preset
      config.base_settings = old_config.base_settings
      config.target_settings = old_config.target_settings or {}

      -- migrate old launch args to new config
      if old_config.launch_args then
        for k, v in pairs(old_config.launch_args) do
          config.target_settings[k].args = v
        end
      end
    end
  end

  -- preload the autocmd if the following option is true. only saves cmakelists.txt files
  if cmake.is_cmake_project() then
    cmake.create_regenerate_on_save_autocmd()
  end
end

function cmake.get_config()
  return config
end

--- Generate build system for this project.
-- Think it as `cmake .`
function cmake.generate(opt, callback)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local clean = opt.bang
  local fargs = opt.fargs or {}
  if clean then
    return cmake.clean(function()
      cmake.generate({ fargs = fargs }, callback)
    end)
  end

  -- if exists presets, preset include all info that cmake
  -- needed to execute, so we don't use cmake-kits.json and
  -- cmake-variants.[json|yaml] event they exist.
  local presets_file = presets.check()
  if presets_file and not config.configure_preset then
    -- this will also set value for build type from preset.
    -- default to be "Debug"
    return cmake.select_configure_preset(function()
      cmake.generate(opt, callback)
    end)
  end

  if presets_file and config.configure_preset then
    -- if exsist preset file and set configure preset, then
    -- set build directory to the `binaryDir` option of `configurePresets`
    local build_directory =
      presets.get_build_dir(presets.get_preset_by_name(config.configure_preset, "configurePresets"))
    if build_directory ~= "" then
      config:update_build_dir(build_directory)
    end
    config:generate_build_directory()

    local args = {
      "--preset",
      config.configure_preset,
    }
    vim.list_extend(args, config.generate_options)
    vim.list_extend(args, fargs)

    local env = environment.get_build_environment(config, config.executor.name == "terminal")

    if config.executor.name == "terminal" then
      if full_cmd ~= "" then
        full_cmd = full_cmd
          .. " && "
          .. terminal.prepare_cmd_for_run(const.cmake_command, env, args)
      else
        full_cmd = terminal.prepare_cmd_for_run(const.cmake_command, env, args)
      end
      if type(callback) == "function" then
        callback()
      else
        utils.run(full_cmd, {}, {}, config.executor, nil, const.cmake_notifications)
        cmake.configure_compile_commands()
        cmake.create_regenerate_on_save_autocmd()
        full_cmd = ""
      end
    else
      return utils.run(const.cmake_command, env, args, config.executor, function()
        if type(callback) == "function" then
          callback()
        end
        cmake.configure_compile_commands()
        cmake.create_regenerate_on_save_autocmd()
      end, const.cmake_notifications)
    end
  end

  -- if exists cmake-kits.json, kit is used to set
  -- environmental variables and args.
  local kits_config = kits.parse(const.cmake_kits_path)
  if kits_config and not config.kit then
    return cmake.select_kit(function()
      cmake.generate(opt, callback)
    end)
  end

  -- specify build type, if exists cmake-variants.json,
  -- this will get build variant from it. Or this will
  -- get build variant from "Debug, Release, RelWithDebInfo, MinSizeRel"
  if not config.build_type then
    return cmake.select_build_type(function()
      cmake.generate(opt, callback)
    end)
  end

  -- cmake kits, if cmake-kits.json doesn't exist, kit_option will
  -- be {env={}, args={}}, so it's okay.
  local kit_option = kits.build_env_and_args(config.kit, config.executor.name == "terminal")

  if const.cmake_build_directory ~= "" then
    config:update_build_dir(const.cmake_build_directory)
  else
    local _build_type = config.build_type:gsub("+", "_"):gsub(" ", "")
    config:update_build_dir(const.cmake_build_directory_prefix .. _build_type)
  end

  config:generate_build_directory()

  local args = {
    "-B",
    config.build_directory.filename,
    "-S",
    ".",
  }
  vim.list_extend(args, variants.build_arglist(config.build_type))
  vim.list_extend(args, kit_option.args)
  vim.list_extend(args, config.generate_options)
  vim.list_extend(args, fargs)

  local env = environment.get_build_environment(config, config.executor.name == "terminal")

  if config.executor.name == "terminal" then
    if full_cmd ~= "" then
      full_cmd = full_cmd .. " && " .. terminal.prepare_cmd_for_run(const.cmake_command, env, args)
    else
      full_cmd = terminal.prepare_cmd_for_run(const.cmake_command, env, args)
    end
    if type(callback) == "function" then
      callback()
    else
      utils.run(full_cmd, {}, {}, config.executor, nil, const.cmake_notifications)
      cmake.configure_compile_commands()
      cmake.create_regenerate_on_save_autocmd()
      full_cmd = ""
    end
  else
    env = vim.tbl_extend("keep", env, kit_option.env)
    utils.run(const.cmake_command, env, args, config.executor, function()
      if type(callback) == "function" then
        callback()
      end
      cmake.configure_compile_commands()
      cmake.create_regenerate_on_save_autocmd()
    end, const.cmake_notifications)
  end
end

--- Clean targets
function cmake.clean(callback)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local args = { "--build", config.build_directory.filename, "--target", "clean" }

  local env = environment.get_build_environment(config, config.executor.name == "terminal")

  if config.executor.name == "terminal" then
    if full_cmd ~= "" then
      full_cmd = full_cmd .. " && " .. terminal.prepare_cmd_for_run(const.cmake_command, env, args)
    else
      full_cmd = terminal.prepare_cmd_for_run(const.cmake_command, env, args)
    end
    if type(callback) == "function" then
      return callback()
    else
      utils.run(full_cmd, {}, {}, config.executor, nil, const.cmake_notifications)
      full_cmd = ""
    end
  else
    return utils.run(const.cmake_command, env, args, config.executor, function()
      if type(callback) == "function" then
        callback()
      end
    end, const.cmake_notifications)
  end
end

--- Build this project using the make toolchain of target platform
--- think it as `cmake --build .`
function cmake.build(opt, callback)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local clean = opt.bang
  local fargs = opt.fargs or {}
  if clean then
    return cmake.clean(function()
      cmake.build({ fargs = fargs }, callback)
    end)
  end

  if not (config.build_directory and config.build_directory:exists()) then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} }, function()
      cmake.build(opt, callback)
    end)
  end

  if opt.target == nil and config.build_target == nil then
    return cmake.select_build_target(function()
      cmake.build(opt, callback)
    end), true
  end

  local args
  local presets_file = presets.check()

  if presets_file and config.build_preset then
    args = { "--build", "--preset", config.build_preset } -- preset don't need define build dir.
  else
    args = { "--build", config.build_directory.filename }
  end

  vim.list_extend(args, config.build_options)
  local env = environment.get_build_environment(config, config.executor.name == "terminal")

  if opt.target ~= nil then
    vim.list_extend(args, { "--target", opt.target })
    vim.list_extend(args, fargs)
  elseif config.build_target == "all" then
    vim.list_extend(args, { "--target", "all" })
    vim.list_extend(args, fargs)
  else
    vim.list_extend(args, { "--target", config.build_target })
    vim.list_extend(args, fargs)
  end

  if config.executor.name == "terminal" then
    if full_cmd ~= "" then
      full_cmd = full_cmd .. " && " .. terminal.prepare_cmd_for_run(const.cmake_command, env, args)
    else
      full_cmd = terminal.prepare_cmd_for_run(const.cmake_command, env, args)
    end
    if type(callback) == "function" then
      callback()
    else
      utils.run(full_cmd, {}, {}, config.executor, nil, const.cmake_notifications)
      full_cmd = ""
    end
  else
    utils.run(const.cmake_command, env, args, config.executor, function()
      if type(callback) == "function" then
        callback()
      end
    end, const.cmake_notifications)
  end
end

function cmake.quick_build(opt, callback)
  -- if no target was supplied, query via ui select
  if opt.fargs[1] == nil then
    if utils.has_active_job(config.terminal, config.executor) then
      return
    end

    if not (config.build_directory and config.build_directory:exists()) then
      -- configure it
      return cmake.generate({ bang = false, fargs = {} }, function()
        cmake.quick_build(opt, callback)
      end)
    end

    local targets_res = config:build_targets()
    local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets

    vim.ui.select(
      display_targets,
      { prompt = "Select target to build" },
      vim.schedule_wrap(function(_, idx)
        if not idx then
          return
        end
        cmake.build({ target = targets[idx] }, callback)
      end)
    )
  else
    cmake.build({ target = opt.fargs[1] }, callback)
  end
end

function cmake.stop()
  if not utils.has_active_job(config.terminal, config.executor) then
    log.error("CMake Tools isn't running")
    return
  end

  utils.stop(config.executor)
end

--- CMake install targets
function cmake.install(opt)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local fargs = opt.fargs

  local args = { "--install", config.build_directory.filename }
  vim.list_extend(args, fargs)
  --TODO notifications
  return utils.run(const.cmake_command, {}, args, config.executor, nil, const.cmake_notifications)
end

--- CMake close cmake console
function cmake.close()
  utils.close_cmake_window(config.executor)
end

--- CMake open cmake console
function cmake.open()
  utils.show_cmake_window(config.executor)
end

-- Run executable targets
function cmake.run(opt)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  if opt.target then
    -- explicit target requested. use that instead of the configured one
    return cmake.build({ target = opt.target }, function()
      local model = config:get_code_model_info()[opt.target]
      local result = config:get_launch_target_from_info(model)
      local target_path = result.data

      local launch_path = vim.fn.fnamemodify(target_path, ":h")

      if full_cmd ~= "" then
        full_cmd = 'cd "'
          .. vim.loop.cwd()
          .. '" && '
          .. full_cmd
          .. " && "
          .. terminal.prepare_cmd_for_execute(
            target_path,
            opt.args,
            launch_path,
            opt.wrap_call,
            environment.get_run_environment(config, opt.target, true)
          )
      else
        full_cmd = terminal.prepare_cmd_for_execute(
          target_path,
          opt.args,
          launch_path,
          opt.wrap_call,
          environment.get_run_environment(config, opt.target, true)
        )
      end
      utils.execute(target_path, full_cmd, config.terminal, config.executor)
      full_cmd = ""
    end)
  else
    local result = config:get_launch_target()
    local result_code = result.code
    if result_code == Types.NOT_CONFIGURED or result_code == Types.CANNOT_FIND_CODEMODEL_FILE then
      if config.executor.name == "terminal" then
        log.error("For terminal mode, you need to firstly invoke CMakeGenerate.")
        full_cmd = ""
        return
      else
        -- Configure it
        return cmake.generate({ bang = false, fargs = utils.deepcopy(opt.fargs) }, function()
          cmake.run(opt)
        end)
      end
    elseif
      result_code == Types.NOT_SELECT_LAUNCH_TARGET
      or result_code == Types.NOT_A_LAUNCH_TARGET
      or result_code == Types.NOT_EXECUTABLE
    then
      -- Re Select a target that could launch
      return cmake.select_launch_target(function()
        cmake.run(opt)
      end), true
    else -- if result_code == Types.SELECTED_LAUNCH_TARGET_NOT_BUILT
      -- Build select launch target every time
      config.build_target = config.launch_target
      return cmake.build({ fargs = utils.deepcopy(opt.fargs) }, function()
        result = config:get_launch_target()
        local target_path = result.data
        local launch_path = vim.fn.fnamemodify(target_path, ":h")

        if full_cmd ~= "" then
          -- This jumps to the working directory, builds the target and then launches it inside the launch terminal
          -- Hence, "cd ".. vim.cwd .. " && "..    The \" is for path handling, specifically in win32
          full_cmd = 'cd "'
            .. vim.loop.cwd()
            .. '" && '
            .. full_cmd
            .. " && "
            .. terminal.prepare_cmd_for_execute(
              target_path,
              cmake:get_launch_args(),
              launch_path,
              opt.wrap_call,
              environment.get_run_environment(config, config.launch_target, true)
            )
        else
          full_cmd = terminal.prepare_cmd_for_execute(
            target_path,
            cmake:get_launch_args(),
            launch_path,
            opt.wrap_call,
            environment.get_run_environment(config, config.launch_target, true)
          )
        end
        utils.execute(target_path, full_cmd, config.terminal, config.executor)
        full_cmd = ""
      end)
    end
  end
end

if has_telescope then
  function cmake.show_target_files(opt)
    -- if no target was supplied, query via ui select
    if opt.fargs[1] == nil then
      if utils.has_active_job(config.terminal, config.executor) then
        return
      end

      if not (config.build_directory and config.build_directory:exists()) then
        -- configure it
        return cmake.generate({ bang = false, fargs = {} }, function()
          cmake.show(opt)
        end)
      end

      local targets_res = config:build_targets()
      local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets

      for idx, v in ipairs(targets) do
        if v == "all" then -- this default target does not exist in the code model
          table.remove(targets, idx)
          table.remove(display_targets, idx)
        end
      end

      vim.ui.select(
        display_targets,
        { prompt = "Select target to run" },
        vim.schedule_wrap(function(_, idx)
          if not idx then
            return
          end
          file_picker.show_target_files(targets[idx])
        end)
      )
    else
      file_picker.show_target_files(opt.fargs[1])
    end
  end
end

function cmake.quick_run(opt)
  -- if no target was supplied, query via ui select
  if opt.fargs[1] == nil then
    if utils.has_active_job(config.terminal, config.executor) then
      return
    end

    if not (config.build_directory and config.build_directory:exists()) then
      -- configure it
      return cmake.generate({ bang = false, fargs = {} }, function()
        cmake.quick_run(opt)
      end)
    end

    local targets_res = config:launch_targets()
    local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets

    vim.ui.select(
      display_targets,
      { prompt = "Select target to run" },
      vim.schedule_wrap(function(_, idx)
        if not idx then
          return
        end
        cmake.run({ target = targets[idx], wrap_call = opt.wrap_call })
      end)
    )
  else
    local target = table.remove(opt.fargs, 1)
    cmake.run({ target = target, args = opt.fargs, wrap_call = opt.wrap_call })
  end
end

-- Set args for launch target
function cmake.launch_args(opt)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  if cmake.get_launch_target() ~= nil then
    if not config.target_settings[cmake.get_launch_target()] then
      config.target_settings[cmake.get_launch_target()] = {}
    end

    config.target_settings[cmake.get_launch_target()].args = utils.deepcopy(opt.fargs)
  end
end

if has_nvim_dap then
  -- Debug execuable targets
  function cmake.debug(opt, callback)
    if utils.has_active_job(config.terminal, config.executor) then
      return
    end

    local env = environment.get_run_environment_table(
      config,
      opt.target and opt.target or config.launch_target
    )
    -- nvim.dap expects all env vars as string
    for index, value in pairs(env) do
      env[index] = tostring(value)
    end

    local can_debug_result = config:validate_for_debugging()
    if can_debug_result.code == Types.CANNOT_DEBUG_LAUNCH_TARGET then
      -- Select build type to debug
      return cmake.select_build_type(function()
        cmake.debug(opt, callback)
      end)
    end

    if opt.target then
      -- explicit target requested. use that instead of the configured one
      return cmake.build({ target = opt.target }, function()
        local model = config:get_code_model_info()[opt.target]
        local result = config:get_launch_target_from_info(model)
        local dap_config = {
          name = opt.target,
          program = result.data,
          cwd = utils.get_path(result.data, "/"),
          args = opt.args,
          env = env,
        }
        -- close cmake console
        cmake.close()
        dap.run(vim.tbl_extend("force", dap_config, const.cmake_dap_configuration))
      end)
    else
      local result = config:get_launch_target()
      local result_code = result.code

      if result_code == Types.NOT_CONFIGURED or result_code == Types.CANNOT_FIND_CODEMODEL_FILE then
        if config.executor.name == "terminal" then
          log.error("For terminal mode, you need to firstly invoke CMakeGenerate.")
          full_cmd = ""
          return
        else
          -- Configure it
          return cmake.generate({ bang = false, fargs = utils.deepcopy(opt.fargs) }, function()
            cmake.debug(opt, callback)
          end)
        end
      elseif
        result_code == Types.NOT_SELECT_LAUNCH_TARGET
        or result_code == Types.NOT_A_LAUNCH_TARGET
        or result_code == Types.NOT_EXECUTABLE
      then
        -- Re Select a target that could launch
        return cmake.select_launch_target(function()
          cmake.debug(opt, callback)
        end),
          true
      else -- if result_code == Types.SELECTED_LAUNCH_TARGET_NOT_BUILT then
        -- Build select launch target every time
        config.build_target = config.launch_target
        return cmake.build({ fargs = utils.deepcopy(opt.fargs) }, function()
          result = config:get_launch_target()
          local target_path = result.data
          local dap_config = {
            name = config.launch_target,
            program = target_path,
            cwd = utils.get_path(result.data, "/"),
            args = cmake:get_launch_args(),
            env = env,
          }
          -- close cmake console
          cmake.close()
          dap.run(vim.tbl_extend("force", dap_config, const.cmake_dap_configuration))
        end)
      end
    end
  end

  function cmake.quick_debug(opt, callback)
    -- if no target was supplied, query via ui select
    if opt.fargs[1] == nil then
      if utils.has_active_job(config.terminal, config.executor) then
        return
      end

      if not (config.build_directory and config.build_directory:exists()) then
        -- configure it
        return cmake.generate({ bang = false, fargs = {} }, function()
          cmake.quick_debug(opt, callback)
        end)
      end

      local targets_res = config:launch_targets()
      local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets

      vim.ui.select(
        display_targets,
        { prompt = "Select target to debug" },
        vim.schedule_wrap(function(_, idx)
          if not idx then
            return
          end
          cmake.debug({ target = targets[idx] }, callback)
        end)
      )
    else
      local target = table.remove(opt.fargs, 1)
      cmake.debug({ target = target, args = opt.fargs }, callback)
    end
  end
end

function cmake.select_build_type(callback)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local types = variants.get(const.cmake_variants_message)
  -- Put selected build type first
  for idx, type in ipairs(types) do
    if type == config.build_type then
      table.insert(types, 1, table.remove(types, idx))
      break
    end
  end

  vim.ui.select(
    types,
    {
      prompt = "Select build type",
      format_item = function(item)
        return item.short .. item.long
      end,
    },
    vim.schedule_wrap(function(build_type)
      if not build_type then
        return
      end
      if config.build_type ~= build_type then
        config.build_type = build_type.short
        if type(callback) == "function" then
          callback()
        else
          cmake.generate({ bang = false, fargs = {} }, nil)
        end
      end
    end)
  )
end

function cmake.select_kit(callback)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local cmake_kits = kits.get(const.cmake_kits_path)
  if cmake_kits then
    -- Put selected kit first
    for idx, kit in ipairs(cmake_kits) do
      if kit == config.kit then
        table.insert(cmake_kits, 1, table.remove(cmake_kits, idx))
        break
      end
    end

    vim.ui.select(
      cmake_kits,
      { prompt = "Select cmake kits" },
      vim.schedule_wrap(function(kit)
        if not kit then
          return
        end
        if config.kit ~= kit then
          config.kit = kit
        end
        if type(callback) == "function" then
          callback()
        else
          cmake.generate({ bang = false, fargs = {} }, nil)
        end
      end)
    )
  else
    log.error("Cannot find CMakeKits.[json|yaml] at Root!!")
  end
end

function cmake.select_configure_preset(callback)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  -- if exists presets
  local presets_file = presets.check()
  if presets_file then
    local configure_preset_names = presets.parse("configurePresets", { include_hidden = false })
    local configure_presets =
      presets.parse_name_mapped("configurePresets", { include_hidden = false })
    local format_preset_name = function(p_name)
      local p = configure_presets[p_name]
      return p.displayName or p.name
    end
    vim.ui.select(
      configure_preset_names,
      {
        prompt = "Select cmake configure presets",
        format_item = format_preset_name,
      },
      vim.schedule_wrap(function(choice)
        if not choice then
          return
        end
        if config.configure_preset ~= choice then
          config.configure_preset = choice
          config.build_type =
            presets.get_build_type(presets.get_preset_by_name(choice, "configurePresets"))
        end
        if type(callback) == "function" then
          callback()
        else
          cmake.generate({ bang = false, fargs = {} }, nil)
        end
      end)
    )
  else
    log.error("Cannot find CMake[User]Presets.json at Root!!")
  end
end

function cmake.select_build_preset(callback)
  if utils.has_active_job(config.terminal, config.executor) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  -- if exists presets
  local presets_file = presets.check()
  if presets_file then
    local build_preset_names = presets.parse("buildPresets", { include_hidden = false })
    local build_presets = presets.parse_name_mapped("buildPresets", { include_hidden = false })
    local format_preset_name = function(p_name)
      local p = build_presets[p_name]
      return p.displayName or p.name
    end
    vim.ui.select(
      build_preset_names,
      { prompt = "Select cmake build presets", format_item = format_preset_name },
      vim.schedule_wrap(function(choice)
        if not choice then
          return
        end
        if config.build_preset ~= choice then
          config.build_preset = choice
        end
        if type(callback) == "function" then
          callback()
        end
      end)
    )
  else
    log.error("Cannot find CMake[User]Presets.json at Root!!")
  end
end

function cmake.select_build_target(callback, regenerate)
  if not (config.build_directory and config.build_directory:exists()) then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} }, function()
      cmake.select_build_target(callback, true)
    end)
  end

  local targets_res = config:build_targets()

  if targets_res.code ~= Types.SUCCESS then
    -- try again
    if not regenerate then
      if config.executor.name == "terminal" then
        log.error("For terminal mode, you need to firstly invoke CMakeGenerate.")
        full_cmd = ""
        return
      else
        return
      end
    else
      return cmake.generate({ bang = true, fargs = {} }, function()
        cmake.select_build_target(callback, false)
      end)
    end
  end
  local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets
  vim.ui.select(
    display_targets,
    { prompt = "Select build target" },
    vim.schedule_wrap(function(_, idx)
      if not idx then
        return
      end
      config.build_target = targets[idx]
      if type(callback) == "function" then
        callback()
      end
    end)
  )
end

function cmake.get_cmake_launch_targets(callback)
  if not (config.build_directory and config.build_directory:exists()) then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} }, function()
      cmake.get_cmake_launch_targets(callback)
    end)
  end

  if type(callback) == "function" then
    callback(config:launch_targets())
  end
end

function cmake.select_launch_target(callback, regenerate)
  if not (config.build_directory and config.build_directory:exists()) then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} }, function()
      cmake.select_launch_target(callback, true)
    end)
  end

  local targets_res = config:launch_targets()

  if targets_res.code ~= Types.SUCCESS then
    -- try again
    if not regenerate then
      if config.executor.name == "terminal" then
        log.error("For terminal mode, you need to firstly invoke CMakeGenerate.")
        full_cmd = ""
        return
      else
        return
      end
    else
      return cmake.generate({ bang = true, fargs = {} }, function()
        cmake.select_launch_target(callback, false)
      end)
    end
  end
  local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets

  vim.ui.select(
    display_targets,
    { prompt = "Select launch target" },
    vim.schedule_wrap(function(_, idx)
      if not idx then
        return
      end
      config.launch_target = targets[idx]
      if type(callback) == "function" then
        callback()
      end
    end)
  )
end

function cmake.settings()
  if not window.is_open() then
    if not config.base_settings then
      config.base_settings = {}
    end

    -- insert missing fields
    config.base_settings = vim.tbl_deep_extend("keep", config.base_settings, base_settings_default)

    window.set_content("return " .. vim.inspect(config.base_settings))
    window.title = "CMake-Tools base settings"
    window.on_save = function(str)
      local fn = loadstring(str)
      if fn then
        config.base_settings = fn()
      end
    end
    window.open()
  end
end

function cmake.target_settings(opt)
  local target = opt.fargs[1] or cmake.get_launch_target()

  if target == nil then
    log.warn("No launch target selected!")
    return
  end

  if not window.is_open() then
    if not config.target_settings then
      config.target_settings = {}
    end
    if not config.target_settings[target] then
      config.target_settings[target] = {}
    end

    -- insert missing fields
    config.target_settings[target] =
      vim.tbl_deep_extend("keep", config.target_settings[target], target_settings_default)

    window.set_content("return " .. vim.inspect(config.target_settings[target]))
    window.title = "CMake-Tools settings for " .. target
    window.on_save = function(str)
      local fn = loadstring(str)
      if fn then
        config.target_settings[target] = fn()
      end
    end
    window.open()
  end
end

--[[ Getters ]]

function cmake.get_build_target()
  return config.build_target
end

function cmake.get_launch_target()
  return config.launch_target
end

function cmake.get_model_info()
  return config:get_code_model_info()
end

function cmake.get_launch_args()
  if cmake.get_launch_target() == nil then
    return {}
  end
  if
    config.target_settings[cmake.get_launch_target()]
    and config.target_settings[cmake.get_launch_target()].args
  then
    return config.target_settings[cmake.get_launch_target()].args
  end

  return {}
end

function cmake.get_build_environment()
  return environment.get_build_environment_table(config)
end

function cmake.get_run_environment(target)
  return environment.get_run_environment_table(
    config,
    target and target or cmake.get_launch_target()
  )
end

function cmake.get_build_type()
  return config.build_type
end

function cmake.get_kit()
  return config.kit
end

function cmake.get_configure_preset()
  return config.configure_preset
end

function cmake.get_build_preset()
  return config.build_preset
end

function cmake.get_build_directory()
  return config.build_directory
end

function cmake.is_cmake_project()
  local result = utils.get_cmake_configuration()
  return result.code == Types.SUCCESS
end

function cmake.has_cmake_preset()
  local presets_file = presets.check()
  return presets_file ~= nil
end

--[[ end ]]

function cmake.configure_compile_commands()
  if const.cmake_soft_link_compile_commands then
    cmake.compile_commands_from_soft_link()
  elseif const.cmake_compile_commands_from_lsp then
    cmake.compile_commands_from_lsp()
  end
end

function cmake.compile_commands_from_soft_link()
  if config.build_directory == nil then
    return
  end

  local source = vim.loop.cwd()
    .. "/"
    .. config.build_directory.filename
    .. "/compile_commands.json"
  local destination = vim.loop.cwd() .. "/compile_commands.json"
  if config.executor.name == "terminal" or utils.file_exists(source) then
    utils.softlink(source, destination, config.executor.name == "terminal", config.terminal.opts)
  end
end

function cmake.compile_commands_from_lsp()
  if config.build_directory == nil or const.lsp_type == nil then
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_active_clients({ name = const.lsp_type })
  for _, client in ipairs(clients) do
    local lspbufs = vim.lsp.get_buffers_by_client_id(client.id)
    for _, bufid in ipairs(lspbufs) do
      vim.api.nvim_set_current_buf(bufid)
      vim.cmd("LspRestart " .. tostring(client.id))
    end
  end
  vim.api.nvim_set_current_buf(buf)
end

function cmake.clangd_on_new_config(new_config)
  const.lsp_type = "clangd"

  local found = false
  local arg = "--compile-commands-dir=" .. config.build_directory.filename
  for _, v in ipairs(new_config.cmd) do
    if string.find(v, "--compile-commands-dir=") ~= nil then
      found = true
      break
    end
  end
  if found ~= true then
    table.insert(new_config.cmd, arg)
  end
end

function cmake.ccls_on_new_config(new_config)
  const.lsp_type = "ccls"

  new_config.init_options.compilationDatabaseDirectory = config.build_directory.filename
end

local group = vim.api.nvim_create_augroup("cmaketools", { clear = true })
local regenerate_id = nil

function cmake.create_regenerate_on_save_autocmd()
  if not const.cmake_regenerate_on_save then
    return
  end
  if regenerate_id then
    vim.api.nvim_del_autocmd(regenerate_id)
  end

  local cmake_files = file_picker.get_cmake_files()

  local pattern = {}
  for _, item in ipairs(cmake_files) do
    table.insert(pattern, vim.loop.cwd() .. "/" .. item)
  end

  local presets_file = presets.check()
  if presets_file then
    for _, item in ipairs({
      "CMakePresets.json",
      "CMakeUserPresets.json",
      "cmake-presets.json",
      "cmake-user-presets.json",
    }) do
      table.insert(pattern, vim.loop.cwd() .. "/" .. item)
    end
  else
    for _, item in ipairs({
      "CMakeVariants.json",
      "CMakeVariants.yaml",
      "cmake-variants.yaml",
      "cmake-variants.json",
      "CMakeKits.json",
      "cmake-kits.json",
    }) do
      table.insert(pattern, vim.loop.cwd() .. "/" .. item)
    end
  end

  if #pattern ~= 0 then
    -- for cmake files
    regenerate_id = vim.api.nvim_create_autocmd("BufWritePre", {
      group = group,
      pattern = pattern,
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        -- Check if buffer is actually modified, and only if it is modified,
        -- execute the :CMakeGenerate, otherwise return. This is to avoid unnecessary regenerattion
        local buf_modified = vim.api.nvim_buf_get_option(buf, "modified")
        if buf_modified then
          cmake.generate({ bang = false, fargs = {} }, nil)
        end
      end,
    })
  end
end

-- We have a command to escape insert mode after proccess extis
-- because, we want to scroll the buffer output after completion of execution
if cmake.is_cmake_project() then
  vim.api.nvim_create_autocmd("TermClose", {
    group = group,
    callback = function()
      vim.cmd.stopinsert()
      vim.api.nvim_feedkeys("<C-\\><C-n><CR>", "n", false)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      _session.save(config)
    end,
  })
end

return cmake
