-- Role: jump anywhere on screen by typing a few characters and a label.
return {
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      {
        "s",
        function()
          require("flash").jump()
        end,
        mode = { "n", "x", "o" },
        desc = "Flash jump",
      },
      {
        "S",
        function()
          require("flash").treesitter()
        end,
        mode = { "n", "x", "o" },
        desc = "Flash treesitter select",
      },
      {
        "r",
        function()
          require("flash").remote()
        end,
        mode = "o",
        desc = "Flash remote operation",
      },
    },
  },
}
