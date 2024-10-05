local scratch = {
  name = "*cmake-tools*",
  buffer = nil,
}

function scratch.create(executor, runner)
  if scratch.buffer ~= nil then
    return
  end

  scratch.buffer = vim.api.nvim_create_buf(true, true) -- can be search, and is a scratch buffer
  vim.api.nvim_buf_set_name(scratch.buffer, scratch.name)
  vim.api.nvim_buf_set_lines(scratch.buffer, 0, 0, false, {
    "THIS IS A SCRATCH BUFFER FOR cmake-tools.nvim, YOU CAN SEE WHICH COMMAND THIS PLUGIN EXECUTES HERE.",
    "EXECUTOR: " .. executor .. " RUNNER: " .. runner,
  })
  vim.api.nvim_buf_set_option(scratch.buffer, "buflisted", false)
end

function scratch.append(cmd)
  vim.schedule(function()
    vim.api.nvim_buf_set_lines(scratch.buffer, -1, -1, false, { cmd })
  end)
end

return scratch
