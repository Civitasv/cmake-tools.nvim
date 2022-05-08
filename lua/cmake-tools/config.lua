local Path = require("plenary.path")
local scandir = require("plenary.scandir")
local const = require("cmake-tools.const")
local Result = require("cmake-tools.result")
local utils = require("cmake-tools.utils")
local Types = require("cmake-tools.types")

local Config = {
  build_directory = nil,
  query_directory = nil,
  reply_directory = nil,
  build_type = nil,
  generate_options = {},
  build_options = {},
  build_target = nil,
  launch_target = nil,
}

function Config:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  self.build_directory = Path:new(vim.loop.cwd(), const.cmake_build_directory)
  self.query_directory = Path:new(
    vim.loop.cwd(),
    const.cmake_build_directory,
    ".cmake",
    "api",
    "v1",
    "query"
  )
  self.reply_directory = Path:new(
    vim.loop.cwd(),
    const.cmake_build_directory,
    ".cmake",
    "api",
    "v1",
    "reply"
  )
  self.build_type = const.cmake_build_type
  self.generate_options = const.cmake_generate_options
  self.build_options = const.cmake_build_options

  return self
end

function Config:get_codemodel_targets()
  local found_files = scandir.scan_dir(
    self.reply_directory.filename,
    { search_pattern = "codemodel*" }
  )
  if #found_files == 0 then
    return Result:new(Types.CANNOT_FIND_CODEMODEL_FILE, nil, "Unable to find codemodel file")
  end
  local codemodel = Path:new(found_files[1])
  local codemodel_json = vim.json.decode(codemodel:read())
  return Result:new(Types.SUCCESS, codemodel_json["configurations"][1]["targets"], "find it")
end

function Config:get_code_model_target_info(codemodel_target)
  return vim.json.decode((self.reply_directory / codemodel_target["jsonFile"]):read())
end

function Config:generate_build_directory()
  if not self.build_directory:mkdir({ parents = true }) then
    return Result:new(Types.CANNOT_CREATE_DIRECTORY, false, "cannot create directory")
  end
  return self:generate_query_files()
end

function Config:generate_query_files()
  if not self.query_directory:mkdir({ parents = true }) then
    return Result:new(Types.CANNOT_CREATE_DIRECTORY, false, "cannot create directory")
  end

  local codemodel_file = self.query_directory / "codemodel-v2"
  if not codemodel_file:is_file() then
    if not codemodel_file:touch() then
      return Result:new(
        Types.CANNOT_CREATE_CODEMODEL_QUERY_FILE,
        nil,
        "Unable to create file " .. codemodel_file.filename
      )
    end
  end
  return Result:new(Types.SUCCESS, true, "yeah, that could be")
end

function Config:check_launch_target()
  -- 1. not configured
  if not self.build_directory:is_dir() then
    return Result:new(Types.NOT_CONFIGURED, nil, "You need to configure it first")
  end

  -- 2. not select launch target yet
  -- print("SELECTED", self.launch_target)
  if not self.launch_target then
    return Result:new(Types.NOT_SELECT_LAUNCH_TARGET, nil, "You need to select launch target first")
  end

  local codemodel_targets = self:get_codemodel_targets()
  if codemodel_targets.code ~= Types.SUCCESS then
    return codemodel_targets
  end
  codemodel_targets = codemodel_targets.data
  -- print("ALL TARGETS", dump(codemodel_targets))

  for _, target in ipairs(codemodel_targets) do
    if self.launch_target == target["name"] then
      local target_info = self:get_code_model_target_info(target)
      local type = target_info["type"]:lower():gsub("_", " ")
      -- print("TYPE", type)
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

function Config:get_launch_target()
  local check_result = self:check_launch_target()
  -- print("CHECK", dump(check_result))
  -- print(check_result.code)
  -- print(Types.SUCCESS)
  if check_result.code ~= Types.SUCCESS then
    -- print("RETURN AGAIN")
    return check_result
  end
  -- print("LAUNCH", dump(check_result))
  local target_info = check_result.data

  -- print("TARGET INFO", dump(target_info))
  local target_path = target_info["artifacts"][1]["path"]
  -- print("TARGET PATH", target_path)
  if not Path:new(target_path):is_file() then
    return Result:new(
      Types.SELECTED_LAUNCH_TARGET_NOT_BUILT,
      nil,
      "Selected target is not built: " .. target_path.filename
    )
  end

  return Result:new(Types.SUCCESS, target_path, "yeah, that's good")
end

function Config:validate_for_debugging()
  local build_type = self.build_type
  if build_type ~= "Debug" and build_type ~= "RelWithDebInfo" then
    utils.error(
      "For debugging you need to use Debug or RelWithDebInfo, but currently your build type is "
        .. build_type
    )
    return Result:new(Types.CANNOT_DEBUG_LAUNCH_TARGET, false, "cannot debug it")
  end
  return Result:new(Types.SUCCESS, true, "Yeah, it may be")
end

local function get_targets(config, opt)
  local targets, display_targets = {}, {}
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
    -- print(dump(target))
    local target_info = config:get_code_model_target_info(target)
    local target_name = target_info["name"]
    -- print(target_name)
    if target_name:find("_autogen") == nil then
      local type = target_info["type"]:lower():gsub("_", " ")
      local display_name = target_name .. " (" .. type .. ")"
      if opt.only_executable and (type ~= "executable") then
      else
        if target_name == config.build_target then
          table.insert(targets, 1, target_name)
          table.insert(display_targets, 1, display_name)
        else
          table.insert(targets, target_name)
          table.insert(display_targets, display_name)
        end
      end
    end
  end
  return targets, display_targets
end

function Config:launch_targets()
  return get_targets(self, { has_all = false, only_executable = true })
end

function Config:build_targets()
  return get_targets(self, { has_all = true, only_executable = false })
end

return Config
