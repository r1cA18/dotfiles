-- Role: start screen shown by a bare `nvim` (snacks.nvim dashboard only).
-- Its file / grep / recent entries call whichever picker is installed.
return {
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = { dashboard = { enabled = true } },
  },
}
