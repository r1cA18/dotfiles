-- LazyVim's TypeScript extra wires up vtsls (its current default) plus
-- treesitter, conform and friends. The vtsls binary is supplied by Nix
-- (extraPackages in neovim.nix), so Mason stays disabled.
return {
  { import = "lazyvim.plugins.extras.lang.typescript" },
}
