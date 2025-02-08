local const = require("cmake-tools.const")

describe('Config', function()
  local Config
  local local_const

  before_each(function()
    package.loaded['cmake-tools.config'] = nil
    Config = require('cmake-tools.config')
    local_const = vim.deepcopy(const)
  end)

  it('should parse user provided ctest arguments', function()
    local_const.ctest_extra_args = { "-j", "6" }
    local config = Config:new(local_const)
    assert.are_same({ "-j", "6" }, config.ctest.extra_args)
  end)

  it('should parse user ctest empty arguments', function()
    local config = Config:new(const)
    assert.are_same({}, config.ctest.extra_args)
  end)
end)
