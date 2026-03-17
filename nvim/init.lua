vim.loader.enable()

local treesitter_grammars = vim.env.TREESITTER_GRAMMARS
if treesitter_grammars then
  vim.opt.runtimepath:append(treesitter_grammars)
end

require("config.lazy")
