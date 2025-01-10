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
  build_type = nil,
  variant = nil,
  build_target = nil,
  launch_target = nil,
  kit = nil,
  configure_preset = nil,
  build_preset = nil,
  base_settings = {
    env = {},
    build_dir = "",
    working_dir = "${dir.binary}",
    use_preset = true,
    generate_options = {},
    build_options = {},
    show_disabled_build_presets = true,
  }, -- general config
  target_settings = {}, -- target specific config
  executor = nil,
  runner = nil,
  env_script = " ",
  cwd = vim.loop.cwd(),
}

function Config:new(const)
  local obj = {}
  setmetatable(obj, { __index = self }) -- when obj cannot find key in its table, it will try to find it from its __index value

  obj:update_build_dir(const.cmake_build_directory, const.cmake_build_directory)

  obj.base_settings.generate_options = const.cmake_generate_options
  obj.base_settings.build_options = const.cmake_build_options
  obj.base_settings.use_preset = const.cmake_use_preset

  obj.base_settings.show_disabled_build_presets = const.cmake_show_disabled_build_presets

  obj.executor = const.cmake_executor
  obj.runner = const.cmake_runner

  return obj
end

function Config:build_directory_path()
  return self.build_directory.filename
end

function Config:has_build_directory()
  return self.build_directory and self.build_directory:exists()
end

---comment
---The reason for storing no expand build directory is to make cwd selecting easier
function Config:no_expand_build_directory_path()
  return self.base_settings.build_dir
end

---comment
---@param build_dir string|function string or a function returning string containing path to the build dir
---@param no_expand_build_dir string|function
function Config:update_build_dir(build_dir, no_expand_build_dir)
  if type(build_dir) == "function" then
    build_dir = build_dir()
  end
  if type(build_dir) ~= "string" then
    error("build_dir needs to be a string or function returning string path to the build_directory")
  end
  if type(no_expand_build_dir) == "function" then
    no_expand_build_dir = no_expand_build_dir()
  end
  if type(no_expand_build_dir) ~= "string" then
    error(
      "no_expand_build_dir needs to be a string or function returning string path to the build_directory"
    )
  end
  local build_path = Path:new(build_dir)
  if build_path:is_absolute() then
    self.build_directory = Path:new(build_dir)
    self.query_directory = Path:new(build_dir, ".cmake", "api", "v1", "query")
    self.reply_directory = Path:new(build_dir, ".cmake", "api", "v1", "reply")
  else
    self.build_directory = Path:new(self.cwd, build_dir)
    self.query_directory = Path:new(self.cwd, build_dir, ".cmake", "api", "v1", "query")
    self.reply_directory = Path:new(self.cwd, build_dir, ".cmake", "api", "v1", "reply")
  end

  self.base_settings.build_dir = Path:new(no_expand_build_dir):absolute()
end

---Prepare build directory. Which allows macro expansion.
---@param kits table all the kits
function Config:prepare_build_directory(kits)
  -- macro expansion:
  --       ${kit}
  --       ${kitGenerator}
  --       ${variant:xx}
  -- get the detailed info of the selected kit
  local build_dir = self:no_expand_build_directory_path()
  local kit = self.kit
  local variant = self.variant
  local kit_info = nil
  if kits then
    for _, item in ipairs(kits) do
      if item.name == kit then
        kit_info = item
      end
    end
  end
  build_dir = build_dir:gsub("${kit}", kit_info and kit_info.name or "")
  build_dir = build_dir:gsub("${kitGenerator}", kit_info and kit_info.generator or "")

  build_dir = build_dir:gsub("${variant:(%w+)}", function(v)
    if variant and variant[v] then
      return variant[v]
    end

    return ""
  end)

  return build_dir
end

function Config:generate_options()
  return self.base_settings.generate_options and self.base_settings.generate_options or {}
end

function Config:build_options()
  return self.base_settings.build_options and self.base_settings.build_options or {}
end

function Config:show_disabled_build_presets()
  return self.base_settings.show_disabled_build_presets
end

function Config:generate_build_directory()
  local build_directory = Path:new(self.build_directory)

  if not build_directory:mkdir({ parents = true }) then
    return Result:new(Types.CANNOT_CREATE_DIRECTORY, false, "cannot create directory")
  end
  return self:generate_query_files()
end

function Config:generate_query_files()
  local query_directory = Path:new(self.query_directory)
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
  local reply_directory = Path:new(self.reply_directory)
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
  local reply_directory = Path:new(self.reply_directory)
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
  local reply_directory = Path:new(self.reply_directory)
  return vim.json.decode((reply_directory / codemodel_target["jsonFile"]):read())
end

-- Check if launch target is built
function Config:check_launch_target()
  -- 1. not configured
  local build_directory = Path:new(self.build_directory)
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
  if require("cmake-tools.osys").iswin32 then
    target_path = target_path:gsub("/", "\\")
  end
  target_path = Path:new(target_path)
  if not target_path:is_absolute() then
    -- then it is a relative path, based on build directory
    local build_directory = Path:new(self.build_directory)
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

  return self:get_launch_target_from_info(target_info)
end

-- Check if build target exists
function Config:check_build_target()
  -- 1. not configured
  local build_directory = Path:new(self.build_directory)
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
    local build_directory = Path:new(self.build_directory)
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

  if not build_type or not variants.debuggable(build_type, self.cwd) then
    return Result:new(Types.CANNOT_DEBUG_LAUNCH_TARGET, false, "cannot debug it")
  end
  return Result:new(Types.SUCCESS, true, "Yeah, it may be")
end

local function get_targets(config, opt)
  local targets, display_targets, paths, abs_paths = {}, {}, {}, {}
  local sources = {}
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
      if opt.query_sources then -- get all source files related to this target
        for _, source in ipairs(target_info["sources"]) do
          local source_abs_path = config.cwd .. "/" .. source["path"]
          table.insert(
            sources,
            { path = source_abs_path, type = type, name = target_name, display_name = display_name }
          )
        end
      end
    end
  end

  if opt.query_sources then
    return Result:new(Types.SUCCESS, {
      targets = targets,
      display_targets = display_targets,
      paths = paths,
      abs_paths = abs_paths,
      sources = sources,
    }, "Success!")
  else
    return Result:new(
      Types.SUCCESS,
      { targets = targets, display_targets = display_targets, paths = paths, abs_paths = abs_paths },
      "Success!"
    )
  end
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

function Config:launch_targets_with_sources()
  return get_targets(self, { has_all = false, only_executable = true, query_sources = true })
end

local _virtual_targets = nil
function Config:update_targets()
  _virtual_targets =
    get_targets(self, { has_all = false, only_executable = false, query_sources = true })
end

function Config:build_targets_with_sources()
  if not _virtual_targets then
    self:update_targets()
  end
  return _virtual_targets
end

return Config
