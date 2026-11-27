-- Role: completion popup (LSP, path, buffer words, snippets, cmdline).
-- Without this file use the builtin <C-x><C-o> or set 'autocomplete'.
return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- v2 on main is a breaking rewrite; stay on v1 releases
    -- Loaded at startup so LSP clients receive blink's capabilities.
    opts = {
      -- <CR> accept, <C-n>/<C-p> or arrows select, <C-space> open, <C-e> close
      keymap = { preset = "enter" },
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
    },
  },
}
