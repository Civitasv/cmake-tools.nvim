local hints = {
  ns_id = vim.api.nvim_create_namespace("cmaketools"),
}

function hints.show(buf, line, target_type, target)
  vim.api.nvim_buf_clear_namespace(buf, hints.ns_id, 0, -1)
  local vl = vim.fn.line("w0")
  local mark_id = vim.api.nvim_buf_set_extmark(buf, hints.ns_id, vl, 0, {
    virt_text = { { target_type .. "(" .. target .. ")", "@type" } },
    virt_text_pos = "right_align",
    hl_mode = "combine",
  })
end

return hints
