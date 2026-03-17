{ pkgs, ... }:
let
  treesitterGrammars = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
  telescopeFzfNative = pkgs.vimPlugins.telescope-fzf-native-nvim;
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraWrapperArgs = [
      "--set"
      "TREESITTER_GRAMMARS"
      "${treesitterGrammars}"
      "--set"
      "TELESCOPE_FZF_NATIVE"
      "${telescopeFzfNative}"
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
