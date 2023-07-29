local kits = {}

-- checks if there is a cmake-kits.json file and parses it to a Lua table
function kits.parse(global_kits_path)
  -- helper function to find the config file
  -- returns file path if found, nil otherwise
  local function findcfg()
    local files = vim.fn.readdir(".")

    -- it will use local kits path first,
    -- otherwise, it will use global kits path
    local file = global_kits_path
    for _, f in ipairs(files) do -- iterate over files in current directory
      if f == "cmake-kits.json" or f == "CMakeKits.json" then -- if a kits config file is found
        file = vim.fn.resolve("./" .. f)
        break
      end
    end
    return file
  end

  -- start parsing
  local config = nil

  local file = findcfg() -- check for config file
  if file then -- if one is found ...
    if file:match(".*%.json") then -- .. and is a json file
      config = vim.fn.json_decode(vim.fn.readfile(file))
    end
  end

  return config
end

-- returns a list of descriptions of all kits
function kits.get(global_kits_path)
  -- start parsing
  local config = kits.parse(global_kits_path)
  local res = {}
  if config then -- if a config is found
    for _, item in ipairs(config) do
      local name = item.name
      table.insert(res, name)
    end
  end
  return res
end

function kits.get_by_name(kit_name)
  local config = kits.parse()
  if config then
    for _, item in ipairs(config) do
      local name = item.name
      if name == kit_name then
        return item
      end
    end
  end
  return nil
end

-- given a kit, build an argument list for CMake
function kits.build_env_and_args(kit_name, always_use_terminal)
  local kit = kits.get_by_name(kit_name)
  local args = {}
  local env = {}

  if not kit then
    return { env = env, args = args } -- silent error (empty arglist) if no config file found
  end

  -- local function to add an argument to `args`
  local function add_args(as)
    for _, a in pairs(as) do
      table.insert(args, a)
    end
  end

  local function add_env(ev)
    for _, a in pairs(ev) do
      table.insert(env, a)
    end
  end

  -- if exists `compilers` option, then set variable for cmake
  if kit.compilers then
    for lang, compiler in pairs(kit.compilers) do
      if always_use_terminal then
        add_args({ "-DCMAKE_" .. lang .. '_COMPILER:FILEPATH="' .. compiler .. '"' })
      else
        add_args({ "-DCMAKE_" .. lang .. "_COMPILER:FILEPATH=" .. compiler })
      end
    end
  end

  -- See : https://metricpanda.com/rival-fortress-update-27-compiling-with-clang-on-windows/
  if kit.linker then
    if always_use_terminal then
      table.insert(args, "-DCMAKE_LINKER=" .. '"' .. kit.linker .. '"')
    else -- Quick Fix Lists
      table.insert(args, "-DCMAKE_LINKER=" .. kit.linker)
    end
  end
  if kit.generator then
    if always_use_terminal then
      table.insert(args, "-G" .. '"' .. kit.generator .. '"')
    else -- Quick Fix Lists
      table.insert(args, "-G" .. kit.generator)
    end
  end
  if kit.host_architecture then
    table.insert(args, "-T host=" .. kit.host_architecture)
  end
  if kit.target_architecture then
    table.insert(args, "-A " .. kit.target_architecture)
  end
  if kit.toolchainFile then
    add_args({ "-DCMAKE_TOOLCHAIN_FILE:FILEPATH=" .. kit.toolchainFile })
  end

  if kit.environmentVariables then
    for k, v in pairs(kit.environmentVariables) do
      add_env({ k .. "=" .. v })
    end
  end
  return { env = env, args = args }
end

return kits
