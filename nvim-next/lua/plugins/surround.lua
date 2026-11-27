-- Role: add / delete / replace surrounding pairs.
-- Uses the `gs` prefix because `s` belongs to motion.lua.
return {
  {
    "nvim-mini/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        replace = "gsr",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
      },
    },
  },
}
