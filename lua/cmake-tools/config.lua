local Path = require("plenary.path")
local scandir = require("plenary.scandir")
local Result = require("cmake-tools.result")
-- local utils = require("cmake-tools.utils") -- Fails lua check. Uncomment this for testing
local Types = require("cmake-tools.types")
local variants = require("cmake-tools.variants")

local Config = {
  build_directory = nil,
  query_directory = nil,
  reply_directory = nil,
  generate_options = {},
  build_options = {},
  build_type = nil,
  build_target = nil,
  launch_target = nil,
  kit = nil,
  configure_preset = nil,
  build_preset = nil,
  base_settings = nil, -- general config
  target_settings = {}, -- target specific config
  executor = nil,
  terminal = nil,
  always_use_terminal = false,
}

function Config:new(const)
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  self.generate_options = const.cmake_generate_options
  self.build_options = const.cmake_build_options
  self.executor = const.cmake_executor
  self.terminal = const.cmake_terminal
  self.always_use_terminal = self.executor.name == "terminal"

  return self
end

function Config:update_build_dir(build_dir)
  self.build_directory = Path:new(build_dir)
  self.query_directory = Path:new(build_dir, ".cmake", "api", "v1", "query")
  self.reply_directory = Path:new(build_dir, ".cmake", "api", "v1", "reply")
end

function Config:generate_build_directory()
  local build_directory = Path:new(vim.loop.cwd(), self.build_directory)

  if not build_directory:mkdir({ parents = true }) then
    return Result:new(Types.CANNOT_CREATE_DIRECTORY, false, "cannot create directory")
  end
  return self:generate_query_files()
end

function Config:generate_query_files()
  local query_directory = Path:new(vim.loop.cwd(), self.query_directory)
  if not query_directory:mkdir({ parents = true }) then
    return Result:new(Types.CANNOT_CREATE_DIRECTORY, false, "cannot create directory")
  end

  local codemodel_file = query_directory / "codemodel-v2"
  if not codemodel_file:is_file() then
    if not codemodel_file:touch() then
      return Result:new(
        Types.CANNOT_CREATE_CODEMODEL_QUERY_FILE,
        nil,
        "Unable to create file " .. codemodel_file.filename
      )
    end
  end

  local cmakeFiles_file = query_directory / "cmakeFiles-v1"
  if not cmakeFiles_file:is_file() then
    if not cmakeFiles_file:touch() then
      return Result:new(
        Types.CANNOT_CREATE_CODEMODEL_QUERY_FILE,
        nil,
        "Unable to create file " .. cmakeFiles_file.filename
      )
    end
  end

  return Result:new(Types.SUCCESS, true, "yeah, that could be")
end

function Config:get_cmake_files()
  -- if reply_directory exists
  local reply_directory = Path:new(vim.loop.cwd(), self.reply_directory)
  if not reply_directory:exists() then
    return Result:new(Types.NOT_CONFIGURED, nil, "Configure fail")
  end

  local found_files = scandir.scan_dir(reply_directory.filename, { search_pattern = "cmakeFiles*" })
  if #found_files == 0 then
    return Result:new(Types.CANNOT_FIND_CODEMODEL_FILE, nil, "Unable to find codemodel file")
  end
  local codemodel = Path:new(found_files[1])
  local codemodel_json = vim.json.decode(codemodel:read())
  return Result:new(Types.SUCCESS, codemodel_json["inputs"], "find it")
end

function Config:get_codemodel_targets()
  -- if reply_directory exists
  local reply_directory = Path:new(vim.loop.cwd(), self.reply_directory)
  if not reply_directory:exists() then
    return Result:new(Types.NOT_CONFIGURED, nil, "Configure fail")
  end

  local found_files = scandir.scan_dir(reply_directory.filename, { search_pattern = "codemodel*" })
  if #found_files == 0 then
    return Result:new(Types.CANNOT_FIND_CODEMODEL_FILE, nil, "Unable to find codemodel file")
  end
  local codemodel = Path:new(found_files[1])
  local codemodel_json = vim.json.decode(codemodel:read())
  return Result:new(Types.SUCCESS, codemodel_json["configurations"][1]["targets"], "find it")
end

function Config:get_code_model_target_info(codemodel_target)
  local reply_directory = Path:new(vim.loop.cwd(), self.reply_directory)
  return vim.json.decode((reply_directory / codemodel_target["jsonFile"]):read())
end

-- Check if launch target is built
function Config:check_launch_target()
  -- 1. not configured
  local build_directory = Path:new(vim.loop.cwd(), self.build_directory)
  if not build_directory:exists() then
    return Result:new(Types.NOT_CONFIGURED, nil, "You need to configure it first")
  end

  -- 2. not select launch target yet
  if not self.launch_target then
    return Result:new(Types.NOT_SELECT_LAUNCH_TARGET, nil, "You need to select launch target first")
  end

  local codemodel_targets = self:get_codemodel_targets()
  if codemodel_targets.code ~= Types.SUCCESS then
    return codemodel_targets
  end
  codemodel_targets = codemodel_targets.data

  for _, target in ipairs(codemodel_targets) do
    if self.launch_target == target["name"] then
      local target_info = self:get_code_model_target_info(target)
      local type = target_info["type"]:lower():gsub("_", " ")
      if type ~= "executable" then
        -- 3. selected target cannot execute
        return Result:new(Types.NOT_EXECUTABLE, nil, "You need to select a executable target")
      end
      return Result:new(Types.SUCCESS, target_info, "Success")
    end
  end

  return Result:new(
    Types.NOT_A_LAUNCH_TARGET,
    nil,
    "Unable to find the following target: " .. self.launch_target
  )
end

function Config:get_launch_target_from_info(target_info)
  local target_path = target_info["artifacts"][1]["path"]
  target_path = Path:new(target_path)
  if not target_path:is_absolute() then
    -- then it is a relative path, based on build directory
    local build_directory = Path:new(vim.loop.cwd(), self.build_directory)
    target_path = build_directory / target_path
  end
  -- else it is an absolute path

  if not target_path:is_file() then
    return Result:new(
      Types.SELECTED_LAUNCH_TARGET_NOT_BUILT,
      target_path.filename,
      "Selected target is not built: " .. target_path.filename
    )
  end

  return Result:new(Types.SUCCESS, target_path.filename, "yeah, that's good")
end

-- Retrieve launch target path: self.launch_target
-- it will first check if this launch target is built
function Config:get_launch_target()
  local check_result = self:check_launch_target()
  if check_result.code ~= Types.SUCCESS then
    return check_result
  end
  local target_info = check_result.data

  return Config:get_launch_target_from_info(target_info)
end

-- Check if build target exists
function Config:check_build_target()
  -- 1. not configured
  local build_directory = Path:new(vim.loop.cwd(), self.build_directory)
  if not build_directory:exists() then
    return Result:new(Types.NOT_CONFIGURED, nil, "You need to configure it first")
  end

  -- 2. not select build target yet
  if not self.build_target then
    return Result:new(Types.NOT_SELECT_BUILD_TARGET, nil, "You need to select Build target first")
  end

  local codemodel_targets = self:get_codemodel_targets()
  if codemodel_targets.code ~= Types.SUCCESS then
    return codemodel_targets
  end
  codemodel_targets = codemodel_targets.data

  for _, target in ipairs(codemodel_targets) do
    if self.build_target == target["name"] then
      local target_info = self:get_code_model_target_info(target)
      -- local type = target_info["type"]:lower():gsub("_", " ")
      return Result:new(Types.SUCCESS, target_info, "Success")
    end
  end

  return Result:new(
    Types.NOT_A_BUILD_TARGET,
    nil,
    "Unable to find the following target: " .. self.build_target
  )
end

-- Retrieve launch target path: self.launch_target
-- it will first check if this launch target is built
function Config:get_build_target()
  local check_result = self:check_build_target()
  if check_result.code ~= Types.SUCCESS then
    return check_result
  end
  local target_info = check_result.data
  local target_path = target_info["artifacts"][1]["path"]
  target_path = Path:new(target_path)
  if not target_path:is_absolute() then
    -- then it is a relative path, based on build directory
    local build_directory = Path:new(vim.loop.cwd(), self.build_directory)
    target_path = build_directory / target_path
  end
  -- else it is an absolute path

  if not target_path:is_file() then
    return Result:new(
      Types.SELECTED_LAUNCH_TARGET_NOT_BUILT,
      nil,
      "Selected target is not built: " .. target_path.filename
    )
  end

  return Result:new(Types.SUCCESS, target_path.filename, "yeah, that's good")
end

-- Check if this launch target is debuggable
-- use variants.debuggable
function Config:validate_for_debugging()
  local build_type = self.build_type

  if not build_type or not variants.debuggable(build_type) then
    return Result:new(Types.CANNOT_DEBUG_LAUNCH_TARGET, false, "cannot debug it")
  end
  return Result:new(Types.SUCCESS, true, "Yeah, it may be")
end

local function get_targets(config, opt)
  local targets, display_targets, paths, abs_paths = {}, {}, {}, {}
  if opt.has_all then
    table.insert(targets, "all")
    table.insert(display_targets, "all")
  end
  local codemodel_targets = config:get_codemodel_targets()
  if codemodel_targets.code ~= Types.SUCCESS then
    return codemodel_targets
  end

  codemodel_targets = codemodel_targets.data
  for _, target in ipairs(codemodel_targets) do
    local target_info = config:get_code_model_target_info(target)
    local target_name = target_info["name"]
    local target_name_on_disk = target_info["nameOnDisk"]
    if target_name:find("_autogen") == nil then
      local type = target_info["type"]:lower():gsub("_", " ")
      local display_name = target_name .. " (" .. type .. ")"
      local path = target_info["paths"]["build"]
      if target_name_on_disk ~= nil then -- only executables have name on disk?
        path = path .. "/" .. target_name_on_disk
      end
      local abs_path = ""
      if type == "executable" then
        abs_path = config.build_directory .. "/" .. target_info["artifacts"][1]["path"]
      end
      if not (opt.only_executable and (type ~= "executable")) then
        if target_name == config.build_target then
          table.insert(targets, 1, target_name)
          table.insert(display_targets, 1, display_name)
          table.insert(paths, 1, path)
          table.insert(abs_paths, 1, abs_path)
        else
          table.insert(targets, target_name)
          table.insert(display_targets, display_name)
          table.insert(paths, path)
          table.insert(abs_paths, abs_path)
        end
      end
    end
  end

  return Result:new(
    Types.SUCCESS,
    { targets = targets, display_targets = display_targets, paths = paths, abs_paths = abs_paths },
    "Success!"
  )
end

function Config:get_code_model_info()
  local codemodel_targets = self:get_codemodel_targets()
  if codemodel_targets.code ~= Types.SUCCESS then
    return codemodel_targets
  end

  local result = {}

  codemodel_targets = codemodel_targets.data
  for _, target in ipairs(codemodel_targets) do
    local target_info = self:get_code_model_target_info(target)
    local name = target_info["name"]
    result[name] = target_info
  end
  return result
end

function Config:launch_targets()
  return get_targets(self, { has_all = false, only_executable = true })
end

function Config:build_targets()
  return get_targets(self, { has_all = true, only_executable = false })
end

return Config
