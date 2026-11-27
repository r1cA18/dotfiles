-- Role: show the available next keys after a prefix (<leader>, g, z, ...).
-- Descriptions come from each keymap's `desc`; only group names live here.
return {
  {
    "nvim-mini/mini.clue",
    event = "VeryLazy",
    opts = function()
      local clue = require("mini.clue")
      return {
        triggers = {
          { mode = "n", keys = "<Leader>" },
          { mode = "x", keys = "<Leader>" },
          { mode = "n", keys = "g" },
          { mode = "x", keys = "g" },
          { mode = "n", keys = "z" },
          { mode = "x", keys = "z" },
          { mode = "n", keys = "[" },
          { mode = "n", keys = "]" },
          { mode = "n", keys = "<C-w>" },
          { mode = "n", keys = "'" },
          { mode = "n", keys = "`" },
          { mode = "n", keys = '"' },
          { mode = "x", keys = '"' },
          { mode = "i", keys = "<C-r>" },
          { mode = "c", keys = "<C-r>" },
        },
        clues = {
          clue.gen_clues.g(),
          clue.gen_clues.z(),
          clue.gen_clues.windows(),
          clue.gen_clues.marks(),
          clue.gen_clues.registers(),
          { mode = "n", keys = "<Leader>b", desc = "+buffer" },
          { mode = "n", keys = "<Leader>c", desc = "+code" },
          { mode = "n", keys = "<Leader>f", desc = "+file" },
          { mode = "n", keys = "<Leader>g", desc = "+git" },
          { mode = "n", keys = "<Leader>gh", desc = "+hunk" },
          { mode = "n", keys = "<Leader>s", desc = "+search" },
          { mode = "n", keys = "<Leader>u", desc = "+ui / toggle" },
        },
        window = { delay = 300, config = { width = "auto" } },
      }
    end,
  },
}
