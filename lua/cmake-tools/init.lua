--- cmake-tools's API
local has_nvim_dap, dap = pcall(require, "dap")
local utils = require("cmake-tools.utils")
local Types = require("cmake-tools.types")
local const = require("cmake-tools.const")
local Config = require("cmake-tools.config")

local config = Config:new()

local cmake = {}

--- Setup cmake-tools
function cmake.setup(values)
  setmetatable(const, { __index = vim.tbl_extend("force", const, values) })
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

  -- print(clean, dump(fargs))
  -- print(config.build_directory.filename)
  config:generate_build_directory()

  vim.list_extend(fargs, {
    "-B",
    config.build_directory.filename,
    "-D",
    "CMAKE_BUILD_TYPE=" .. config.build_type,
    unpack(config.generate_options),
  })
  -- print(dump(config.generate_options))
  return utils.run(const.cmake_command, fargs, {
    on_success = function()
      if type(callback) == "function" then
        callback()
      end
    end,
  })
end

--- Clean targets
function cmake.clean(callback)
  if not utils.has_active_job() then
    return
  end

  local args = { "--build", config.build_directory.filename, "--target", "clean" }
  -- print(dump(args))
  return utils.run(const.cmake_command, args, {
    on_success = function()
      if type(callback) == "function" then
        callback()
      end
    end,
  })
end

--- Build this project using the make toolchain of target platform
--- think it as `cmake --build .`
function cmake.build(opt, callback)
  if not utils.has_active_job() then
    return
  end
  -- print("BUILD")

  local fargs = opt.fargs or {}

  if not config.build_directory:exists() then
    -- configure it
    return cmake.generate({ clean = false, fargs = {} }, function()
      vim.schedule(function()
        cmake.build(opt, callback)
      end)
    end)
  end
  -- print("TARGET", config.build_target)

  if config.build_target == nil then
    return vim.schedule(function()
      cmake.select_build_target(function()
        vim.schedule(function()
          cmake.build(opt, callback)
        end)
      end, false)
    end)
  end

  if config.build_target == "all" then
    vim.list_extend(fargs, {
      "--build",
      config.build_directory.filename,
      unpack(config.build_options),
    })
  else
    -- print(config.build_target)
    vim.list_extend(fargs, {
      "--build",
      config.build_directory.filename,
      "--target",
      config.build_target,
      unpack(config.build_options),
    })
  end
  -- print(utils.dump(fargs))
  return utils.run(const.cmake_command, fargs, {
    on_success = function()
      if type(callback) == "function" then
        callback()
      end
    end,
  })
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

  local fargs = opt.fargs

  vim.list_extend(fargs, { "--install", config.build_directory.filename })
  return utils.run(const.cmake_command, fargs)
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
    return cmake.generate({ clean = false, fargs = utils.deepcopy(opt.fargs) }, function()
      cmake.run(opt, callback)
    end)
  elseif
    result_code == Types.NOT_SELECT_LAUNCH_TARGET
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

        return utils.execute(target_path, { bufname = vim.fn.expand("%:t:r") })
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
      return cmake.generate({ clean = false, fargs = utils.deepcopy(opt.fargs) }, function()
        cmake.debug(opt, callback)
      end)
    elseif
      result_code == Types.NOT_SELECT_LAUNCH_TARGET
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
  -- Put selected build type first
  local types = { "Debug", "Release", "RelWithDebInfo", "MinSizeRel" }
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
    config.build_type = build_type
    if type(callback) == "function" then
      callback()
    end
  end)
end

function cmake.select_build_target(callback, not_regenerate)
  if not config.build_directory:exists() then
    -- configure it
    return cmake.generate({ clean = false, fargs = {} }, function()
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
      return cmake.generate({ clean = true, fargs = {} }, function()
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
    return cmake.generate({ clean = false, fargs = {} }, function()
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
      return cmake.generate({ clean = true, fargs = {} }, function()
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
