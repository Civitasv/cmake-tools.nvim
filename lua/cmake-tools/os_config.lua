local os_config = {}

local function enum(tbl)
  local length = #tbl
  for i = 1, length do
    local v = tbl[i]
    tbl[v] = i
  end
  return tbl
end

local Os_List = enum({
  "Win32",
  "Unix",
  "MacOS"
})

-- Detect os on startup
local is_macunix = vim.fn.has("macunix")
local is_win32 = vim.fn.has("win32")
local is_wsl = vim.fn.has("wsl")

function os_config.get_os()
  if is_win32 == 1 then
    os_config.my_os = Os_List.Win32
    -- print('Win32')
  elseif is_wsl == 1 then
    os_config.my_os = Os_List.Unix
    -- print('Unix')
  elseif is_macunix == 1 then
    os_config.my_os = Os_List.MacOS
    -- print('MacOS')
  else
    vim.notify("CMake Tools: OS is Not detected!", vim.log.levels.ERROR, { title = "CMake" })
  end
  return os_config.my_os
end

--- TODO: All this is intended to do is to prevent the user from spamming multiple CMake <Taks> Commands, all at once.
function os_config.get_process_wrapper_for(cmd)
  local my_os = os_config.get_os()

  if my_os == Os_List.Win32 then
    local wrapped_cmd = "Start-Process -FilePath pwsh.exe -ArgumentList \"-noprofile\", \"-Command\"," ..
        cmd .. " -PassThru -NoNewWindow | Wait-Process"
    -- local wrapped_cmd =  "Start-Process -FilePath pwsh  \"-Command " .. cmd .." && echo 'done!' \" -NoNewWindow -ArgumentList '-noprofile -command \"Start-Process cmd.exe -Verb RunAs -args /k\"'"
    -- wrapped_cmd = wrapped_cmd .. string.char(13)
    -- print('wrapped_cmd: ' .. wrapped_cmd)
    return wrapped_cmd
  elseif my_os == Os_List.Unix then
    -- TODO: Wrapped command here
  elseif my_os == Os_List.MacOS then
    -- TODO: Wrapped command here
  end
end

function os_config.start_local_shell(split_direction)
  if os_config.get_os() == Os_List.Win32 then
    vim.cmd(':' .. split_direction .. ' sp | :term')           -- Creater terminal in a split
    local terminal_buffer_idx = vim.api.nvim_get_current_buf() -- Get the buffer idx
    vim.api.nvim_buf_set_option(terminal_buffer_idx, 'bufhidden', 'hide')
    return terminal_buffer_idx
  elseif os_config.get_os() == Os_List.Unix then
    -- TODO: Wrapped command here
  elseif os_config.get_os() == Os_List.MacOS then
    -- TODO: Wrapped command here
  end
end

function os_config.set_local_opts()
  if os_config.get_os() == Os_List.Win32 then
    vim.cmd(':setlocal shell=pwsh')
    local powershell_options = {
      shell = vim.fn.executable "pwsh" == 1 and "pwsh" or "powershell",
      shellcmdflag =
      "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;",
      shellredir = "-RedirectStandardOutput %s -NoNewWindow -Wait",
      shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode",
      shellquote = "",
      shellxquote = "",
    }

    for option, value in pairs(powershell_options) do
      vim.opt[option] = value
      -- vim.cmd(':setlocal ' .. option .. "=" ..value)
    end
  end
end

return os_config
