-- Role: auto close and auto rename HTML / JSX tags.
return {
  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },
}
