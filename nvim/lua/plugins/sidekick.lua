-- Drive the Claude Code / Codex CLIs from a Neovim split. Loaded on keypress
-- so machines without either CLI never pay a startup cost.
return {
  {
    "folke/sidekick.nvim",
    opts = {},
    keys = {
      {
        "<leader>aa",
        function()
          require("sidekick.cli").toggle()
        end,
        desc = "Sidekick Toggle CLI",
        mode = { "n", "v" },
      },
      {
        "<leader>ac",
        function()
          require("sidekick.cli").toggle({ name = "claude", focus = true })
        end,
        desc = "Sidekick Claude Code",
        mode = { "n", "v" },
      },
      {
        "<leader>ax",
        function()
          require("sidekick.cli").toggle({ name = "codex", focus = true })
        end,
        desc = "Sidekick Codex",
        mode = { "n", "v" },
      },
      {
        "<leader>ap",
        function()
          require("sidekick.cli").prompt()
        end,
        desc = "Sidekick Prompt Picker",
        mode = { "n", "v" },
      },
    },
  },
}
