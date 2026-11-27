-- Only values that differ from Neovim's defaults. Plugin options live in
-- lua/plugins/<role>.lua.
local opt = vim.opt

-- Carried over from the previous config.
opt.conceallevel = 2 -- render-markdown / obsidian need concealed markup
opt.foldlevel = 99 -- start with every fold open
opt.smoothscroll = true

-- Behaviour LazyVim used to provide implicitly.
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes" -- no text shift when signs appear
opt.cursorline = true
opt.scrolloff = 4
opt.clipboard = "unnamedplus" -- share the system clipboard
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.splitright = true
opt.splitbelow = true
opt.updatetime = 250 -- CursorHold delay (diagnostics, git signs)
opt.winborder = "rounded" -- border for every floating window (0.11+)
