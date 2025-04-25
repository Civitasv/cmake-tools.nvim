local scratch = {
  name = "*cmake-tools*",
  buffer = nil,
}

function scratch.create(executor, runner)
  if scratch.buffer and vim.api.nvim_buf_is_valid(scratch.buffer) then
    return
  end

  scratch.buffer = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(scratch.buffer, scratch.name)
  vim.api.nvim_buf_set_lines(scratch.buffer, 0, 0, false, {
    "THIS IS A SCRATCH BUFFER FOR cmake-tools.nvim, YOU CAN SEE WHICH COMMAND THIS PLUGIN EXECUTES HERE.",
    "EXECUTOR: " .. executor .. " RUNNER: " .. runner,
  })

  -- Better scratch behavior
  vim.api.nvim_set_option_value("buflisted", false, { buf = scratch.buffer })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = scratch.buffer })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = scratch.buffer })
  vim.api.nvim_set_option_value("swapfile", false, { buf = scratch.buffer })
end

function scratch.append(cmd)
  vim.schedule(function()
    if scratch.buffer and vim.api.nvim_buf_is_valid(scratch.buffer) then
      vim.api.nvim_buf_set_lines(scratch.buffer, -1, -1, false, { cmd })
    else
      vim.notify("[cmake-tools.nvim] scratch buffer not created yet", vim.log.levels.WARN)
    end
  end)
end

return scratch
