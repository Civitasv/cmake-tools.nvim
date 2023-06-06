-- cmake-tools's API
local has_nvim_dap, dap = pcall(require, "dap")
local utils = require("cmake-tools.utils")
local Types = require("cmake-tools.types")
local const = require("cmake-tools.const")
local Config = require("cmake-tools.config")
local variants = require("cmake-tools.variants")
local kits = require("cmake-tools.kits")
local presets = require("cmake-tools.presets")
local log = require("cmake-tools.log")
local osys = require("cmake-tools.osys")

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
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local clean = opt.bang
  local fargs = opt.fargs or {}
  if clean then
    return cmake.clean(
      function()
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
    return cmake.select_configure_preset(
      function()
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
        cmake.configure_compile_commands(const.cmake_always_use_terminal, const.cmake_terminal_opts)
      end,
      cmake_launch_path = vim.loop.cwd(),
      cmake_always_use_terminal = const.cmake_always_use_terminal,
      cmake_quickfix_opts = const.cmake_quickfix_opts,
      cmake_terminal_opts = const.cmake_terminal_opts
    })
  end

  -- if exists cmake-kits.json, kit is used to set
  -- environmental variables and args.
  local kits_config = kits.parse(const.cmake_kits_path)
  if kits_config and not config.kit then
    return cmake.select_kit(
      function()
        cmake.generate(opt, callback)
      end)
  end

  -- specify build type, if exists cmake-variants.json,
  -- this will get build variant from it. Or this will
  -- get build variant from "Debug, Release, RelWithDebInfo, MinSizeRel"
  if not config.build_type then
    return cmake.select_build_type(
      function()
        cmake.generate(opt, callback)
      end)
  end

  -- cmake kits, if cmake-kits.json doesn't exist, kit_option will
  -- be {env={}, args={}}, so it's okay.
  local kit_option = kits.build_env_and_args(
    config.kit,
    const.cmake_always_use_terminal)

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
      cmake.configure_compile_commands(const.cmake_always_use_terminal, const.cmake_terminal_opts)
    end,
    cmake_launch_path = vim.loop.cwd(),
    cmake_always_use_terminal = const.cmake_always_use_terminal,
    cmake_quickfix_opts = const.cmake_quickfix_opts,
    cmake_terminal_opts = const.cmake_terminal_opts
  })
end

--- Clean targets
function cmake.clean(callback)
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local args = { "--build", config.build_directory.filename, "--target", "clean" }

  return utils.run(const.cmake_command, {}, args, {
    on_success = function()
      if type(callback) == "function" then
        callback()
      end
    end,
    cmake_launch_path = vim.loop.cwd(),
    cmake_always_use_terminal = const.cmake_always_use_terminal,
    cmake_quickfix_opts = const.cmake_quickfix_opts,
    cmake_terminal_opts = const.cmake_terminal_opts
  })
end

--- Build this project using the make toolchain of target platform
--- think it as `cmake --build .`
function cmake.build(opt, callback)
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local clean = opt.bang
  local fargs = opt.fargs or {}
  if clean then
    return cmake.clean(
      function()
        cmake.build({ fargs = fargs }, callback)
      end)
  end

  if not (config.build_directory and config.build_directory:exists()) then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} },
      function()
        cmake.build(opt, callback)
      end)
  end

  if config.build_target == nil then
    return cmake.select_build_target(
      function()
        cmake.build(opt, callback)
      end), false
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
    cmake_launch_path = vim.loop.cwd(),
    cmake_always_use_terminal = const.cmake_always_use_terminal,
    cmake_quickfix_opts = const.cmake_quickfix_opts,
    cmake_terminal_opts = const.cmake_terminal_opts
  })
end

function cmake.stop()
  if not utils.job or utils.job.is_shutdown then
    log.error("CMake Tools isn't running")
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
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
    return
  end

  local result = utils.get_cmake_configuration()
  if result.code ~= Types.SUCCESS then
    return log.error(result.message)
  end

  local fargs = opt.fargs

  local args = { "--install", config.build_directory.filename }
  vim.list_extend(args, fargs)

  return utils.run(const.cmake_command, {}, args, {
    cmake_launch_path         = vim.loop.cwd(),
    cmake_always_use_terminal = const.cmake_always_use_terminal,
    cmake_quickfix_opts       = const.cmake_quickfix_opts,
    cmake_terminal_opts       = const.cmake_terminal_opts
  })
end

--- CMake close cmake console
function cmake.close()
  utils.close_cmake_window()
end

--- CMake open cmake console
function cmake.open()
  utils.show_cmake_window(const.cmake_always_use_terminal, const.cmake_quickfix_opts, const.cmake_terminal_opts)
end

-- Run executable targets
function cmake.run(opt, callback)
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
    return
  end

  local result = config:get_launch_target()
  local result_code = result.code
  -- print(Types[result_code])
  if result_code == Types.NOT_CONFIGURED or result_code == Types.CANNOT_FIND_CODEMODEL_FILE then
    -- Configure it
    return cmake.generate({ bang = false, fargs = utils.deepcopy(opt.fargs) },
      function()
        cmake.run(opt, callback)
      end)
  elseif result_code == Types.NOT_SELECT_LAUNCH_TARGET
      or result_code == Types.NOT_A_LAUNCH_TARGET
      or result_code == Types.NOT_EXECUTABLE
  then
    -- Re Select a target that could launch
    return cmake.select_launch_target(
      function()
        cmake.run(opt, callback)
      end), false
  else -- if result_code == Types.SELECTED_LAUNCH_TARGET_NOT_BUILT
    -- Build select launch target every time
    config.build_target = config.launch_target
    return cmake.build({ fargs = utils.deepcopy(opt.fargs) },
      function()
        result = config:get_launch_target()
        local target_path = result.data
        local launch_path = vim.fn.fnamemodify(target_path, ":h")

        return utils.execute(target_path, {
          cmake_launch_path = launch_path,
          cmake_launch_args = cmake:get_launch_args(),
          cmake_always_use_terminal = const.cmake_always_use_terminal,
          cmake_quickfix_opts = const.cmake_quickfix_opts,
          cmake_terminal_opts = const.cmake_terminal_opts
        })
      end
    )
  end
end

-- Set args for launch target
function cmake.launch_args(opt)
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
    return
  end

  if (cmake.get_launch_target() ~= nil) then
    config.launch_args[cmake.get_launch_target()] = utils.deepcopy(opt.fargs);
  end
end

if has_nvim_dap then
  -- Debug execuable targets
  function cmake.debug(opt, callback)
    if utils.has_active_job(
      const.cmake_always_use_terminal
    ) then
      return
    end

    local can_debug_result = config:validate_for_debugging()
    if can_debug_result.code == Types.CANNOT_DEBUG_LAUNCH_TARGET then
      -- Select build type to debug
      return cmake.select_build_type(
        function()
          cmake.debug(opt, callback)
        end)
    end

    local result = config:get_launch_target()
    local result_code = result.code

    if result_code == Types.NOT_CONFIGURED or result_code == Types.CANNOT_FIND_CODEMODEL_FILE then
      -- Configure it
      return cmake.generate({ bang = false, fargs = utils.deepcopy(opt.fargs) },
        function()
          cmake.debug(opt, callback)
        end)
    elseif result_code == Types.NOT_SELECT_LAUNCH_TARGET
        or result_code == Types.NOT_A_LAUNCH_TARGET
        or result_code == Types.NOT_EXECUTABLE
    then
      -- Re Select a target that could launch
      return cmake.select_launch_target(
        function()
          cmake.debug(opt, callback)
        end), false
    else -- if result_code == Types.SELECTED_LAUNCH_TARGET_NOT_BUILT then
      -- Build select launch target every time
      config.build_target = config.launch_target
      return cmake.build({ fargs = utils.deepcopy(opt.fargs) },
        function()
          result = config:get_launch_target()
          local target_path = result.data
          local dap_config = {
            name = config.launch_target,
            program = target_path,
            cwd = utils.get_path(result.data, "/"),
            args = cmake:get_launch_args(),
          }
          -- close cmake console
          cmake.close()
          dap.run(vim.tbl_extend("force", dap_config, const.cmake_dap_configuration))
        end)
    end
  end
end

function cmake.select_build_type(callback)
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
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

  vim.ui.select(types, { prompt = "Select build type" },
    vim.schedule_wrap(
      function(build_type)
        if not build_type then
          return
        end
        if config.build_type ~= build_type then
          config.build_type = build_type
          if type(callback) == "function" then
            callback()
          end
        end
      end
    )
  )
end

function cmake.select_kit(callback)
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
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

    vim.ui.select(cmake_kits, { prompt = "Select cmake kits" },
      vim.schedule_wrap(
        function(kit)
          if not kit then
            return
          end
          if config.kit ~= kit then
            config.kit = kit
          end
          if type(callback) == "function" then
            callback()
          end
        end
      )
    )
  else
    log.error("Cannot find CMakeKits.[json|yaml] at Root!!")
  end
end

function cmake.select_configure_preset(callback)
  if utils.has_active_job(
    const.cmake_always_use_terminal
  ) then
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
      vim.schedule_wrap(
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
        end
      )
    )
  else
    log.error("Cannot find CMake[User]Presets.json at Root!!")
  end
end

function cmake.select_build_preset(callback)
  if not utils.has_avtive_job(
    const.cmake_always_use_terminal,
    const.cmake_terminal_opts
  ) then
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
    vim.ui.select(build_preset_names, { prompt = "Select cmake build presets", format_item = format_preset_name },
      vim.schedule_wrap(
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
        end
      )
    )
  else
    log.error("Cannot find CMake[User]Presets.json at Root!!")
  end
end

function cmake.select_build_target(callback, not_regenerate)
  if not (config.build_directory and config.build_directory:exists()) then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} },
      function()
        cmake.select_build_target(callback, false)
      end)
  end

  local targets_res = config:build_targets()

  if targets_res.code ~= Types.SUCCESS then
    -- try again
    if not_regenerate then
      return log.error("CMake Configure Not Success!")
    else
      return cmake.generate({ bang = true, fargs = {} },
        function()
          cmake.select_build_target(callback, true)
        end)
    end
  end
  local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets
  vim.ui.select(display_targets, { prompt = "Select build target" },
    vim.schedule_wrap(
      function(_, idx)
        if not idx then
          return
        end
        config.build_target = targets[idx]
        if type(callback) == "function" then
          callback()
        end
      end
    )
  )
end

function cmake.select_launch_target(callback, not_regenerate)
  if not (config.build_directory and config.build_directory:exists()) then
    -- configure it
    return cmake.generate({ bang = false, fargs = {} },
      function()
        cmake.select_launch_target(callback, false)
      end)
  end

  local targets_res = config:launch_targets()

  if targets_res.code ~= Types.SUCCESS then
    -- try again
    if not_regenerate then
      return log.error("CMake Configure Not Success!")
    else
      return cmake.generate({ bang = true, fargs = {} },
        function()
          cmake.select_launch_target(callback, true)
        end)
    end
  end
  local targets, display_targets = targets_res.data.targets, targets_res.data.display_targets

  vim.ui.select(display_targets, { prompt = "Select launch target" },
    vim.schedule_wrap(
      function(_, idx)
        if not idx then
          return
        end
        config.launch_target = targets[idx]
        if type(callback) == "function" then
          callback()
        end
      end
    )
  )
end

--[[ Getters ]]

function cmake.get_build_target()
  return config.build_target
end

function cmake.get_launch_target()
  return config.launch_target
end

function cmake.get_launch_args()
  if (cmake.get_launch_target() == nil) then
    return nil
  end
  return config.launch_args[cmake.get_launch_target()]
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

--[[ end ]]

function cmake.configure_compile_commands(cmake_always_use_terminal, cmake_terminal_opts)
  if const.cmake_soft_link_compile_commands then
    cmake.compile_commands_from_soft_link(cmake_always_use_terminal, cmake_terminal_opts)
  elseif const.cmake_compile_commands_from_lsp then
    cmake.compile_commands_from_lsp()
  end
end

function cmake.compile_commands_from_soft_link(cmake_always_use_terminal, cmake_terminal_opts)
  if config.build_directory == nil then return end

  local source = vim.loop.cwd() .. "/" .. config.build_directory.filename .. "/compile_commands.json"
  local destination = vim.loop.cwd() .. "/compile_commands.json"
  if cmake_always_use_terminal or utils.file_exists(source) then
    utils.softlink(source, destination, {
      cmake_launch_path = vim.loop.cwd(),
      cmake_always_use_terminal = cmake_always_use_terminal,
      cmake_terminal_opts = cmake_terminal_opts
    })
  end
end

function cmake.compile_commands_from_lsp()
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
  vim.api.nvim_create_autocmd("BufWritePre", {
    group    = vim.api.nvim_create_augroup("cmaketools", { clear = true }),
    pattern  = "CMakeLists.txt",
    callback = function()
      local buf          = vim.api.nvim_get_current_buf()
      -- Check if buffer is actually modified, and only if it is modified,
      -- execute the :CMakeGenerate, otherwise return. This is to avoid unnecessary regenerattion
      local buf_modified = vim.api.nvim_buf_get_option(buf, "modified")
      if buf_modified then
        cmake.generate({ bang = false, fargs = {} },
          function()
            -- no function here
          end)
      end
      -- print("buffer is not modified... not saving!")
    end,
  })
end

-- For win32, we have a command to escape insert mode after proccess extis
-- because, we want to scroll the buffer output after completion of execution
if osys.is_win32 then
  vim.api.nvim_create_autocmd("TermClose", {
    group    = "cmake_tools",
    callback = function()
      vim.cmd.stopinsert()
      vim.api.nvim_feedkeys("<C-\\><C-n><CR>", "n", false)
    end
  })
end

return cmake
