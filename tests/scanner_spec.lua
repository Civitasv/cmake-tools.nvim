-- tests/scanner_spec.lua
describe("scanner", function()
  local scanner

  before_each(function()
    require("plenary.reload").reload_module("cmake-tools.scanner")
    scanner = require("cmake-tools.scanner")
  end)

  it("returns a table", function()
    local kits = scanner.scan_for_kits()
    assert.is_table(kits)
  end)

  it("finds a kit when gcc is installed", function()
    if vim.fn.executable("gcc") ~= 1 then
      pending("gcc not available on this system")
      return
    end
    local kits = scanner.scan_for_kits()
    assert.is_true(#kits > 0)

    local gcc_kit
    for _, kit in ipairs(kits) do
      if kit.compilers and kit.compilers.C and kit.compilers.C:find("gcc") then
        gcc_kit = kit
        break
      end
    end
    assert.is_not_nil(gcc_kit, "expected a kit with a gcc C compiler")
  end)

  it("kit has a name field", function()
    local kits = scanner.scan_for_kits()
    for _, kit in ipairs(kits) do
      assert.is_string(kit.name)
      assert.is_true(#kit.name > 0)
    end
  end)

  it("kit compilers.C is a non-empty path", function()
    local kits = scanner.scan_for_kits()
    for _, kit in ipairs(kits) do
      assert.is_string(kit.compilers.C)
      assert.is_true(#kit.compilers.C > 0)
    end
  end)

  it("kit compilers.CXX is set when the cxx companion exists", function()
    local kits = scanner.scan_for_kits()
    for _, kit in ipairs(kits) do
      if kit.compilers.CXX then
        assert.is_string(kit.compilers.CXX)
        assert.is_true(#kit.compilers.CXX > 0)
      end
    end
  end)

  it("kit linker is a path string when set", function()
    local kits = scanner.scan_for_kits()
    for _, kit in ipairs(kits) do
      if kit.linker then
        assert.is_string(kit.linker)
        assert.is_true(#kit.linker > 0)
      end
    end
  end)

  it("finds a clang kit when clang is installed", function()
    if vim.fn.executable("clang") ~= 1 then
      pending("clang not available on this system")
      return
    end
    local kits = scanner.scan_for_kits()
    local clang_kit
    for _, kit in ipairs(kits) do
      if kit.compilers and kit.compilers.C and kit.compilers.C:find("clang") then
        clang_kit = kit
        break
      end
    end
    assert.is_not_nil(clang_kit, "expected a kit with a clang C compiler")
    if clang_kit.compilers.CXX then
      assert.is_true(clang_kit.compilers.CXX:find("clang++") ~= nil)
    end
  end)

  it("toolchainFile is a string path when set", function()
    local kits = scanner.scan_for_kits()
    for _, kit in ipairs(kits) do
      if kit.toolchainFile then
        assert.is_string(kit.toolchainFile)
        assert.is_true(vim.fn.filereadable(kit.toolchainFile) == 1)
      end
    end
  end)
end)

describe("kits", function()
  it("parse from global file", function()
    local kit = require("cmake-tools.kits")
    local const = require("cmake-tools.const")
    local kits = kit.get(const.cmake_kits_path, vim.loop.cwd())
    assert(#kits > 0)
  end)
end)
