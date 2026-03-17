return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.auto_install = false
      opts.ensure_installed = {}
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {},
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    enabled = false,
  },
}
