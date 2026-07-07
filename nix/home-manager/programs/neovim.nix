{
  config,
  lib,
  pkgs,
  ...
}:
let
  treesitterGrammars = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
  dotfilesDir = "${config.home.homeDirectory}/dotfiles";
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = true;
    withPython3 = true;
    initLua = ''
      vim.loader.enable()

      local treesitter_grammars = vim.env.TREESITTER_GRAMMARS
      if treesitter_grammars then
        vim.opt.runtimepath:append(treesitter_grammars)
      end

      require("config.lazy")
    '';
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
      vscode-langservers-extracted
      vtsls
      yaml-language-server
    ];
  };

  # Out-of-store symlink so config edits apply instantly without a rebuild.
  # The store-copy alternative would make ~/.config/nvim read-only and force a
  # `dr` for every tweak, and also block lazy.nvim from writing its lockfile.
  xdg.configFile."nvim/lua".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nvim/lua";
  xdg.configFile."nvim/lazy-lock.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nvim/lazy-lock.json";
  xdg.configFile."nvim/stylua.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nvim/stylua.toml";

  # Converge plugins to the committed lockfile on every `dr`. lazy.nvim writes
  # nvim/lazy-lock.json (now writable via the out-of-store symlink); `Lazy!
  # restore` checks out exactly those pins. Guarded so a machine without nvim
  # or git, or a first run before plugins exist, never fails activation.
  home.activation.nvimLazyRestore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v nvim >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
      echo "Restoring Neovim plugins to committed lockfile..."
      $DRY_RUN_CMD nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || true
    fi
  '';
}
