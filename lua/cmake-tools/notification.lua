local has_notify, notify = pcall(require, "notify")

local notification = {
  notification = {},
}

function notification.update_spinner() -- update spinner helper function to defer
  if notification.notification.spinner_idx then
    local new_spinner = (notification.notification.spinner_idx + 1)
      % #notification.notification.spinner
    notification.notification.spinner_idx = new_spinner

    notification.notification.id = notification.notify(nil, notification.notification.level, {
      title = "CMakeTools",
      hide_from_history = true,
      icon = notification.notification.spinner[new_spinner],
      replace = notification.notification.id,
    })

    vim.defer_fn(function()
      notification.update_spinner()
    end, notification.notification.refresh_rate_ms)
  end
end

function notification.notify(msg, lvl, opts)
  if notification.notification.enabled and has_notify then
    opts.hide_from_history = true
    return notify(msg, lvl, opts)
  end
end

return notification
