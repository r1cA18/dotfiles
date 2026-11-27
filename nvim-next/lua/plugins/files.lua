-- Role: file operations. Edit a directory like a buffer: rename, move, delete
-- and create by editing lines, then `:w` to apply.
return {
  {
    "stevearc/oil.nvim",
    lazy = false, -- must load at startup so `nvim <dir>` opens oil
    opts = {
      default_file_explorer = true,
      delete_to_trash = true,
      view_options = { show_hidden = true },
      keymaps = {
        -- Free <C-h> / <C-l> for window navigation (config/keymaps.lua).
        ["<C-h>"] = false,
        ["<C-l>"] = false,
        ["<C-x>"] = { "actions.select", opts = { horizontal = true } },
        ["<F5>"] = "actions.refresh",
      },
      float = { max_width = 0.8, max_height = 0.8 },
    },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory (Oil)" },
      {
        "<leader>e",
        function()
          require("oil").toggle_float()
        end,
        desc = "File explorer (Oil float)",
      },
    },
  },
}
