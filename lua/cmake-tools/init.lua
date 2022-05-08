--- cmake-tools's API

local dap = require("dap")
local utils = require("cmake-tools.utils")
local ErrorTypes, SuccessTypes = require("cmake-tools.types")()
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
  if not result.code == SuccessTypes.SUCCESS then
    return utils.error(result.message)
  end

  local clean = opt.bang
  local fargs = opt.fargs or {}
  if clean then
    return cmake.clean(function()
      cmake.generate(opt, callback)
    end)
  end

  config:generate_build_directory()

  vim.list_extend(fargs, {
    "-B",
    config.build_directory.filename,
    "-D",
    "CMAKE_BUILD_TYPE=" .. config.build_type,
    unpack(config.generate_options),
  })
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
  print("BUILD")

  local fargs = opt.fargs or {}

  if not config.build_directory:is_dir() then
    -- configure it
    return cmake.configure({ clean = false, fargs = {} }, function()
      vim.schedule(function()
        cmake.build(opt, callback)
      end)
    end)
  end
  print("TARGET", config.build_target)

  if not config.build_target then
    return vim.schedule(function()
      cmake.select_build_target(function()
        vim.schedule(function()
          cmake.build(opt, callback)
        end)
      end)
    end)
  end

  if config.build_target == "all" then
    vim.list_extend(fargs, {
      "--build",
      config.build_directory.filename,
      unpack(config.build_options),
    })
  else
    vim.list_extend(fargs, {
      "--build",
      config.build_directory.filename,
      "--target",
      config.build_target,
      unpack(config.build_options),
    })
  end
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
    utils.error("No running process")
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

  local result = config:launch_target()
  local result_code = result.code
  if result_code == ErrorTypes.NOT_CONFIGURED then
    -- Configure it
    return cmake.generate({ clean = false }, function()
      cmake.run(opt, callback)
    end)
  elseif
    result_code == ErrorTypes.NOT_SELECT_LAUNCH_TARGET
    or result_code == ErrorTypes.NOT_A_LAUNCH_TARGET
    or result_code == ErrorTypes.NOT_EXECUTABLE
  then
    -- Re Select a target that could launch
    return cmake.select_launch_target(function()
      vim.schedule(function()
        cmake.run(opt, callback)
      end)
    end)
  elseif result_code == ErrorTypes.SELECTED_LAUNCH_TARGET_NOT_BUILT then
    -- Build select launch target
    config.build_target = config.launch_target
    config:write()
    return cmake.build({}, function()
      vim.schedule(function()
        cmake.run(opt, callback)
      end)
    end)
  end

  local target_path = result.data

  return utils.execute(target_path.filename, { bufname = vim.fn.expand("%:t:r") })
end

-- Debug execuable targets
function cmake.debug(opt, callback)
  if not utils.ensure_no_job_active() then
    return
  end

  local can_debug_result = config:validate_for_debugging()
  if not can_debug_result.code == SuccessTypes.SUCCESS then
    -- Select build type to debug
    return cmake.select_build_type(function()
      cmake.debug(opt, callback)
    end)
  end

  local result = config:launch_target()
  local result_code = result.code

  if result_code == ErrorTypes.NOT_CONFIGURED then
    -- Configure it
    return cmake.generate({ clean = false }, function()
      cmake.debug(opt, callback)
    end)
  elseif
    result_code == ErrorTypes.NOT_SELECT_LAUNCH_TARGET
    or result_code == ErrorTypes.NOT_A_LAUNCH_TARGET
    or result_code == ErrorTypes.NOT_EXECUTABLE
  then
    -- Re Select a target that could launch
    return cmake.select_launch_target(function()
      vim.schedule(function()
        cmake.debug(opt, callback)
      end)
    end)
  elseif result_code == ErrorTypes.SELECTED_LAUNCH_TARGET_NOT_BUILT then
    -- Build select launch target
    config.build_target = config.launch_target
    config:write()
    return cmake.build({}, function()
      vim.schedule(function()
        cmake.debug(opt, callback)
      end)
    end)
  end

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
    config:write()
    if type(callback) == "function" then
      callback()
    end
  end)
end

function cmake.select_build_target(callback)
  if not config.build_directory:is_dir() then
    utils.error("You need to configure first")
    return
  end

  local targets, display_targets = config:build_targets()
  vim.ui.select(display_targets, { prompt = "Select build target" }, function(_, idx)
    if not idx then
      return
    end
    config.build_target = targets[idx]
    config:write()
    if type(callback) == "function" then
      callback()
    end
  end)
end

function cmake.select_launch_target(callback)
  if not config.build_directory:is_dir() then
    utils.error("You need to configure first")
    return
  end

  local targets, display_targets = config:launch_targets()
  vim.ui.select(display_targets, { prompt = "Select launch target" }, function(_, idx)
    if not idx then
      return
    end
    config.launch_target = targets[idx]
    config:write()
    if type(callback) == "function" then
      callback()
    end
  end)
end

return cmake
