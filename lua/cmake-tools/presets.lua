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

function presets.parsePresets(file, presetType)
  local data = vim.fn.json_decode(vim.fn.readfile(file))
  local options = {}
  for _, v in pairs(data[presetType]) do
    table.insert(options, v["name"])
  end
  return options
end

return presets
