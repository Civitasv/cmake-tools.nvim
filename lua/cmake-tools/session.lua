local osys = require("cmake-tools.osys")
local utils = require("cmake-tools.utils")
local log = require("cmake-tools.log")

local default_config
local migrated = false

---@param path string
---@return string
local function normalize(path)
  if osys.iswin32 then
    return (path:gsub("/", "\\"))
  end
  return path
end

local session_dir = normalize(vim.fn.stdpath("data") .. "/cmake_tools_nvim/")

local session = {}

--- Move a file, falling back to copy when rename cannot cross filesystems
---@param src string
---@param dst string
---@return boolean success
local function move_file(src, dst)
  if vim.fn.rename(src, dst) == 0 then
    return true
  end

  local input = io.open(src, "rb")
  if not input then
    return false
  end
  local contents = input:read("*a")
  input:close()

  local output = io.open(dst, "wb")
  if not output then
    return false
  end
  output:write(contents)
  output:close()

  return true
end

--- Migrate session files from the legacy cache directory to the new stdpath location
local function migrate_legacy_cache()
  -- TODO: this can be dropped after a grace period, maybe
  local old_dir
  if osys.iswin32 then
    old_dir = normalize(vim.fn.expand("~") .. "/AppData/Local/cmake_tools_nvim/")
  else
    old_dir = normalize(vim.fn.expand("~") .. "/.cache/cmake_tools_nvim/")
  end

  if not utils.file_exists(old_dir) then
    return
  end

  if not utils.file_exists(session_dir) then
    utils.mkdir(session_dir)
  end

  local failed = 0
  local files = vim.fn.glob(old_dir .. "*", false, true)
  for _, file in ipairs(files) do
    local filename = vim.fn.fnamemodify(normalize(file), ":t")
    local new_path = session_dir .. filename
    -- a file already present in the new location wins, the legacy one is dropped
    if utils.file_exists(new_path) or move_file(file, new_path) then
      vim.fn.delete(file)
    else
      failed = failed + 1
    end
  end

  if failed > 0 then
    log.warn(
      failed .. " session file(s) could not be moved from " .. old_dir .. " to " .. session_dir
    )
  end

  vim.fn.delete(old_dir, "d")
end

---@param cwd string neovim working directory
---@return string
local function get_current_path(cwd)
  local clean_path = cwd:gsub("/", "")
  clean_path = clean_path:gsub("\\", "")
  clean_path = clean_path:gsub(":", "")
  return session_dir .. clean_path .. ".lua"
end

local function init_cache()
  if not migrated then
    migrated = true
    migrate_legacy_cache()
  end

  if not utils.file_exists(session_dir) then
    utils.mkdir(session_dir)
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
  init_cache()

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

---@param const Const
function session.setup(const)
  local Config = require("cmake-tools.config")
  default_config = Config:new(const)
end

--- Build a table containing only the fields that differ from the defaults
---@param current table
---@param default table
---@return table|nil dirty only modified fields, or nil if none
local function get_dirty_fields(current, default)
  local dirty = {}
  for key, current_value in pairs(current) do
    local default_value = default[key]
    if type(current_value) == "table" and type(default_value) == "table" then
      local dirty_sub = get_dirty_fields(current_value, default_value)
      if dirty_sub then
        dirty[key] = dirty_sub
      end
    elseif current_value ~= default_value then
      dirty[key] = current_value
    end
  end
  return next(dirty) and dirty or nil
end

---@param cwd string neovim working directory (used as cache key)
---@param config Config current config to persist
function session.save(cwd, config)
  init_session(cwd)

  local path = get_current_path(cwd)
  local file = io.open(path, "w")

  local dirty_base_settings = get_dirty_fields(config.base_settings, default_config.base_settings)

  local current_build_dir = config:build_directory_path()
  local default_build_dir = default_config:build_directory_path()

  ---@class SerializedConfig
  local serialized_object = {
    build_directory = (current_build_dir ~= default_build_dir) and current_build_dir or nil,
    build_type = config.build_type,
    variant = config.variant,
    build_target = config.build_target,
    launch_target = config.launch_target,
    kit = config.kit,
    configure_preset = config.configure_preset,
    env_script = config.env_script,
    build_preset = config.build_preset,
    test_preset = config.test_preset,
    selected_test = config.selected_test,
    base_settings = dirty_base_settings,
    target_settings = config.target_settings,
    cwd = config.cwd,
  }

  if file then
    file:write(tostring("return " .. vim.inspect(serialized_object)))
    file:close()
  end
end

return session
