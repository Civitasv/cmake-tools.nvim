local osys = require("cmake-tools.osys")
local utils = require("cmake-tools.utils")

local session = {
  dir = {
    unix = vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/",
    mac = vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/",
    win = vim.fn.expand("~") .. "/AppData/Local/cmake_tools_nvim/",
  },
}

---@return string
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

---@param cwd string neovim working directory
---@return string
local function get_current_path(cwd)
  local clean_path = cwd:gsub("/", "")
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

---@param cwd string neovim working directory
local function init_session(cwd)
  init_cache()

  local path = get_current_path(cwd)
  if not utils.file_exists(path) then
    local file = io.open(path, "w")
    if file then
      file:close()
    end
  end
end

---@param cwd string neovim working directory (used as cache key)
---@return SerializedConfig raw session data, or empty table if none exists
function session.load(cwd)
  local path = get_current_path(cwd)

  if utils.file_exists(path) then
    local config = dofile(path)
    return config or {}
  end

  return {}
end

---@param config Config
---@param old_config SerializedConfig
---@return Config merged config with session state applied
function session.update(config, old_config)
  if next(old_config) == nil then
    return config
  end

  local mt = getmetatable(config)
  local build_directory = old_config.build_directory
  local old_build_dir = old_config.base_settings and old_config.base_settings.build_dir
  old_config.build_directory = nil

  config = vim.tbl_deep_extend("force", config, old_config)
  setmetatable(config, mt)

  if build_directory and old_build_dir then
    config:update_build_dir(build_directory, old_build_dir)
  end

  return config
end

---@param cwd string neovim working directory (used as cache key)
---@param config Config current config to persist
function session.save(cwd, config)
  init_session(cwd)

  local path = get_current_path(cwd)
  local file = io.open(path, "w")

  ---@class SerializedConfig
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
    selected_test = config.selected_test,
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
