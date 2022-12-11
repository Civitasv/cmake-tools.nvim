--- cmake-tools's API
local has_nvim_dap, dap = pcall(require, "dap")
local utils = require("cmake-tools.utils")
local Types = require("cmake-tools.types")
local const = require("cmake-tools.const")
local Config = require("cmake-tools.config")
local variants = require("cmake-tools.variants")
local kits = require("cmake-tools.kits")
local presets = require("cmake-tools.presets")

local config = Config:new(const)

local cmake = {}

--- Setup cmake-tools
function cmake.setup(values)
  const = vim.tbl_deep_extend("force", const, values)
  config = Config:new(const)
end

--- Generate build system for this project.
-- Think it as `cmake .`
function cmake.generate(opt, callback)
  if not utils.has_active_job() then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return utils.error(result.message)
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
    local build_directory = presets.get_build_dir(
      presets.get_preset_by_name(config.configure_preset, "configurePresets")
    )
    if build_directory ~= "" then
      config:update_build_dir(build_directory)
    end
    config:generate_build_directory()

    vim.list_extend(fargs, {
      "--preset",
      config.configure_preset,
      unpack(config.generate_options),
    })

    return utils.run(const.cmake_command, {}, fargs, {
      on_success = function()
        if type(callback) == "function" then
          callback()
        end
      end,
      cmake_show_console = const.cmake_show_console,
      cmake_console_size = const.cmake_console_size
    })
  end

  -- if exists cmake-kits.json, kit is used to set
  -- environmental variables and args.
  local kits_config = kits.parse()
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
  local kit_option = kits.build_env_and_args(config.kit)

  if const.cmake_build_directory ~= "" then
    config:update_build_dir(const.cmake_build_directory)
  else
    config:update_build_dir(const.cmake_build_directory_prefix .. config.build_type)
  end

  config:generate_build_directory()

  vim.list_extend(fargs, {
    "-B",
    config.build_directory.filename,
    "-S",
    ".",
    unpack(variants.build_arglist(config.build_type)),
    unpack(kit_option.args),
    unpack(config.generate_options),
  })

  return utils.run(const.cmake_command, kit_option.env, fargs, {
    on_success = function()
      if type(callback) == "function" then
        callback()
      end
    end,
    cmake_show_console = const.cmake_show_console,
    cmake_console_size = const.cmake_console_size
  })
end

--- Clean targets
function cmake.clean(callback)
  if not utils.has_active_job() then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return utils.error(result.message)
  end

  local args = { "--build", config.build_directory.filename, "--target", "clean" }

  return utils.run(const.cmake_command, {}, args, {
    on_success = function()
      if type(callback) == "function" then
        callback()
      end
    end,
    cmake_show_console = const.cmake_show_console,
    cmake_console_size = const.cmake_console_size
  })
end

--- Build this project using the make toolchain of target platform
--- think it as `cmake --build .`
function cmake.build(opt, callback)
  if not utils.has_active_job() then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return utils.error(result.message)
  end

  local fargs = opt.fargs or {}

  --[[ if not config.build_directory:exists() then ]]
  -- first, configure it
  return cmake.generate({ bang = false, fargs = {} }, function()
    -- then, build it
    if config.build_target == nil then
      return vim.schedule(function()
        cmake.select_build_target(function()
          vim.schedule(function()
            cmake.build(opt, callback)
          end)
        end, false)
      end)
    end

    local args
    local presets_file = presets.check()

    if presets_file and config.build_preset then
      args = { "--build", "--preset", config.build_preset, unpack(config.build_options) } -- preset don't need define build dir.
    else
      args = { "--build", config.build_directory.filename, unpack(config.build_options) }
    end

    if config.build_target == "all" then
      vim.list_extend(fargs, vim.list_extend(args, {
        "--target",
        "all"
      }))
    else
      vim.list_extend(fargs, vim.list_extend(args, {
        "--target",
        config.build_target
      }))
    end

    return utils.run(const.cmake_command, {}, fargs, {
      on_success = function()
        if type(callback) == "function" then
          callback()
        end
      end,
      cmake_show_console = const.cmake_show_console,
      cmake_console_size = const.cmake_console_size
    })
  end)
  --[[ end ]]
end

function cmake.stop()
  if not utils.job or utils.job.is_shutdown then
    utils.error("CMake Tools isn't running")
    return
  end

  utils.job:shutdown(1, 9)

  if vim.fn.has("win32") == 1 then
    -- Kill all children
    for _, pid in ipairs(vim.api.nvim_get_proc_children(utils.job.pid)) do
      vim.loop.kill(pid, 9)
    end
  else
    vim.loop.kill(utils.job.pid, 9)
  end
end

--- CMake install targets
function cmake.install(opt)
  if not utils.has_active_job() then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return utils.error(result.message)
  end

  local fargs = opt.fargs

  vim.list_extend(fargs, { "--install", config.build_directory.filename })
  return utils.run(const.cmake_command, {}, fargs, {
    cmake_show_console = const.cmake_show_console,
    cmake_console_size = const.cmake_console_size
  })
end

--- CMake close cmake console
function cmake.close()
  utils.close_cmake_console()
end

--- CMake open cmake console
function cmake.open()
  utils.show_cmake_console()
end

-- Run executable targets
function cmake.run(opt, callback)
  if not utils.has_active_job() then
    return
  end

  local result = config:get_launch_target()
  local result_code = result.code
  -- print(Types[result_code])
  if result_code == Types.NOT_CONFIGURED or result_code == Types.CANNOT_FIND_CODEMODEL_FILE then
    -- Configure it
    return cmake.generate({ bang = false, fargs = utils.deepcopy(opt.fargs) }, function()
      cmake.run(opt, callback)
    end)
  elseif result_code == Types.NOT_SELECT_LAUNCH_TARGET
      or result_code == Types.NOT_A_LAUNCH_TARGET
      or result_code == Types.NOT_EXECUTABLE
  then
    -- Re Select a target that could launch
    return cmake.select_launch_target(function()
      vim.schedule(function()
        cmake.run(opt, callback)
      end)
    end, false)
  else -- if result_code == Types.SELECTED_LAUNCH_TARGET_NOT_BUILT
    -- Build select launch target every time
    config.build_target = config.launch_target
    return cmake.build({ fargs = utils.deepcopy(opt.fargs) }, function()
      vim.schedule(function()
        result = config:get_launch_target()
        -- print(utils.dump(result))
        local target_path = result.data
        -- print("TARGET", target_path)

        return utils.execute(target_path, {
          bufname = vim.fn.expand("%:t:r"),
          cmake_console_position = const.cmake_console_position,
          cmake_console_size = const.cmake_console_size
        })
      end)
    end)
  end
end

if has_nvim_dap then
  -- Debug execuable targets
  function cmake.debug(opt, callback)
    if not utils.has_active_job() then
      return
    end

    local can_debug_result = config:validate_for_debugging()
    if can_debug_result.code == Types.CANNOT_DEBUG_LAUNCH_TARGET then
      -- Select build type to debug
      return cmake.select_build_type(function()
        cmake.debug(opt, callback)
      end)
    end

    local result = config:get_launch_target()
    local result_code = result.code

    if result_code == Types.NOT_CONFIGURED or result_code == Types.CANNOT_FIND_CODEMODEL_FILE then
      -- Configure it
      return cmake.generate({ bang = false, fargs = utils.deepcopy(opt.fargs) }, function()
        cmake.debug(opt, callback)
      end)
    elseif result_code == Types.NOT_SELECT_LAUNCH_TARGET
        or result_code == Types.NOT_A_LAUNCH_TARGET
        or result_code == Types.NOT_EXECUTABLE
    then
      -- Re Select a target that could launch
      return cmake.select_launch_target(function()
        vim.schedule(function()
          cmake.debug(opt, callback)
        end)
      end, false)
    else -- if result_code == Types.SELECTED_LAUNCH_TARGET_NOT_BUILT then
      -- Build select launch target every time
      config.build_target = config.launch_target
      return cmake.build({ fargs = utils.deepcopy(opt.fargs) }, function()
        vim.schedule(function()
          result = config:get_launch_target()
          local target_path = result.data
          local dap_config = {
            name = config.launch_target,
            program = target_path,
            cwd = vim.loop.cwd(),
          }
          dap.run(vim.tbl_extend("force", dap_config, const.cmake_dap_configuration))
          if const.cmake_dap_open_command then
            const.cmake_dap_open_command()
          end
        end)
      end)
    end
  end
end

function cmake.select_build_type(callback)
  if not utils.has_active_job() then
    return
  end
  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return utils.error(result.message)
  end

  local types = variants.get(const.cmake_variants_message)
  -- Put selected build type first
  for idx, type in ipairs(types) do
    if type == config.build_type then
      table.insert(types, 1, table.remove(types, idx))
      break
    end
  end

  vim.ui.select(types, { prompt = "Select build type" }, function(build_type)
    if not build_type then
      return
    end
    if config.build_type ~= build_type then
      config.build_type = build_type
      if type(callback) == "function" then
        callback()
      end
      -- regenerate it
      --[[ return cmake.generate({ bang = false, fargs = {} }, function() ]]
      --[[   vim.schedule(function() ]]
      --[[     if type(callback) == "function" then ]]
      --[[       callback() ]]
      --[[     end ]]
      --[[   end) ]]
      --[[ end) ]]
    end
  end)
end

function cmake.select_kit(callback)
  if not utils.has_active_job() then
    return
  end
  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return utils.error(result.message)
  end

  local cmake_kits = kits.get()
  if cmake_kits then
    -- Put selected kit first
    for idx, kit in ipairs(cmake_kits) do
      if kit == config.kit then
        table.insert(cmake_kits, 1, table.remove(cmake_kits, idx))
        break
      end
    end

    vim.ui.select(cmake_kits, { prompt = "Select cmake kits" }, function(kit)
      if not kit then
        return
      end
      if config.kit ~= kit then
        config.kit = kit
      end
      if type(callback) == "function" then
        callback()
      end
    end)
  else
    utils.error("Cannot find CMakeKits.[json|yaml] at Root!!")
  end
end

function cmake.select_configure_preset(callback)
  if not utils.has_active_job() then
    return
  end
  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return utils.error(result.message)
  end

  -- if exists presets
  local presets_file = presets.check()
  if presets_file then
    local configure_presets = presets.parse("configurePresets")
    vim.ui.select(configure_presets, { prompt = "Select cmake configure presets" },
      function(choice)
        if not choice then
          return
        end
        if config.configure_preset ~= choice then
          config.configure_preset = choice
          config.build_type = presets.get_build_type(
            presets.get_preset_by_name(choice, "configurePresets")
          )
        end
        if type(callback) == "function" then
          callback()
        end
      end)
  else
    utils.error("Cannot find CMake[User]Presets.json at Root!!")
  end
end

function cmake.select_build_preset(callback)
  if not utils.has_active_job() then
    return
  end
  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return utils.error(result.message)
  end

  -- if exists presets
  local presets_file = presets.check()
  if presets_file then
    local configure_presets = presets.parse("buildPresets")
    vim.ui.select(configure_presets, { prompt = "Select cmake build presets" },
      function(choice)
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
  else
    utils.error("Cannot find CMake[User]Presets.json at Root!!")
  end
end

function cmake.select_build_target(callback, not_regenerate)
  if not config.build_directory:exists() then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} }, function()
      vim.schedule(function()
        cmake.select_build_target(callback, false)
      end)
    end)
  end

  local targets_res = config:build_targets()

  if targets_res.code ~= Types.SUCCESS then
    -- try again
    if not_regenerate then
      return utils.error("CMake Configure Not Success!")
    else
      return cmake.generate({ bang = true, fargs = {} }, function()
        vim.schedule(function()
          cmake.select_build_target(callback, true)
        end)
      end)
    end
  end
  local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets
  vim.ui.select(display_targets, { prompt = "Select build target" }, function(_, idx)
    if not idx then
      return
    end
    config.build_target = targets[idx]
    if type(callback) == "function" then
      callback()
    end
  end)
end

function cmake.select_launch_target(callback, not_regenerate)
  if not config.build_directory:exists() then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} }, function()
      vim.schedule(function()
        cmake.select_launch_target(callback, false)
      end)
    end)
  end

  local targets_res = config:launch_targets()

  if targets_res.code ~= Types.SUCCESS then
    -- try again
    if not_regenerate then
      return utils.error("CMake Configure Not Success!")
    else
      return cmake.generate({ bang = true, fargs = {} }, function()
        vim.schedule(function()
          cmake.select_launch_target(callback, true)
        end)
      end)
    end
  end
  local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets

  vim.ui.select(display_targets, { prompt = "Select launch target" }, function(_, idx)
    if not idx then
      return
    end
    config.launch_target = targets[idx]
    if type(callback) == "function" then
      callback()
    end
  end)
end

return cmake
