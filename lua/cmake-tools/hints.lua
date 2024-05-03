local hints = {
  ns_id = vim.api.nvim_create_namespace("cmaketools"),
}

function hints.show(buf, targets)
  vim.api.nvim_buf_clear_namespace(buf, hints.ns_id, 0, -1)
  local start_line = vim.fn.line("w0")
  local end_line = vim.fn.line("w$")
  for i, target in ipairs(targets) do
    if start_line + i - 1 <= end_line then
      local mark_id = vim.api.nvim_buf_set_extmark(buf, hints.ns_id, start_line + i - 2, 0, {
        virt_text = { { target.type .. "(" .. target.name .. ")", "@type" } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
    end
  end
end

return hints
