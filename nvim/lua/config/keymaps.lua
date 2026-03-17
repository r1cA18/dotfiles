vim.keymap.set("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New Buffer" })
vim.keymap.set("n", "<leader>fp", function()
  require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find Config File" })
