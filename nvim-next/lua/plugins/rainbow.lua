-- Role: color nested brackets by depth. Works for filetypes that have a
-- treesitter parser; needs no setup call.
return {
  { "HiPhish/rainbow-delimiters.nvim", event = { "BufReadPost", "BufNewFile" } },
}
