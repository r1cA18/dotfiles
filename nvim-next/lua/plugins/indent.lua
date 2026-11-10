-- Role: indent guides and current-scope highlight (snacks.nvim indent only).
return {
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = { indent = { enabled = true } },
  },
}
