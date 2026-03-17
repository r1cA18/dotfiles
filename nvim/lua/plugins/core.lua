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
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.cmdline = opts.cmdline or {}
      opts.cmdline.format = opts.cmdline.format or {}

      for _, format in ipairs({ "cmdline", "lua", "calculator", "filter" }) do
        if opts.cmdline.format[format] then
          opts.cmdline.format[format].lang = nil
        end
      end
    end,
  },
}
