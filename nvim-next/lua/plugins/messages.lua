-- Role: message and cmdline presentation, using Neovim 0.12's builtin ui2
-- (experimental). No plugin: messages no longer block with "Press ENTER" and
-- the cmdline gets syntax highlighting. `g<` opens the message pager.
local ok, ui2 = pcall(require, "vim._core.ui2")
if ok then
  ui2.enable({})
end

return {}
