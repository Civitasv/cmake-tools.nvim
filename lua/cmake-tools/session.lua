local osys = require("cmake-tools.osys")
local utils = require("cmake-tools.utils")

local session = {
  dir = {
    unix = vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/",
    mac = vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/",
    win = vim.fn.expand("~") .. "/AppData/Local/cmake_tools_nvim/",
  },
}

local function get_cache_path()
  if osys.islinux then
    return session.dir.unix
  elseif osys.ismac then
    return session.dir.mac
  elseif osys.iswsl then
    return session.dir.unix
  elseif osys.isbsd then
    return session.dir.unix
  elseif osys.iswin32 then
    return session.dir.win
  end
end

local function get_current_path()
  local current_path = vim.loop.cwd()
  local clean_path = current_path:gsub("/", "")
  clean_path = clean_path:gsub("\\", "")
  clean_path = clean_path:gsub(":", "")
  return get_cache_path() .. clean_path .. ".lua"
end

local function init_cache()
  local cache_path = get_cache_path()
  if not utils.file_exists(cache_path) then
    utils.mkdir(cache_path)
  end
end

local function init_session()
  init_cache()

  local path = get_current_path()
  if not utils.file_exists(path) then
    local file = io.open(path, "w")
    if file then
      file:close()
    end
  end
end

function session.load()
  local path = get_current_path()

  if utils.file_exists(path) then
    local config = dofile(path)
    return config or {}
  end

  return {}
end

function session.update(config, old_config)
  if next(old_config) ~= nil then
    if old_config.build_directory and old_config.base_settings.build_dir then
      config:update_build_dir(old_config.build_directory, old_config.base_settings.build_dir)
    end
    if old_config.build_type then
      config.build_type = old_config.build_type
    end
    if old_config.variant then
      config.variant = old_config.variant
    end
    if old_config.build_target then
      config.build_target = old_config.build_target
    end
    if old_config.launch_target then
      config.launch_target = old_config.launch_target
    end
    if old_config.kit then
      config.kit = old_config.kit
    end
    if old_config.configure_preset then
      config.configure_preset = old_config.configure_preset
    end
    if old_config.build_preset then
      config.build_preset = old_config.build_preset
    end
    if old_config.env_script then
      config.env_script = old_config.env_script
    end
    if old_config.cwd then
      config.cwd = old_config.cwd
    end

    config.base_settings =
      vim.tbl_deep_extend("keep", old_config.base_settings, config.base_settings)
    config.target_settings = old_config.target_settings or {}

    -- migrate old launch args to new config
    if old_config.launch_args then
      for k, v in pairs(old_config.launch_args) do
        config.target_settings[k].args = v
      end
    end
  end
end

function session.save(config)
  init_session()

  local path = get_current_path()
  local file = io.open(path, "w")

  local serialized_object = {
    build_directory = config:build_directory_path(),
    build_type = config.build_type,
    variant = config.variant,
    build_target = config.build_target,
    launch_target = config.launch_target,
    kit = config.kit,
    configure_preset = config.configure_preset,
    env_script = config.env_script,
    build_preset = config.build_preset,
    base_settings = config.base_settings,
    target_settings = config.target_settings,
    cwd = config.cwd,
  }

  if file then
    file:write(tostring("return " .. vim.inspect(serialized_object)))
    file:close()
  end
end

return session
