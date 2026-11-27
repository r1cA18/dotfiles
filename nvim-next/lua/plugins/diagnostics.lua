-- Role: how diagnostics are drawn at the cursor line.
-- Without this file diagnostics show as signs and underlines only; use
-- <C-w>d for the float and [d / ]d to jump.
return {
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    config = function()
      require("tiny-inline-diagnostic").setup({ preset = "modern" })
      vim.diagnostic.config({ virtual_text = false })
    end,
  },
}
