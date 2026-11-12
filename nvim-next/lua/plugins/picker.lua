-- Role: fuzzy picker (files, grep, buffers, help, diagnostics, symbols).
-- Uses the fzf / rg / fd binaries supplied by Nix.
return {
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    opts = {},
    init = function()
      -- Route vim.ui.select (code actions etc.) through fzf-lua on first use.
      vim.ui.select = function(...)
        require("fzf-lua").register_ui_select()
        return vim.ui.select(...)
      end
    end,
    keys = {
      { "<leader><space>", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent files" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
      { "<leader>,", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
      {
        "<leader>fp",
        function()
          require("fzf-lua").files({ cwd = vim.fn.stdpath("config") })
        end,
        desc = "Find config file",
      },
      { "<leader>/", "<cmd>FzfLua live_grep<cr>", desc = "Grep in project" },
      { "<leader>sw", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word under cursor" },
      { "<leader>sw", "<cmd>FzfLua grep_visual<cr>", mode = "x", desc = "Grep selection" },
      { "<leader>sh", "<cmd>FzfLua helptags<cr>", desc = "Help pages" },
      { "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
      { "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Diagnostics (buffer)" },
      { "<leader>sD", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Diagnostics (workspace)" },
      { "<leader>ss", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Symbols (buffer)" },
      { "<leader>sr", "<cmd>FzfLua resume<cr>", desc = "Resume last picker" },
      { "<leader>gs", "<cmd>FzfLua git_status<cr>", desc = "Git status" },
      { "<leader>uC", "<cmd>FzfLua colorschemes<cr>", desc = "Colorschemes" },
    },
  },
}
