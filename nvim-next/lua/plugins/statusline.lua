-- Role: statusline. Without this file Neovim 0.12's builtin statusline is used.
return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = { theme = "auto", globalstatus = true },
    },
  },
}
