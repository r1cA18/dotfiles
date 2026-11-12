-- Role: treesitter highlighting and folding.
-- Highlighting itself is builtin (vim.treesitter.start). nvim-treesitter is
-- never loaded as a plugin: its checkout is only the source of pinned parser
-- revisions and queries for scripts/build-parsers.lua (see README).
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = true,
    -- Rebuild parsers whenever the pinned revisions change (install / update).
    build = function()
      dofile(vim.fn.stdpath("config") .. "/scripts/build-parsers.lua")
    end,
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("dotfiles_syntax", { clear = true }),
        callback = function(ev)
          -- Fails quietly for filetypes without an installed parser.
          if not pcall(vim.treesitter.start, ev.buf) then
            return
          end
          if ev.buf == vim.api.nvim_get_current_buf() then
            vim.wo[0][0].foldmethod = "expr"
            vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
          end
        end,
      })
    end,
  },
}
