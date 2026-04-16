local constants = require("cmake-tools.const")
local scanner = {}

local C_COMPILERS = { "gcc", "clang" }
local TOOLCHAIN_SEARCH_PATHS = {
  vim.fn.expand("~/.cmake/toolchains"),
  "/usr/share/cmake/toolchains",
  "/usr/local/share/cmake/toolchains",
  "/etc/cmake/toolchains",
}

local function toolchain_candidates(prefix)
  if prefix == "" then
    return {}
  end

  local triplet = prefix:gsub("%-$", "")

  return {
    triplet .. ".cmake",
    triplet .. "-toolchain.cmake",
    "toolchain-" .. triplet .. ".cmake",
  }
end

local function find_toolchain_file(prefix)
  local candidates = toolchain_candidates(prefix)
  if #candidates == 0 then
    return nil
  end

  for _, search_dir in ipairs(TOOLCHAIN_SEARCH_PATHS) do
    for _, filename in ipairs(candidates) do
      local full_path = search_dir .. "/" .. filename
      if vim.fn.filereadable(full_path) == 1 then
        return full_path
      end
    end
  end

  return nil
end
local function match_c_compiler(exe)
  for _, compiler_name in ipairs(C_COMPILERS) do
    local prefix = exe:match("^(.+%-)" .. compiler_name .. "$")
    if prefix then
      return prefix, compiler_name
    end
    if exe == compiler_name then
      return "", compiler_name
    end
  end
  return nil, nil
end
local function derive_toolchain(prefix, c_name)
  local map = {
    gcc = { cxx = "g++", linker = "ld" },
    clang = { cxx = "clang++", linker = "lld" },
  }
  local companions = map[c_name]
  if not companions then
    return nil
  end

  return {
    c = (prefix or "") .. c_name,
    cxx = (prefix or "") .. companions.cxx,
    linker = (prefix or "") .. companions.linker,
    prefix = prefix or "",
  }
end

local function get_path_executables()
  local path_dirs = vim.split(vim.env.PATH or "", ":", { plain = true })
  local executables = {}
  for _, dir in ipairs(path_dirs) do
    local entries = vim.fn.readdir(dir)
    for _, entry in ipairs(entries) do
      local full = dir .. "/" .. entry
      if vim.fn.executable(full) == 1 then
        executables[entry] = true
      end
    end
  end
  return executables
end
local function discover_toolchains(executables)
  local seen = {}
  local chains = {}

  for exe in pairs(executables) do
    local prefix, c_name = match_c_compiler(exe)
    if c_name then
      local key = prefix .. c_name
      if not seen[key] then
        seen[key] = true
        local chain = derive_toolchain(prefix, c_name)
        if chain then
          table.insert(chains, chain)
        end
      end
    end
  end
  return chains
end

local function check_executable_exists(compiler)
  if not compiler or compiler == "" then
    return nil
  end
  local exists = vim.fn.executable(compiler) == 1
  return exists
end

local function get_executable_path(compiler)
  if not compiler or compiler == "" then
    return nil
  end
  local path = vim.fn.exepath(compiler)
  return path
end

local function get_compiler_version(compiler)
  if not compiler or compiler == "" then
    return nil
  end
  local version_output = vim.fn.system({ compiler, "--version" })
  local version = version_output:match("%d+%.%d+%.%d+")
  return version
end

-- Main function to scan for kits
function scanner.scan_for_kits()
  local executables = get_path_executables()
  local toolchains = discover_toolchains(executables)
  local kits = {}

  for _, tc in ipairs(toolchains) do
    local has_c = check_executable_exists(tc.c)
    local has_cxx = check_executable_exists(tc.cxx)

    if has_c then
      local kit = { compilers = {} }

      local version = get_compiler_version(tc.c)
      local prefix_label = tc.prefix ~= "" and (tc.prefix:gsub("%-$", "") .. " ") or ""
      kit.name = prefix_label .. tc.c .. " " .. (version or "Unknown")

      kit.compilers.C = get_executable_path(tc.c)

      if has_cxx then
        kit.compilers.CXX = get_executable_path(tc.cxx)
      end

      if check_executable_exists(tc.linker) then
        kit.linker = get_executable_path(tc.linker)
      end
      local toolchain_file = find_toolchain_file(tc.prefix)
      if toolchain_file then
        kit.toolchainFile = toolchain_file
      end
      table.insert(kits, kit)
    end
  end
  if vim.fn.isdirectory(constants.cmake_config_path) == 0 then
    vim.fn.mkdir(constants.cmake_config_path, "p")
  end
  local json_kits = vim.fn.json_encode(kits)
  if json_kits then
    vim.fn.writefile({ json_kits }, constants.cmake_kits_path)
  end
  return kits
end

return scanner
