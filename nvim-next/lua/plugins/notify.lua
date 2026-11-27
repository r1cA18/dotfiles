-- Role: notification popups for vim.notify (snacks.nvim notifier only).
-- snacks.nvim is shared with dashboard.lua and indent.lua; each file enables
-- exactly one feature and lazy.nvim merges the opts.
return {
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = { notifier = { enabled = true } },
    keys = {
      {
        "<leader>n",
        function()
          Snacks.notifier.show_history()
        end,
        desc = "Notification history",
      },
      {
        "<leader>un",
        function()
          Snacks.notifier.hide()
        end,
        desc = "Dismiss notifications",
      },
    },
  },
}
