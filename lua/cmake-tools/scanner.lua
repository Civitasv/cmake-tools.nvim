local scanner = {}

--Helper functions
local function execute_command(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  if handle == nil then
    return false, -1, ""
  end
  local result = handle:read("*a")
  if result == nil then
    result = ""
  end
  local success, exit_code = handle:close()
  if success == nil then
    return false, exit_code or -1, result
  end
  return true, 0, result
end

local function split_path(path_env)
  local paths = {}
  local sep = package.config:sub(1, 1) == "\\" and ";" or ":"
  for path in string.gmatch(path_env, "([^" .. sep .. "]+)") do
    table.insert(paths, path)
  end
  return paths
end

local function get_gcc_version(gcc_path)
  local success, exit_code, output = execute_command('"' .. gcc_path .. '" --version')
  if output == nil then
    return nil
  end
  -- Try multiple patterns to match different gcc output formats
  local version = output:match("gcc[%s%a]([%d%.]+)") -- "gcc (GCC) 15.2.1"
    or output:match("gcc version ([%d%.]+)") -- "gcc version 11.4.0"
  return version
end

local function get_clang_version(clang_path)
  local success, exit_code, output = execute_command('"' .. clang_path .. '" --version ')
  if output == nil then
    return nil
  end
  local version_line = output:match("clang version ([%d%.]+)")
  return version_line
end

local function find_compiler_pair(dir, c_compiler)
  local base_name = c_compiler:match("([^/\\]+)$")
  local cxx_name
  if base_name:match("gcc") then
    cxx_name = base_name:gsub("gcc", "g++")
  elseif base_name:match("clang") then
    cxx_name = base_name:gsub("clang", "clang++")
  else
    return nil
  end
  local cxx_path = dir .. "/" .. cxx_name
  if vim.fn.filereadable(cxx_path) then
    return cxx_path
  end
  return nil
end

local function find_linker_pair(dir, linker_name)
  if not linker_name then
    return nil
  end
  local linker_path = dir .. "/" .. linker_name
  if vim.fn.filereadable(linker_path) then
    return linker_path
  end
  return nil
end

local function get_toolchain_file()
  local toolchainFile = os.getenv("CMAKE_TOOLCHAIN_FILE")
  if toolchainFile and vim.fn.filereadable(toolchainFile) then
    return toolchainFile
  end
  return nil
end

local function ensure_directory(path)
  if not path then
    vim.notify("Path is empty", vim.log.levels.ERROR)
    return
  end
  local pattern = "(.*/)"
  local dir = path:match(pattern)
  if dir then
    vim.fn.mkdir(dir, "p")
  end
end

local function save_kits(kits, filepath)
  ensure_directory(filepath)
  local file = io.open(filepath, "w")
  if not file then
    vim.notify("Failed to open file for writing: " .. filepath, vim.log.levels.ERROR)
    return false
  end
  if not kits then
    vim.notify("Can not encode data to json because it is nil", vim.log.levels.ERROR)
    return false
  end
  local json_content = vim.json.encode(kits)
  file:write(json_content)
  file:close()
  return true
end

-- Main function to scan for kits
function scanner.scan_for_kits()
  local kits = {}
  local const = require("cmake-tools.const")
  local path_env = os.getenv("PATH") or ""
  local paths = split_path(path_env)

  for _, dir in ipairs(paths) do
    local linker_path = find_linker_pair(dir, "lld")
    if linker_path == nil then
      linker_path = find_linker_pair(dir, "ld")
    end
    local toolchainFile = get_toolchain_file()
    local gcc_path = dir .. "/gcc"
    if vim.fn.filereadable(gcc_path) then
      local gcc_version = get_gcc_version(gcc_path)
      local gxx_path = find_compiler_pair(dir, gcc_path)
      if gxx_path then
        local kit = {
          name = "GCC-" .. (gcc_version or "unknown"),
          compilers = {
            C = gcc_path,
            CXX = gxx_path,
          },
          linker = (linker_path or ""),
          toolchainFile = (toolchainFile or ""),
        }
        table.insert(kits, kit)
      end
    end

    local clang_path = dir .. "/clang"
    if vim.fn.filereadable(clang_path) then
      local clang_version = get_clang_version(clang_path)
      local clangxx_path = find_compiler_pair(dir, clang_path)
      if clangxx_path then
        local kit = {
          name = "Clang-" .. (clang_version or "unknown"),
          compilers = {
            C = clang_path,
            CXX = clangxx_path,
          },
          linker = (linker_path or ""),
          toolchainFile = (toolchainFile or ""),
        }
        table.insert(kits, kit)
      end
    end
  end

  if #kits == 0 then
    vim.notify("No compilers found in PATH.", vim.log.levels.WARN)
    return {}
  end
  vim.notify("Found kits", vim.log.levels.INFO)
  if const.cmake_kits_path == nil then
    vim.notify(
      "local const variable is nil, it seems that the required module could not be loaded",
      vim.log.levels.ERROR
    )
    return {}
  end
  save_kits(kits, const.cmake_kits_path)
  return kits
end

return scanner
