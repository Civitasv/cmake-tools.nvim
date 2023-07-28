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
  elseif osys.iswin32 then
    return session.dir.win
  end
end

local function get_current_path()
  local current_path = vim.loop.cwd()
  local clean_path = current_path:gsub("/", "")
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
    os.execute("touch " .. path)
  end
end

function session.load()
  local path = get_current_path()

  if utils.file_exists(path) then
    local config = dofile(path)
    return config
  end

  init_session()
  return {}
end

function session.save(config)
  local path = get_current_path()
  local file = io.open(path, "w")

  local serialized_object = {
    build_directory = config.build_directory and config.build_directory.filename or "",
    query_directory = config.build_directory and config.query_directory.filename or "",
    reply_directory = config.build_directory and config.reply_directory.filename or "",
    generate_options = config.generate_options,
    build_options = config.build_options,
    build_type = config.build_type,
    build_target = config.build_target,
    launch_target = config.launch_target,
    launch_args = config.launch_args,
    kit = config.kit,
    configure_preset = config.configure_preset,
    build_preset = config.build_preset,
  }

  if file then
    file:write(tostring("return " .. vim.inspect(serialized_object)))
    file:close()
  end
end

return session
