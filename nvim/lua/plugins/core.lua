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
    enabled = false,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    enabled = false,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    enabled = false,
  },
}
