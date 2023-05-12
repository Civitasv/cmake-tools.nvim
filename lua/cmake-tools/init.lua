-- cmake-tools's API
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

    local args = {
      "--preset",
      config.configure_preset,
    }
    vim.list_extend(args, config.generate_options)
    vim.list_extend(args, fargs)

    --[[ print(unpack(args)) ]]
    return utils.run(const.cmake_command, {}, args, {
      on_success = function()
        if type(callback) == "function" then
          callback()
        end
        cmake.configure_compile_commands()
      end,
      cmake_console_position = const.cmake_console_position,
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

  return utils.run(const.cmake_command, kit_option.env, args, {
    on_success = function()
      if type(callback) == "function" then
        callback()
      end
      cmake.configure_compile_commands()
    end,
    cmake_console_position = const.cmake_console_position,
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
    cmake_console_position = const.cmake_console_position,
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

  local experimental = 0
  if experimental == 1 then
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
      args = { "--build", "--preset", config.build_preset } -- preset don't need define build dir.
    else
      args = { "--build", config.build_directory.filename }
    end

    vim.list_extend(args, config.build_options)

    if config.build_target == "all" then
      vim.list_extend(args, { "--target", "all" })
      vim.list_extend(args, fargs)
    else
      vim.list_extend(args, { "--target", config.build_target })
      vim.list_extend(args, fargs)
    end

    return utils.run(const.cmake_command, {}, args, {
      on_success = function()
        if type(callback) == "function" then
          callback()
        end
      end,
      cmake_console_position = const.cmake_console_position,
      cmake_show_console = const.cmake_show_console,
      cmake_console_size = const.cmake_console_size
    })
  else
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
        args = { "--build", "--preset", config.build_preset } -- preset don't need define build dir.
      else
        args = { "--build", config.build_directory.filename }
      end

      vim.list_extend(args, config.build_options)

      if config.build_target == "all" then
        vim.list_extend(args, { "--target", "all" })
        vim.list_extend(args, fargs)
      else
        vim.list_extend(args, { "--target", config.build_target })
        vim.list_extend(args, fargs)
      end

      return utils.run(const.cmake_command, {}, args, {
        on_success = function()
          if type(callback) == "function" then
            callback()
          end
        end,
        cmake_console_position = const.cmake_console_position,
        cmake_show_console = const.cmake_show_console,
        cmake_console_size = const.cmake_console_size
      })
    end)
  end
end

--- Clean Rebuild: Clean the project and then Rebuild the target
--- [See dependancy discussion here]
function cmake.clean_rebuild(opt, callback)
  if not utils.has_active_job() then
    return
  end

  -- Check of project is configured
  if config.build_directory == nil then
    local fargs = fargs or opt.fargs
    return cmake.generate({opt = opt.bang , fargs = fargs }, function()
        cmake.clean_rebuild(opt, callback)
      end)
  end

  -- Check if build type is selected and loop back
  if config.build_type == nil then
    return cmake.select_build_type(function()
        cmake.clean_rebuild(opt, callback)
      end)
  end

  -- Check if build target is selected and loop back
  if config.build_target == nil then
    return cmake.select_build_target(function()
        cmake.clean_rebuild(opt, callback)
      end)
  end

  -- finally clean and build
  return cmake.clean(function()
    cmake.build(opt, callback)
  end)
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

  local args = { "--install", config.build_directory.filename }
  vim.list_extend(args, fargs)

  return utils.run(const.cmake_command, {}, args, {
    cmake_console_position = const.cmake_console_position,
    cmake_show_console     = const.cmake_show_console,
    cmake_console_size     = const.cmake_console_size
  })
end

--- CMake close cmake console
function cmake.close()
  utils.close_cmake_console()
end

--- CMake open cmake console
function cmake.open()
  utils.show_cmake_console(const.cmake_console_position, const.cmake_console_size)
end

local getPath = function(str,sep)
    sep=sep or'/'
    return str:match("(.*"..sep..")")
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
        -- print("TARGET", target_path)
        local target_path = result.data
        local is_win32 = vim.fn.has("win32")
        if (is_win32 == 1) then
          -- Prints the output in the same cmake window as in wsl/linux
          local new_s= getPath(target_path, '/')
          -- print(getPath(target_path,sep))
          return utils.execute(target_path, {
            bufname = vim.fn.expand("%:p"),
            cmake_launch_path = new_s,
            cmake_console_position = const.cmake_console_position,
            cmake_console_size = const.cmake_console_size
          })
        else
          -- print("target_path: " .. target_path)
          local new_s= getPath(target_path, '/')
          return utils.execute('"' .. target_path .. '"', {
            bufname = vim.fn.expand("%:t:r"),
            cmake_launch_path = new_s,
            cmake_console_position = const.cmake_console_position,
            cmake_console_size = const.cmake_console_size
          })
        end
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
          -- close cmake console
          cmake.close()
          dap.run(vim.tbl_extend("force", dap_config, const.cmake_dap_configuration))
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
    local configure_preset_names = presets.parse("configurePresets", { include_hidden = false })
    local configure_presets = presets.parse_name_mapped("configurePresets", { include_hidden = false })
    local format_preset_name = function(p_name)
      local p = configure_presets[p_name]
      return p.displayName or p.name
    end
    vim.ui.select(configure_preset_names,
      {
        prompt = "Select cmake configure presets",
        format_item = format_preset_name
      },
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
    local build_preset_names = presets.parse("buildPresets", { include_hidden = false })
    local build_presets = presets.parse_name_mapped("buildPresets", { include_hidden = false })
    local format_preset_name = function(p_name)
      local p = build_presets[p_name]
      return p.displayName or p.name
    end
    vim.ui.select(build_preset_names, { prompt = "Select cmake build presets", format_item = format_preset_name },
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
  if not (config.build_directory and config.build_directory:exists()) then
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
  if not (config.build_directory and config.build_directory:exists()) then
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

--[[ Getters ]]
function cmake.get_build_target()
  return config.build_target
end

function cmake.get_launch_target()
  return config.launch_target
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

function cmake.is_cmake_project()
  local result = utils.get_cmake_configuration()
  return result.code == Types.SUCCESS
end

function cmake.has_cmake_preset()
  local presets_file = presets.check()
  return presets_file ~= nil
end

function cmake.configure_compile_commands()
  if const.lsp_type == nil then
    if const.cmake_soft_link_compile_commands then
      cmake.compile_commands_from_soft_link()
    end
  else
    cmake.compile_commands_from_preset()
  end
end

function cmake.compile_commands_from_soft_link()
  if config.build_directory == nil or const.lsp_type ~= nil then return end

  local source = config.build_directory.filename .. "/compile_commands.json"
  local destination = vim.loop.cwd() .. "/compile_commands.json"
  if utils.file_exists(source) then
    utils.softlink(source, destination)
  end
end

function cmake.compile_commands_from_preset()
  if config.build_directory == nil or const.lsp_type == nil then return end

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
      v = arg
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

-- preload the autocmd if the following option is true. only saves cmakelists.txt files
if const.cmake_regenerate_on_save == true then
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("cmaketools", {clear = true}),
    pattern  = "CMakeLists.txt",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()

      -- TODO: do some logic here to check if buffer is actually modified, and only if it is modified,
      -- execute the generate, otherwise return. This is to avoid unnecessary regenerattion
      local buf_modified  = vim.api.nvim_buf_get_option(buf, 'modified')
      -- print("buf_modified: " .. utils.dump(buf_modified))
      -- if not vim.api.nvim_buf_get_option(buf, "modified") then
      --   return
      -- end

      vim.schedule(
        function()
          cmake.generate({ bang = false, fargs = {} },
            function()
              -- no function here
            end)
        end)
      -- print("buffer is not modified... not saving!")
    end,
  })
end

return cmake
