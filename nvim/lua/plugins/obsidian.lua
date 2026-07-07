-- Obsidian vault integration (community fork). The spec collapses to nothing
-- on machines where the vault is absent, so nvim never errors there.
local vault = vim.fn.expand("~/vault")

if vim.fn.isdirectory(vault) == 0 then
  return {}
end

return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      legacy_commands = false,
      workspaces = {
        { name = "vault", path = vault },
      },
    },
  },
}
