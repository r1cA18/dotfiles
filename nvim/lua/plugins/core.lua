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
    "nvim-telescope/telescope-fzf-native.nvim",
    dir = vim.env.TELESCOPE_FZF_NATIVE,
    enabled = vim.env.TELESCOPE_FZF_NATIVE ~= nil,
    config = function()
      require("telescope").load_extension("fzf")
    end,
  },
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {},
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    enabled = false,
  },
}
