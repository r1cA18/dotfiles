-- Role: highlight text patterns: TODO / FIXME / HACK / NOTE keywords and
-- #rrggbb color codes.
return {
  {
    "nvim-mini/mini.hipatterns",
    event = { "BufReadPost", "BufNewFile" },
    opts = function()
      local hipatterns = require("mini.hipatterns")
      return {
        highlighters = {
          fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
          hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
          todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
          note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
          hex_color = hipatterns.gen_highlighter.hex_color(),
        },
      }
    end,
  },
}
