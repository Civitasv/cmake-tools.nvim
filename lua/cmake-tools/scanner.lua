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

  -- strip trailing dash for the filename
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
  for _, c_name in ipairs(C_COMPILERS) do
    local prefix = exe:match("^(.+%-)" .. c_name .. "$")
    if prefix then
      return prefix, c_name
    end
    -- Without prefix: "gcc"
    if exe == c_name then
      return "", c_name
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
    -- preserve prefix so we can use it in the kit name
    prefix = prefix or "",
  }
end

local function get_path_executables()
  local path_dirs = vim.split(vim.env.PATH or "", ":", { plain = true })
  local executables = {}
  for _, dir in ipairs(path_dirs) do
    local entries = vim.fn.readdir(dir) -- returns {} on error / missing dir
    for _, entry in ipairs(entries) do
      local full = dir .. "/" .. entry
      if vim.fn.executable(full) == 1 then
        executables[entry] = true -- deduplicate by name
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
  vim.notify("Discovered toolchains: " .. vim.inspect(chains))
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
  vim.notify("Scanning for kits…")

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
      else
        vim.notify("No C++ compiler found for: " .. tc.c)
      end

      if check_executable_exists(tc.linker) then
        kit.linker = get_executable_path(tc.linker)
      else
        vim.notify("No linker found for: " .. tc.c)
      end
      local toolchain_file = find_toolchain_file(tc.prefix)
      if toolchain_file then
        kit.toolchainFile = toolchain_file
        vim.notify("Toolchain file found: " .. toolchain_file)
      else
        if tc.prefix ~= "" then
          vim.notify("No toolchain file found for prefix: " .. tc.prefix, vim.log.levels.WARN)
        end
      end

      table.insert(kits, kit)
    else
      vim.notify("Skipping toolchain – C compiler not found: " .. tc.c)
    end
  end
  local json_kits = vim.fn.json_encode(kits)
  if json_kits then
    vim.fn.writefile({ json_kits }, constants.cmake_kits_path)
    vim.notify("Kits saved to: " .. constants.cmake_kits_path)
  else
    vim.notify("Failed to encode kits to JSON.", vim.log.levels.ERROR)
  end
  vim.notify("Scanning complete.")
  return kits
end

return scanner
