-- Entry point. Keep this thin: each line loads one independent module.
vim.loader.enable()

-- Leader must be set before lazy.nvim reads plugin keymaps.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
