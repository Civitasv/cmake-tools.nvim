local stub_notification
local stub_runner

local function clear_modules()
  package.loaded["cmake-tools.utils"] = nil
  package.loaded["cmake-tools.notification"] = nil
  package.loaded["cmake-tools.runners"] = nil
  package.loaded["cmake-tools.executors"] = nil
end

describe("utils.run", function()
  before_each(function()
    clear_modules()

    stub_notification = {
      enabled = true,
      stop_calls = 0,
      start_calls = 0,
      notify_calls = {},
      notify = function(self, msg, level, opts)
        table.insert(self.notify_calls, { msg = msg, level = level, opts = opts })
      end,
      startSpinner = function(self)
        self.start_calls = self.start_calls + 1
      end,
      stopSpinner = function(self)
        self.stop_calls = self.stop_calls + 1
      end,
    }

    package.loaded["cmake-tools.notification"] = {
      new = function(_)
        return stub_notification
      end,
    }

    stub_runner = {
      run = function(_, _, _, _, _, _, on_exit, on_output)
        on_output("[ 50%] Running test", nil)
        on_exit(0)
      end,
    }

    package.loaded["cmake-tools.runners"] = {
      fake = stub_runner,
    }

    package.loaded["cmake-tools.executors"] = {
      fake = {},
    }
  end)

  after_each(function()
    clear_modules()
  end)

  it("stops spinner when run completes", function()
    local utils = require("cmake-tools.utils")

    utils.run("ctest", "", {}, {}, vim.loop.cwd(), { name = "fake", opts = {} }, nil)

    assert.equals(1, stub_notification.start_calls)
    assert.equals(1, stub_notification.stop_calls)
  end)
end)
