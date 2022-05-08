local Path = require("plenary.path")
local scandir = require('plenary.scandir')
local const = require("cmake-tools.const")
local Result = require("cmake-tools.result")
local utils = require("cmake-tools.utils")
local ErrorTypes, SuccessTypes = require("cmake-tools.types")()

local Config = {
  build_directory = "",
  reply_directory = "",
  build_type = "",
  generate_options = {},
  build_options = {},
  build_target = nil,
  launch_target = nil
}

function Config:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  self.build_directory = Path:new(const.cmake_build_directory)
  self.reply_directory = Path:new(const.cmake_build_directory, '.cmake', 'api', 'v1', 'reply')
  self.build_type = Path:new(const.cmake_build_type)
  self.generate_options = Path:new(const.cmake_generate_options)
  self.build_options = Path:new(const.cmake_build_options)

  return self
end

function Config:get_codemodel_targets()
  local found_files = scandir.scan_dir(self:get_reply_dir().filename, { search_pattern = 'codemodel*' })
  if #found_files == 0 then
    return Result:new(ErrorTypes.CANNOT_FIND_CMAKE_CONFIGURATION_FILE, nil, "Unable to find codemodel file")
  end
  local codemodel = Path:new(found_files[1])
  local codemodel_json = vim.json.decode(codemodel:read())
  return codemodel_json['configurations'][1]['targets']
end


function Config:get_code_model_target_info(codemodel_target)
  return vim.json.decode((self.reply_directory / codemodel_target['jsonFile']):read())
end


function Config:generate_build_directory()
  self.build_directory:mkdir({ parent = true })
end

function Config:check_launch_target()
  -- 1. not configured
  if not self.build_directory:is_dir() then
    return Result:new(ErrorTypes.NOT_CONFIGURED, nil, "You need to configure it first")
  end

  -- 2. not select launch target yet
  if not self.launch_target then
    return Result:new(ErrorTypes.NOT_SELECT_LAUNCH_TARGET, nil, "You need to select launch target first")
  end

  for _, target in ipairs(self:get_codemodel_targets()) do
    if self.json.current_target == target['name'] then
      local target_info = self:get_target_info(target)
      if target_info['type'] ~= 'EXECUTABLE' then
        -- 3. selected target cannot execute
        return Result:new(ErrorTypes.NOT_EXECUTABLE, nil, "You need to select a executable target")
      end
      return Result:new(SuccessTypes.SUCCESS, target_info, "Success")
    end
  end

  return Result:new(ErrorTypes.SELECTED_LAUNCH_TARGET_NOT_BUILT, nil, 'Unable to find the following target: ' .. self.launch_target)
end

function Config:get_launch_target()
  local check_result = self:check_launch_target()
  if not check_result.code == SuccessTypes.SUCCESS then
    return check_result
  end
  local target_info = check_result.data

  local target_path = self.build_directory / target_info['artifacts'][1]['path']
  if not target_path:is_file() then
    return Result:new(ErrorTypes.SELECTED_LAUNCH_TARGET_NOT_BUILT, nil, 'Selected target is not built: ' .. target_path.filename)
  end

  return target_path
end

function Config:validate_for_debugging()
  local build_type = self.json.build_type
  if build_type ~= 'Debug' and build_type ~= 'RelWithDebInfo' then
    utils.error('For debugging you need to use Debug or RelWithDebInfo, but currently your build type is ' .. build_type)
    return false
  end
  return true
end

return Config
