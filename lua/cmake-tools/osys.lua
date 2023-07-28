local os = {
  iswin32 = vim.fn.has("win32") == 1,
  ismac = vim.fn.has("mac") == 1,
  iswsl = vim.fn.has("wsl") == 1,
  islinux = vim.fn.has("linux") == 1,
}

return os
