local Path = require("plenary.path")

-- Stub osys to avoid win32 path mangling
package.loaded["cmake-tools.osys"] = { iswin32 = false }

local Config = require("cmake-tools.config")

describe("Config:update_build_dir", function()
  local config

  before_each(function()
    config = {
      cwd = "/home/user/project",
      base_settings = { build_dir = "" },
    }
    setmetatable(config, { __index = Config })
  end)

  it("sets absolute build_directory when given an absolute path", function()
    config:update_build_dir("/tmp/build", "/tmp/build")
    assert.equals("/tmp/build", config.build_directory:absolute())
  end)

  it("errors when build_dir is not a string or function", function()
    assert.has_error(function()
      config:update_build_dir(42, "out/${variant:buildType}")
    end)
  end)

  it("errors when no_expand_build_dir is not a string or function", function()
    assert.has_error(function()
      config:update_build_dir("out/Debug", 42)
    end)
  end)

  it("sets build, query and reply directories relative to build_dir", function()
    config:update_build_dir("out/Debug", "out/${variant:buildType}")

    assert.equals(
      "/home/user/project/out/Debug",
      config.build_directory:absolute()
    )
    assert.equals(
      "/home/user/project/out/Debug/.cmake/api/v1/query",
      config.query_directory:absolute()
    )
    assert.equals(
      "/home/user/project/out/Debug/.cmake/api/v1/reply",
      config.reply_directory:absolute()
    )
  end)

  it("preserves relative template in base_settings.build_dir", function()
    config:update_build_dir("out/Debug", "out/${variant:buildType}")
    assert.equals("out/${variant:buildType}", config.base_settings.build_dir)
  end)

  it("preserves absolute template in base_settings.build_dir", function()
    config:update_build_dir("out/Debug", "/home/user/project/out/${variant:buildType}")
    assert.equals("/home/user/project/out/${variant:buildType}", config.base_settings.build_dir)
  end)
end)
