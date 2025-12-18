local match = require("luassert.match")
local stub = require("luassert.stub")
local const = require("cmake-tools.const")
local ctest = require("cmake-tools.test.ctest")
local utils = require("cmake-tools.utils")

describe("run", function()
  local local_const
  local Config
  local expected
  before_each(function()
    package.loaded["cmake-tools.config"] = nil
    Config = require("cmake-tools.config")
    local_const = vim.deepcopy(const)
    expected = { "--test-dir", "build_dir", "-R", "test_name" }
    stub(utils, "run")
  end)

  it("takes extra args from user config", function()
    local_const.ctest_extra_args = { "-j", "6" }
    local config = Config:new(local_const)
    ctest:run("test_name", "build_dir", "env", config, {})
    table.insert(expected, "-j")
    table.insert(expected, "6")
    assert
      .stub(utils.run).was
      .called_with(match._, match._, match._, expected, match._, match._, match._)
  end)

  it("ignores extra args if not provided", function()
    local config = Config:new(const)
    ctest:run("test_name", "build_dir", "env", config, {})
    assert
      .stub(utils.run).was
      .called_with(match._, match._, match._, expected, match._, match._, match._)
  end)
end)
