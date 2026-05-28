{ pkgs, ... }:
let
  treesitterGrammars = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = true;
    withPython3 = true;
    extraWrapperArgs = [
      "--set"
      "TREESITTER_GRAMMARS"
      "${treesitterGrammars}"
    ];
    extraPackages = with pkgs; [
      bash-language-server
      biome
      lua-language-server
      marksman
      nixd
      nixfmt
      shellcheck
      shfmt
      stylua
      taplo
      typescript-language-server
      vscode-langservers-extracted
      yaml-language-server
    ];
  };

  xdg.configFile."nvim".source = ../../../nvim;
}
