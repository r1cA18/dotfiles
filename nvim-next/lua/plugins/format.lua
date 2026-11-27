-- Role: formatting. Formatter binaries come from Nix (neovim.nix
-- extraPackages). Filetypes without an entry fall back to the LSP formatter.
return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        nix = { "nixfmt" },
        sh = { "shfmt" },
        zsh = { "shfmt" },
      },
      default_format_opts = { lsp_format = "fallback" },
      format_on_save = function()
        if vim.g.disable_autoformat then
          return
        end
        return { timeout_ms = 1000 }
      end,
    },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true })
        end,
        mode = { "n", "x" },
        desc = "Format buffer / selection",
      },
      {
        "<leader>uf",
        function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify("Format on save: " .. (vim.g.disable_autoformat and "off" or "on"))
        end,
        desc = "Toggle format on save",
      },
    },
  },
}
