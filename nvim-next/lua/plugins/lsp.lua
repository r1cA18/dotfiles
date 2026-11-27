-- Role: LSP. Uses the builtin client (vim.lsp.config / vim.lsp.enable);
-- nvim-lspconfig only supplies the per-server definitions. Server binaries
-- come from Nix (neovim.nix extraPackages), never Mason.
-- The builtin keymaps (grn gra grr gri grt grx gO K [d ]d <C-s>) are used as is.
return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- Teach lua_ls about the Neovim runtime (replaces lazydev.nvim).
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
          },
        },
      })

      vim.lsp.enable({
        "bashls",
        "biome",
        "cssls",
        "html",
        "jsonls",
        "lua_ls",
        "marksman",
        "nixd",
        "taplo",
        "vtsls",
        "yamlls",
      })

      vim.diagnostic.config({ severity_sort = true })

      vim.keymap.set("n", "<leader>uh", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end, { desc = "Toggle inlay hints" })
    end,
  },
}
