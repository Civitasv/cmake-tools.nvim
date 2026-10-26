describe("Config.update_build_directory with presets", function()
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    local f = assert(io.open(dir .. "/CMakePresets.json", "w"))
    f:write([[{
      "version": 3,
      "configurePresets": [
        { "name": "base", "hidden": true, "generator": "Ninja",
          "binaryDir": "${sourceDir}/build/${presetName}" },
        { "name": "Debug", "inherits": "base" }
      ]
    }]])
    f:close()
  end)

  after_each(function()
    vim.fn.delete(dir, "rf")
  end)

  it("keeps preset macros out of the stored no-expand build dir", function()
    local const = require("cmake-tools.const")
    local Config = require("cmake-tools.config")
    local config = Config:new(const)
    config.cwd = dir
    config.configure_preset = "Debug"

    config:update_build_directory()

    assert.is_truthy(config.build_directory.filename:find("build/Debug", 1, true))
    assert.is_nil(config:no_expand_build_directory_path():find("${sourceDir}", 1, true))
  end)
end)
