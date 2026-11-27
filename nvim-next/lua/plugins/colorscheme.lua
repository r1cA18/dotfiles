-- Role: colorscheme. tokyonight is the default; catppuccin is installed to try.
-- Switch for one session with `:colorscheme catppuccin-mocha`, or change the
-- name below to make it permanent.
return {
  {
    "folke/tokyonight.nvim",
    priority = 1000, -- load before every other plugin
    config = function()
      vim.cmd.colorscheme("tokyonight-moon")
    end,
  },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
}
