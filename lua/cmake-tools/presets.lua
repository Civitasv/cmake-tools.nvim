local Path = require("plenary.path")

local presets = {}

-- checks if there is a CMakePresets.json or CMakeUserPresets.json file
function presets.check()
  -- helper function to find the config file
  -- returns file path if found, nil otherwise
  local function findcfg()
    local files = vim.fn.readdir(".")
    local file = nil
    for _, f in ipairs(files) do -- iterate over files in current directory
      if f == "CMakePresets.json" or f == "CMakeUserPresets.json" then -- if a kits config file is found
        file = vim.fn.resolve("./" .. f)
        break
      end
    end

    return file
  end

  local file = findcfg() -- check for config file

  return file
end

function presets.parse(type)
  local file = presets.check()
  local options = {}
  if not file then
    return options
  end
  local data = vim.fn.json_decode(vim.fn.readfile(file))
  for _, v in pairs(data[type]) do
    table.insert(options, v["name"])
  end
  return options
end

function presets.get_preset_by_name(name, type)
  local file = presets.check()
  if not file then
    return nil
  end
  local data = vim.fn.json_decode(vim.fn.readfile(file))
  for _, v in pairs(data[type]) do
    if v.name == name then
      return v
    end
  end
  return nil
end

function presets.get_build_type(preset)
  if preset and preset.cacheVariables and preset.cacheVariables.CMAKE_BUILD_TYPE then
    return preset.cacheVariables.CMAKE_BUILD_TYPE
  end
  return "Debug"
end

function presets.get_build_dir(preset)
  if preset and preset.binaryDir then
    return Path:new(preset.binaryDir)
  end
  return -1
end

return presets
