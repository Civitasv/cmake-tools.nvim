local const = require("cmake-tools.const")
local scanner = {}
-- Configuration
scanner.KITS_FILE = const.cmake_kits_path

--Helper functions
-- Simple JSON encoder
function scanner.json_encode(obj, indent)
  indent = indent or 0
  local spaces = string.rep("  ", indent)

  if type(obj) == "table" then
    local is_array = #obj > 0
    local result = "{\n"
    local first = true

    for k, v in pairs(obj) do
      if not first then
        result = result .. ",\n"
      end
      first = false

      if is_array then
        result = result .. spaces .. "  " .. scanner.json_encode(v, indent + 1)
      else
        result = result .. spaces .. '  "' .. k .. '": ' .. scanner.json_encode(v, indent + 1)
      end
    end

    return result .. "\n" .. spaces .. "}"
  elseif type(obj) == "string" then
    return '"' .. obj:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
  elseif type(obj) == "number" or type(obj) == "boolean" then
    return tostring(obj)
  elseif obj == nil then
    return "null"
  end
end

function scanner.execute_command(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  if handle == nil then
    return false, -1, ""
  end
  local result = handle:read("*a")
  if result == nil then
    result = ""
  end
  local success, exit_type, exit_code = handle:close()
  -- io.popen's close() returns: true on success, or nil, "exit", code on failure
  if success == nil then
    return false, exit_code or -1, result
  end
  return true, 0, result
end

function scanner.file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  else
    return false
  end
end

function scanner.split_path(path_env)
  local paths = {}
  local sep = package.config:sub(1, 1) == "\\" and ";" or ":"
  for path in string.gmatch(path_env, "([^" .. sep .. "]+)") do
    table.insert(paths, path)
  end
  return paths
end

function scanner.get_gcc_version(gcc_path)
  local success, exit_code, output = scanner.execute_command('"' .. gcc_path .. '" --version')
  if output == nil then
    return nil
  end
  -- Try multiple patterns to match different gcc output formats
  local version = output:match("gcc%s+%(GCC%)%s+([%d%.]+)") -- "gcc (GCC) 15.2.1"
    or output:match("gcc version ([%d%.]+)") -- "gcc version 11.4.0"
  return version
end

function scanner.get_clang_version(clang_path)
  local success, exit_code, output = scanner.execute_command('"' .. clang_path .. '" --version ')
  if output == nil then
    return nil
  end
  local version_line = output:match("clang version ([%d%.]+)")
  return version_line
end

function scanner.find_compiler_pair(dir, c_compiler)
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
  if scanner.file_exists(cxx_path) then
    return cxx_path
  end
  return nil
end

function scanner.find_linker_pair(dir, linker_name)
  if not linker_name then
    return nil
  end
  local linker_path = dir .. "/" .. linker_name
  if scanner.file_exists(linker_path) then
    return linker_path
  end
  return nil
end

function scanner.get_toolchain_file()
  local toolchainFile = os.getenv("CMAKE_TOOLCHAIN_FILE")
  if toolchainFile and scanner.file_exists(toolchainFile) then
    return toolchainFile
  end
  return nil
end

function scanner.ensure_directory(path)
  local pattern = "(.*/)"
  local dir = path:match(pattern)
  if dir then
    vim.fn.mkdir(dir, "p")
  end
end

function scanner.save_kits(kits, filepath)
  scanner.ensure_directory(filepath)
  local file = io.open(filepath, "w")
  if not file then
    error("Failed to open file for writing: " .. filepath)
    return false
  end
  local json_content = scanner.json_encode(kits)
  file:write(json_content)
  file:close()
  return true
end

-- Main fucntion to scan for kits
function scanner.scan_for_kits()
  local kits = {}

  local path_env = os.getenv("PATH") or ""
  local paths = scanner.split_path(path_env)

  for _, dir in ipairs(paths) do
    local linker_path = scanner.find_linker_pair(dir, "lld")
    if linker_path == nil then
      linker_path = scanner.find_linker_pair(dir, "ld")
    end
    local toolchainFile = scanner.get_toolchain_file()
    local gcc_path = dir .. "/gcc"
    if scanner.file_exists(gcc_path) then
      local gcc_version = scanner.get_gcc_version(gcc_path)
      local gxx_path = scanner.find_compiler_pair(dir, gcc_path)
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
    if scanner.file_exists(clang_path) then
      local clang_version = scanner.get_clang_version(clang_path)
      local clangxx_path = scanner.find_compiler_pair(dir, clang_path)
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
    print("No compilers found in PATH.")
    return {}
  end
  scanner.save_kits(kits, scanner.KITS_FILE)
  return kits
end

return scanner
