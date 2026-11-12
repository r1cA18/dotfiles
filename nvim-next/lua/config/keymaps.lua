-- Plugin-independent keymaps only. A keymap that calls a plugin belongs in
-- that plugin's role file under lua/plugins/.
local map = vim.keymap.set

map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", { desc = "Clear search highlight" })

-- Window navigation.
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })
